part of '../_index.dart';

/// Мультиплексирующий транспорт для поддержки нескольких вызовов через одно соединение.
///
/// Позволяет выполнять множество параллельных вызовов через один базовый транспорт,
/// добавляя идентификаторы вызовов и маршрутизацию сообщений.
class RpcMultiplexTransport implements IRpcTransport {
  /// Базовый транспорт, через который идет коммуникация
  final IRpcTransport _baseTransport;

  /// Логгер для отладки
  final RpcLogger? _logger;

  /// Счетчик для генерации уникальных ID вызовов
  int _nextCallId = 1;

  /// Контроллеры для каждого активного вызова
  final Map<String, StreamController<RpcTransportMessage<Uint8List>>>
      _callControllers = {};

  /// Подписка на входящие сообщения от базового транспорта
  StreamSubscription? _subscription;

  /// Имя заголовка для ID вызова
  static const String _callIdHeader = 'x-rpc-call-id';

  /// Флаг, указывающий, закрыт ли транспорт
  bool _closed = false;

  /// Создает новый мультиплексирующий транспорт
  ///
  /// [baseTransport] Базовый транспорт для обмена данными
  /// [logger] Опциональный логгер для отладки
  RpcMultiplexTransport({
    required IRpcTransport baseTransport,
    RpcLogger? logger,
  })  : _baseTransport = baseTransport,
        _logger = logger {
    _setupMessageRouting();
  }

  /// Настраивает маршрутизацию входящих сообщений
  void _setupMessageRouting() {
    _subscription = _baseTransport.incomingMessages.listen(
      (message) {
        final callId = _getCallIdFromMessage(message);

        if (callId != null) {
          final controller = _callControllers[callId];
          if (controller != null && !controller.isClosed) {
            // Передаем сообщение в соответствующий поток
            controller.add(message);

            // Если это последнее сообщение в стриме, закрываем контроллер
            if (message.isEndOfStream) {
              controller.close();
              _callControllers.remove(callId);
              _logger?.debug('Вызов $callId завершен (получен END_STREAM)');
            }
          } else {
            _logger?.warning(
                'Получено сообщение для неизвестного вызова: $callId');
          }
        } else {
          // Сообщение без ID вызова - если это ответ от сервера
          // Если это первое сообщение в новой серии, создаем новый вызов
          if (_callControllers.isEmpty) {
            _logger?.warning(
                'Сообщение без ID вызова игнорируется, т.к. нет активных вызовов');
            return;
          }

          // Если есть только один активный вызов, отправляем ему
          if (_callControllers.length == 1) {
            final controller = _callControllers.values.first;
            if (!controller.isClosed) {
              _logger?.debug(
                  'Сообщение без ID направлено единственному активному вызову');
              controller.add(message);

              if (message.isEndOfStream) {
                controller.close();
                _callControllers.remove(_callControllers.keys.first);
              }
            }
          } else {
            _logger?.warning(
                'Получено сообщение без ID вызова, но активных вызовов несколько. '
                'Невозможно определить целевой вызов.');
          }
        }
      },
      onError: (error, stackTrace) {
        _logger?.error('Ошибка в базовом транспорте',
            error: error, stackTrace: stackTrace);

        // Передаем ошибку всем активным вызовам
        for (final controller in _callControllers.values) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      },
      onDone: () {
        _logger?.debug('Базовый транспорт завершил работу');

        // Закрываем все активные контроллеры
        for (final controller in _callControllers.values) {
          if (!controller.isClosed) {
            controller.close();
          }
        }
        _callControllers.clear();
      },
    );
  }

  /// Создает новый вызов и возвращает транспорт для него
  ///
  /// Создает виртуальный транспорт, который использует базовый транспорт
  /// с добавлением идентификатора вызова.
  ///
  /// [methodName] Имя метода для логирования (опционально)
  /// Возвращает новый транспорт для одного вызова
  IRpcTransport createCallTransport([String? methodName]) {
    final callId = _generateCallId();
    final logPrefix =
        methodName != null ? '$methodName ($callId)' : 'Вызов $callId';

    _logger?.debug('Создан новый $logPrefix');

    return _CallTransport(
      callId: callId,
      multiplexTransport: this,
      logger: _logger != null
          ? RpcLogger(
              logPrefix,
              colors: RpcLoggerColors.singleColor(AnsiColor.brightBlack),
            )
          : null,
    );
  }

  /// Генерирует уникальный ID вызова
  String _generateCallId() {
    return 'call-${_nextCallId++}';
  }

  /// Извлекает ID вызова из сообщения
  String? _getCallIdFromMessage(RpcTransportMessage<Uint8List> message) {
    if (message.metadata != null) {
      return message.metadata!.getHeaderValue(_callIdHeader);
    }
    return null;
  }

  /// Добавляет ID вызова к метаданным
  RpcMetadata _addCallIdToMetadata(String callId, RpcMetadata metadata) {
    final headers = List<RpcHeader>.from(metadata.headers);
    headers.add(RpcHeader(_callIdHeader, callId));
    return RpcMetadata(headers);
  }

  /// Отправляет сообщение через базовый транспорт
  ///
  /// [callId] ID вызова
  /// [message] Сообщение для отправки
  /// [metadata] Опциональные метаданные
  /// [endStream] Флаг завершения потока
  Future<void> _sendMessageForCall(
    String callId,
    Uint8List? message,
    RpcMetadata? metadata,
    bool endStream,
  ) async {
    if (_closed) {
      throw StateError('Транспорт закрыт');
    }

    // Добавляем ID вызова в метаданные
    final callIdMetadata = metadata != null
        ? _addCallIdToMetadata(callId, metadata)
        : RpcMetadata([RpcHeader(_callIdHeader, callId)]);

    // Сначала всегда отправляем метаданные с ID вызова
    await _baseTransport.sendMetadata(
      callIdMetadata,
      endStream: endStream && message == null,
    );

    // Если есть сообщение и еще не завершен поток, отправляем данные
    if (message != null && !(endStream && message == null)) {
      await _baseTransport.sendMessage(message, endStream: endStream);
    }
  }

  /// Создает новый поток для вызова
  ///
  /// [callId] ID вызова
  /// Возвращает поток сообщений для этого вызова
  Stream<RpcTransportMessage<Uint8List>> _createCallStream(String callId) {
    final controller =
        StreamController<RpcTransportMessage<Uint8List>>.broadcast();
    _callControllers[callId] = controller;
    return controller.stream;
  }

  @override
  Future<void> sendMetadata(RpcMetadata metadata,
      {bool endStream = false}) async {
    throw UnsupportedError(
        'Прямая отправка через мультиплексирующий транспорт не поддерживается. '
        'Используйте createCallTransport() для создания потока для вызова.');
  }

  @override
  Future<void> sendMessage(Uint8List data, {bool endStream = false}) async {
    throw UnsupportedError(
        'Прямая отправка через мультиплексирующий транспорт не поддерживается. '
        'Используйте createCallTransport() для создания потока для вызова.');
  }

  @override
  Future<void> finishSending() async {
    throw UnsupportedError(
        'Прямая отправка через мультиплексирующий транспорт не поддерживается. '
        'Используйте createCallTransport() для создания потока для вызова.');
  }

  @override
  Stream<RpcTransportMessage<Uint8List>> get incomingMessages {
    throw UnsupportedError(
        'Прямая подписка на мультиплексирующий транспорт не поддерживается. '
        'Используйте createCallTransport() для создания потока для вызова.');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    // Отменяем подписку на базовый транспорт
    await _subscription?.cancel();

    // Закрываем все активные контроллеры
    for (final controller in _callControllers.values) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    _callControllers.clear();

    // Закрываем базовый транспорт
    await _baseTransport.close();
  }
}

/// Транспорт для отдельного вызова через мультиплексирующий транспорт
///
/// Представляет "виртуальный" транспорт для одного вызова,
/// маршрутизирующий все сообщения через родительский мультиплексирующий транспорт.
class _CallTransport implements IRpcTransport {
  /// ID этого вызова
  final String callId;

  /// Родительский мультиплексирующий транспорт
  final RpcMultiplexTransport multiplexTransport;

  /// Логгер для отладки
  final RpcLogger? logger;

  /// Флаг, указывающий, закрыт ли транспорт
  bool _closed = false;

  /// Флаг, указывающий, завершена ли отправка
  bool _sendingFinished = false;

  /// Поток входящих сообщений для этого вызова
  late final Stream<RpcTransportMessage<Uint8List>> _incomingMessagesStream;

  /// Создает новый транспорт для отдельного вызова
  ///
  /// [callId] Уникальный ID вызова
  /// [multiplexTransport] Родительский мультиплексирующий транспорт
  /// [logger] Опциональный логгер для отладки
  _CallTransport({
    required this.callId,
    required this.multiplexTransport,
    this.logger,
  }) {
    _incomingMessagesStream = multiplexTransport._createCallStream(callId);
  }

  @override
  Stream<RpcTransportMessage<Uint8List>> get incomingMessages =>
      _incomingMessagesStream;

  @override
  Future<void> sendMetadata(RpcMetadata metadata,
      {bool endStream = false}) async {
    if (_closed || _sendingFinished) {
      throw StateError('Транспорт закрыт или отправка завершена');
    }

    logger?.debug('Отправка метаданных${endStream ? " (END_STREAM)" : ""}');

    await multiplexTransport._sendMessageForCall(
      callId,
      null, // нет сообщения, только метаданные
      metadata,
      endStream,
    );

    if (endStream) {
      _sendingFinished = true;
    }
  }

  @override
  Future<void> sendMessage(Uint8List data, {bool endStream = false}) async {
    if (_closed || _sendingFinished) {
      throw StateError('Транспорт закрыт или отправка завершена');
    }

    logger?.debug(
        'Отправка сообщения размером ${data.length} байт${endStream ? " (END_STREAM)" : ""}');

    await multiplexTransport._sendMessageForCall(
      callId,
      data,
      null, // нет отдельных метаданных
      endStream,
    );

    if (endStream) {
      _sendingFinished = true;
    }
  }

  @override
  Future<void> finishSending() async {
    if (_closed || _sendingFinished) return;

    logger?.debug('Завершение отправки');

    _sendingFinished = true;

    // Отправляем пустой DATA фрейм с END_STREAM
    await multiplexTransport._sendMessageForCall(
      callId,
      Uint8List(0), // пустое сообщение
      null,
      true, // END_STREAM
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;

    logger?.debug('Закрытие транспорта');
    _closed = true;

    // Если отправка не завершена, завершаем
    if (!_sendingFinished) {
      await finishSending();
    }
  }
}
