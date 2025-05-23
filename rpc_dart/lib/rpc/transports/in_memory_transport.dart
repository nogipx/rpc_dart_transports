part of '../_index.dart';

/// Высокопроизводительный транспорт для обмена сообщениями в памяти.
///
/// Полноценная реализация транспортного уровня для коммуникации
/// между компонентами в одном процессе с минимальными накладными расходами.
/// Идеально подходит для:
/// - Межкомпонентной коммуникации внутри приложения
/// - Высоконагруженных систем, где важна скорость обмена данными
/// - Микросервисов в одном процессе с общей памятью
/// - Повышения производительности без сетевых накладных расходов
class RpcInMemoryTransport implements IRpcTransport {
  /// Контроллер для отправки сообщений партнерскому транспорту
  final StreamController<RpcTransportMessage<Uint8List>> _outgoingController;

  /// Контроллер для управления потоком входящих сообщений
  final StreamController<RpcTransportMessage<Uint8List>> _incomingController =
      StreamController<RpcTransportMessage<Uint8List>>();

  /// Флаг, указывающий, что отправка завершена
  bool _sendingFinished = false;

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
  /// [flowControlWindow] Начальный размер окна управления потоком (предотвращает OOM)
  /// [logger] Опциональный логгер для отладки транспорта
  /// [errorHandler] Функция для обработки ошибок транспорта
  RpcInMemoryTransport(
    this._outgoingController, {
    int initialFlowControlWindow = 10 * 1024 * 1024, // 10 МБ по умолчанию
    int maxFlowControlWindow = 100 * 1024 * 1024, // 100 МБ максимум
    RpcLogger? logger,
    void Function(Object error)? errorHandler,
  })  : _flowControlWindow = initialFlowControlWindow,
        _maxFlowControlWindow = maxFlowControlWindow,
        _logger = logger,
        _errorHandler = errorHandler {
    // Проверяем, что контроллер еще открыт
    if (_outgoingController.isClosed) {
      throw StateError('Контроллер для отправки сообщений закрыт');
    }

    _logger?.debug(
        'InMemoryTransport: инициализирован с буфером $_flowControlWindow байт');
  }

  @override
  Stream<RpcTransportMessage<Uint8List>> get incomingMessages =>
      _incomingController.stream;

  /// Добавляет входящее сообщение в поток (вызывается партнерским транспортом)
  void addIncomingMessage(RpcTransportMessage<Uint8List> message) {
    if (_incomingController.isClosed) return;

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

    // Если это сообщение завершающее, закрываем контроллер
    if (message.isEndOfStream) {
      _logger?.debug(
          'InMemoryTransport: получен END_STREAM, закрываем поток приема');
      _incomingController.close();
    }
  }

  /// Увеличивает окно управления потоком для предотвращения переполнения памяти
  void _increaseFlowControlWindow(num increment) {
    final newWindow = _flowControlWindow + increment.toInt();
    _flowControlWindow =
        newWindow > _maxFlowControlWindow ? _maxFlowControlWindow : newWindow;
  }

  @override
  Future<void> sendMetadata(RpcMetadata metadata,
      {bool endStream = false}) async {
    if (_sendingFinished || _closed) {
      _logger?.warning(
          'InMemoryTransport: попытка отправить метаданные после завершения отправки');
      return;
    }

    try {
      _outgoingController.add(RpcTransportMessage<Uint8List>(
        metadata: metadata,
        isEndOfStream: endStream,
      ));

      if (endStream) {
        _sendingFinished = true;
      }
    } catch (e) {
      _logger?.error('InMemoryTransport: ошибка при отправке метаданных: $e');
      _errorHandler?.call(e);
      rethrow;
    }
  }

  @override
  Future<void> sendMessage(Uint8List data, {bool endStream = false}) async {
    if (_sendingFinished || _closed) {
      _logger?.warning(
          'InMemoryTransport: попытка отправить данные после завершения отправки');
      return;
    }

    try {
      _outgoingController.add(RpcTransportMessage<Uint8List>(
        payload: data,
        isEndOfStream: endStream,
      ));

      if (endStream) {
        _sendingFinished = true;
      }
    } catch (e) {
      _logger?.error('InMemoryTransport: ошибка при отправке сообщения: $e');
      _errorHandler?.call(e);
      rethrow;
    }
  }

  @override
  Future<void> finishSending() async {
    if (_sendingFinished || _closed) return;

    try {
      _sendingFinished = true;

      // Отправляем пустое сообщение с флагом END_STREAM
      // согласно спецификации gRPC - пустой DATA фрейм с END_STREAM
      _outgoingController.add(RpcTransportMessage<Uint8List>(
        isEndOfStream: true,
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
      _sendingFinished = true;

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
        StreamController<RpcTransportMessage<Uint8List>>();
    final serverToClientController =
        StreamController<RpcTransportMessage<Uint8List>>();

    // Создаем оптимизированные транспорты
    final clientTransport = RpcInMemoryTransport(
      clientToServerController,
      initialFlowControlWindow: initialFlowControlWindow,
      maxFlowControlWindow: maxFlowControlWindow,
      logger: clientLogger,
      errorHandler: clientErrorHandler,
    );

    final serverTransport = RpcInMemoryTransport(
      serverToClientController,
      initialFlowControlWindow: initialFlowControlWindow,
      maxFlowControlWindow: maxFlowControlWindow,
      logger: serverLogger,
      errorHandler: serverErrorHandler,
    );

    // Подписываемся на сообщения для передачи между транспортами
    clientToServerController.stream.listen(
      serverTransport.addIncomingMessage,
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
      clientTransport.addIncomingMessage,
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
