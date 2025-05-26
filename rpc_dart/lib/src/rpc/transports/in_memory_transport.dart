// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Высокопроизводительный транспорт для обмена сообщениями в памяти со Stream ID.
///
/// Полноценная реализация транспортного уровня для коммуникации
/// между компонентами в одном процессе с минимальными накладными расходами.
/// Поддерживает мультиплексирование по уникальным Stream ID согласно gRPC спецификации.
/// Идеально подходит для:
/// - Межкомпонентной коммуникации внутри приложения
/// - Высоконагруженных систем, где важна скорость обмена данными
/// - Микросервисов в одном процессе с общей памятью
/// - Повышения производительности без сетевых накладных расходов
class RpcInMemoryTransport implements IRpcTransport {
  /// Контроллер для отправки сообщений партнерскому транспорту
  final StreamController<RpcTransportMessage> _outgoingController;

  /// Контроллер для управления потоком входящих сообщений
  final StreamController<RpcTransportMessage> _incomingController =
      StreamController<RpcTransportMessage>.broadcast();

  /// Счетчик для генерации уникальных Stream ID
  int _nextStreamId;

  /// Активные streams и их состояние отправки
  final Map<int, bool> _streamSendingFinished = <int, bool>{};

  /// Флаг, указывающий, что транспорт закрыт
  bool _closed = false;

  /// Размер окна управления потоком (для предотвращения OOM)
  int _flowControlWindow;

  /// Максимальный размер окна управления потоком
  final int _maxFlowControlWindow;

  /// Логгер для отладки транспорта
  final RpcLogger? _logger;

  /// Обработчик ошибок транспорта
  final void Function(Object error)? _errorHandler;

  /// Создает новый высокопроизводительный транспорт для обмена сообщениями в памяти
  ///
  /// [_outgoingController] Контроллер для отправки сообщений партнеру
  /// [isClient] Флаг клиентского транспорта (влияет на генерацию Stream ID)
  /// [flowControlWindow] Начальный размер окна управления потоком (предотвращает OOM)
  /// [logger] Опциональный логгер для отладки транспорта
  /// [errorHandler] Функция для обработки ошибок транспорта
  RpcInMemoryTransport._(
    this._outgoingController, {
    bool isClient = true, // Клиент использует нечетные ID, сервер - четные
    int initialFlowControlWindow = 10 * 1024 * 1024, // 10 МБ по умолчанию
    int maxFlowControlWindow = 100 * 1024 * 1024, // 100 МБ максимум
    RpcLogger? logger,
    void Function(Object error)? errorHandler,
  })  : _nextStreamId =
            isClient ? 1 : 2, // HTTP/2: клиент - нечетные, сервер - четные
        _flowControlWindow = initialFlowControlWindow,
        _maxFlowControlWindow = maxFlowControlWindow,
        _logger = logger,
        _errorHandler = errorHandler {
    // Проверяем, что контроллер еще открыт
    if (_outgoingController.isClosed) {
      throw StateError('Контроллер для отправки сообщений закрыт');
    }

    _logger?.debug(
        'InMemoryTransport: инициализирован с буфером $_flowControlWindow байт, isClient: $isClient');
  }

  @override
  Stream<RpcTransportMessage> get incomingMessages =>
      _incomingController.stream;

  @override
  Stream<RpcTransportMessage> getMessagesForStream(int streamId) {
    return incomingMessages.where((message) => message.streamId == streamId);
  }

  @override
  int createStream() {
    final streamId = _nextStreamId;
    _nextStreamId +=
        2; // HTTP/2: клиент использует нечетные ID, сервер - четные
    _streamSendingFinished[streamId] = false;
    _logger?.debug('InMemoryTransport: создан stream $streamId');
    return streamId;
  }

  /// Добавляет входящее сообщение в поток (вызывается партнерским транспортом)
  void _addIncomingMessage(RpcTransportMessage message) {
    if (_incomingController.isClosed) return;

    _logger?.debug(
        'InMemoryTransport: получено сообщение для stream ${message.streamId}, isMetadataOnly: ${message.isMetadataOnly}, endStream: ${message.isEndOfStream}, payload: ${message.payload?.length ?? 0} байт, path: ${message.methodPath}');

    // Проверка размера сообщения для управления памятью
    if (message.payload != null) {
      final messageSize = message.payload!.length;

      // Проверяем, не потребляем ли мы слишком много памяти
      if (messageSize > _flowControlWindow) {
        _logger?.debug(
            'InMemoryTransport: увеличиваем буфер для сообщения размером $messageSize байт');
        _increaseFlowControlWindow(messageSize * 2); // Увеличиваем с запасом
      }

      // Уменьшаем доступное окно
      _flowControlWindow -= messageSize;

      // Если окно стало меньше 20% от максимума, увеличиваем его
      if (_flowControlWindow < (_maxFlowControlWindow * 0.2)) {
        _increaseFlowControlWindow(_maxFlowControlWindow / 2);
      }
    }

    // Добавляем сообщение в поток
    _incomingController.add(message);

    // Если это сообщение завершающее, закрываем контроллер для конкретного stream
    if (message.isEndOfStream) {
      _logger?.debug(
          'InMemoryTransport: получен END_STREAM для stream ${message.streamId}');
    }
  }

  /// Увеличивает окно управления потоком для предотвращения переполнения памяти
  void _increaseFlowControlWindow(num increment) {
    final newWindow = _flowControlWindow + increment.toInt();
    _flowControlWindow =
        newWindow > _maxFlowControlWindow ? _maxFlowControlWindow : newWindow;
  }

  @override
  Future<void> sendMetadata(
    int streamId,
    RpcMetadata metadata, {
    bool endStream = false,
  }) async {
    if (_closed) {
      _logger?.warning(
          'InMemoryTransport: попытка отправить метаданные после закрытия транспорта');
      return;
    }

    try {
      final message = RpcTransportMessage(
        metadata: metadata,
        isEndOfStream: endStream,
        methodPath: metadata.methodPath,
        streamId: streamId,
      );

      _logger?.debug(
          'InMemoryTransport: отправляем метаданные для stream $streamId, endStream: $endStream, path: ${metadata.methodPath}');
      _outgoingController.add(message);

      if (endStream) {
        _streamSendingFinished[streamId] = true;
        _logger?.debug(
            'InMemoryTransport: stream $streamId помечен как завершенный для отправки');
      }
    } catch (e) {
      _logger?.error('InMemoryTransport: ошибка при отправке метаданных: $e');
      _errorHandler?.call(e);
      rethrow;
    }
  }

  @override
  Future<void> sendMessage(
    int streamId,
    Uint8List data, {
    bool endStream = false,
  }) async {
    if (_closed) {
      _logger?.warning(
          'InMemoryTransport: попытка отправить данные после закрытия транспорта');
      return;
    }

    try {
      final message = RpcTransportMessage(
        payload: data,
        isEndOfStream: endStream,
        streamId: streamId,
      );

      _logger?.debug(
          'InMemoryTransport: отправляем сообщение для stream $streamId, размер: ${data.length} байт, endStream: $endStream');
      _outgoingController.add(message);

      if (endStream) {
        _streamSendingFinished[streamId] = true;
        _logger?.debug(
            'InMemoryTransport: stream $streamId помечен как завершенный для отправки');
      }
    } catch (e) {
      _logger?.error('InMemoryTransport: ошибка при отправке сообщения: $e');
      _errorHandler?.call(e);
      rethrow;
    }
  }

  @override
  Future<void> finishSending(int streamId) async {
    if (_closed) return;

    if (_streamSendingFinished[streamId] == true) {
      return; // Уже завершен
    }

    try {
      _streamSendingFinished[streamId] = true;

      // Отправляем пустые метаданные с флагом END_STREAM для конкретного stream
      _outgoingController.add(RpcTransportMessage(
        metadata: RpcMetadata([]),
        isEndOfStream: true,
        streamId: streamId,
      ));
    } catch (e) {
      _logger?.error('InMemoryTransport: ошибка при завершении отправки: $e');
      _errorHandler?.call(e);
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;

    try {
      _closed = true;
      _streamSendingFinished.clear();

      // Закрываем исходящий поток, если он еще открыт
      if (!_outgoingController.isClosed) {
        await _outgoingController.close();
      }

      // Закрываем входящий поток, если он еще открыт
      if (!_incomingController.isClosed) {
        await _incomingController.close();
      }
    } catch (e) {
      _logger?.error('InMemoryTransport: ошибка при закрытии транспорта: $e');
      _errorHandler?.call(e);
      rethrow;
    }
  }

  /// Создает пару соединенных транспортов для обмена данными
  ///
  /// [initialFlowControlWindow] Начальный размер буфера (10 МБ по умолчанию)
  /// [maxFlowControlWindow] Максимальный размер буфера (100 МБ по умолчанию)
  /// [clientLogger] Логгер для клиентского транспорта
  /// [serverLogger] Логгер для серверного транспорта
  /// [clientErrorHandler] Обработчик ошибок клиентского транспорта
  /// [serverErrorHandler] Обработчик ошибок серверного транспорта
  ///
  /// Возвращает кортеж (клиентский транспорт, серверный транспорт)
  static (RpcInMemoryTransport, RpcInMemoryTransport) pair({
    int initialFlowControlWindow = 10 * 1024 * 1024, // 10 МБ
    int maxFlowControlWindow = 100 * 1024 * 1024, // 100 МБ
    RpcLogger? clientLogger,
    RpcLogger? serverLogger,
    void Function(Object error)? clientErrorHandler,
    void Function(Object error)? serverErrorHandler,
  }) {
    // Создаем контроллеры для обмена сообщениями в обоих направлениях
    final clientToServerController =
        StreamController<RpcTransportMessage>.broadcast();
    final serverToClientController =
        StreamController<RpcTransportMessage>.broadcast();

    // Создаем оптимизированные транспорты
    final clientTransport = RpcInMemoryTransport._(
      clientToServerController,
      isClient: true, // Клиент будет использовать нечетные Stream ID
      initialFlowControlWindow: initialFlowControlWindow,
      maxFlowControlWindow: maxFlowControlWindow,
      logger: clientLogger,
      errorHandler: clientErrorHandler,
    );

    final serverTransport = RpcInMemoryTransport._(
      serverToClientController,
      isClient: false, // Сервер будет использовать четные Stream ID
      initialFlowControlWindow: initialFlowControlWindow,
      maxFlowControlWindow: maxFlowControlWindow,
      logger: serverLogger,
      errorHandler: serverErrorHandler,
    );

    // Подписываемся на сообщения для передачи между транспортами
    clientToServerController.stream.listen(
      serverTransport._addIncomingMessage,
      onError: (error) {
        serverLogger?.error('Ошибка в потоке клиент->сервер: $error');
        serverErrorHandler?.call(error);
      },
      onDone: () {
        if (!serverTransport._incomingController.isClosed) {
          serverTransport._incomingController.close();
        }
      },
    );

    serverToClientController.stream.listen(
      clientTransport._addIncomingMessage,
      onError: (error) {
        clientLogger?.error('Ошибка в потоке сервер->клиент: $error');
        clientErrorHandler?.call(error);
      },
      onDone: () {
        if (!clientTransport._incomingController.isClosed) {
          clientTransport._incomingController.close();
        }
      },
    );

    return (clientTransport, serverTransport);
  }
}
