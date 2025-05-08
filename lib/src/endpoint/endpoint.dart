import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:rpc_dart/rpc_dart.dart';

/// Конечная точка для обмена сообщениями
base class RpcEndpoint {
  /// Транспорт для отправки/получения сообщений
  final RpcTransport _transport;
  RpcTransport get transport => _transport;

  /// Сериализатор для преобразования сообщений
  final RpcSerializer _serializer;
  RpcSerializer get serializer => _serializer;

  /// Обработчики ожидающих ответов
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  /// Контроллеры потоков данных
  final Map<String, StreamController<dynamic>> _streamControllers = {};

  /// Обработчики методов по имени сервиса и метода
  final Map<String, Map<String, Future<dynamic> Function(RpcMethodContext)>>
      _methodHandlers = {};

  /// Подписка на входящие сообщения
  StreamSubscription<Uint8List>? _subscription;

  /// Генератор случайных чисел для ID сообщений
  final Random _random = Random();

  /// Создаёт новую конечную точку
  ///
  /// [transport] - транспорт для обмена сообщениями
  /// [serializer] - сериализатор для преобразования сообщений
  RpcEndpoint(this._transport, this._serializer) {
    _initialize();
  }

  /// Инициализирует конечную точку
  void _initialize() {
    _subscription = _transport.receive().listen(_handleIncomingData);
  }

  /// Регистрирует обработчик метода
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [handler] - функция обработки запроса, которая принимает контекст вызова
  void registerMethod(
    String serviceName,
    String methodName,
    Future<dynamic> Function(RpcMethodContext) handler,
  ) {
    _methodHandlers.putIfAbsent(serviceName, () => {});
    _methodHandlers[serviceName]![methodName] = handler;
  }

  /// Вызывает удаленный метод и возвращает результат
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [request] - данные запроса
  /// [timeout] - таймаут ожидания ответа
  /// Возвращает Future с результатом вызова
  Future<dynamic> invoke(
    String serviceName,
    String methodName,
    dynamic request, {
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) async {
    final requestId = _generateRequestId();
    final completer = Completer<dynamic>();
    _pendingRequests[requestId] = completer;

    final message = RpcMessage(
      type: RpcMessageType.request,
      id: requestId,
      service: serviceName,
      method: methodName,
      payload: request,
      metadata: metadata,
    );

    await _sendMessage(message);

    if (timeout != null) {
      return completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingRequests.remove(requestId);
          throw TimeoutException(
              'Вызов метода $serviceName.$methodName превысил время ожидания');
        },
      );
    }

    return completer.future;
  }

  /// Открывает поток данных от удаленной стороны
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [request] - начальный запрос (опционально)
  /// [metadata] - дополнительные метаданные
  /// [streamId] - опциональный ID для потока, если не указан, будет сгенерирован
  /// Возвращает Stream с данными от удаленной стороны
  Stream<dynamic> openStream(
    String serviceName,
    String methodName, {
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Используем переданный streamId или генерируем новый
    final actualStreamId = streamId ?? _generateRequestId();

    // Если поток с таким ID уже существует, возвращаем его
    if (_streamControllers.containsKey(actualStreamId)) {
      return _streamControllers[actualStreamId]!.stream;
    }

    final controller = StreamController<dynamic>.broadcast();
    _streamControllers[actualStreamId] = controller;

    final message = RpcMessage(
      type: RpcMessageType.request,
      id: actualStreamId,
      service: serviceName,
      method: methodName,
      payload: request,
      metadata: metadata,
    );

    _sendMessage(message);

    return controller.stream;
  }

  /// Обрабатывает входящие бинарные данные
  void _handleIncomingData(Uint8List data) {
    final json = _serializer.deserialize(data);
    final message = RpcMessage.fromJson(json);

    switch (message.type) {
      case RpcMessageType.request:
        _handleRequest(message);
        break;
      case RpcMessageType.response:
        _handleResponse(message);
        break;
      case RpcMessageType.streamData:
        _handleStreamData(message);
        break;
      case RpcMessageType.streamEnd:
        _handleStreamEnd(message);
        break;
      case RpcMessageType.error:
        _handleError(message);
        break;
      case RpcMessageType.ping:
        _handlePing(message);
        break;
      case RpcMessageType.pong:
        // Ничего не делаем с pong сообщениями
        break;
      case RpcMessageType.contract:
        // Обработка контрактов будет добавлена позже
        break;
    }
  }

  /// Обрабатывает входящий запрос
  Future<void> _handleRequest(RpcMessage message) async {
    final serviceName = message.service;
    final methodName = message.method;

    if (serviceName == null || methodName == null) {
      await _sendErrorMessage(
          message.id, 'Имя сервиса или метода не указано', message.metadata);
      return;
    }

    final serviceHandlers = _methodHandlers[serviceName];
    if (serviceHandlers == null) {
      await _sendErrorMessage(
          message.id, 'Сервис не найден: $serviceName', message.metadata);
      return;
    }

    final methodHandler = serviceHandlers[methodName];
    if (methodHandler == null) {
      await _sendErrorMessage(
        message.id,
        'Метод не найден: $methodName в сервисе $serviceName',
        message.metadata,
      );
      return;
    }

    try {
      // Создаем контекст вызова метода
      final context = RpcMethodContext(
        messageId: message.id,
        metadata: message.metadata,
        payload: message.payload,
        serviceName: serviceName,
        methodName: methodName,
      );

      // Вызываем обработчик с контекстом
      final result = await methodHandler(context);

      await _sendMessage(
        RpcMessage(
          type: RpcMessageType.response,
          id: message.id,
          payload: result,
          metadata: message.metadata,
        ),
      );
    } catch (e) {
      await _sendErrorMessage(
          message.id, 'Ошибка при выполнении метода: $e', message.metadata);
    }
  }

  /// Обрабатывает входящий ответ
  void _handleResponse(RpcMessage message) {
    final completer = _pendingRequests.remove(message.id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(message.payload);
    }
  }

  /// Обрабатывает входящие данные в потоке
  void _handleStreamData(RpcMessage message) {
    final controller = _streamControllers[message.id];
    if (controller != null && !controller.isClosed) {
      controller.add(message.payload);
    }
  }

  /// Обрабатывает завершение потока
  void _handleStreamEnd(RpcMessage message) {
    final controller = _streamControllers.remove(message.id);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  /// Обрабатывает сообщение с ошибкой
  void _handleError(RpcMessage message) {
    final completer = _pendingRequests.remove(message.id);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(message.payload ?? 'Неизвестная ошибка');
    }

    final controller = _streamControllers[message.id];
    if (controller != null && !controller.isClosed) {
      controller.addError(message.payload ?? 'Неизвестная ошибка');
    }
  }

  /// Обрабатывает ping сообщение
  Future<void> _handlePing(RpcMessage message) async {
    await _sendMessage(
      RpcMessage(
        type: RpcMessageType.pong,
        id: message.id,
        payload: message.payload,
        metadata: message.metadata,
      ),
    );
  }

  /// Отправляет сообщение об ошибке
  Future<void> _sendErrorMessage(
    String requestId,
    String errorMessage,
    Map<String, dynamic>? metadata,
  ) async {
    await _sendMessage(
      RpcMessage(
          type: RpcMessageType.error,
          id: requestId,
          payload: errorMessage,
          metadata: metadata),
    );
  }

  /// Отправляет сообщение через транспорт
  Future<void> _sendMessage(RpcMessage message) async {
    final data = _serializer.serialize(message.toJson());
    await _transport.send(data);
  }

  /// Генерирует уникальный ID запроса
  String _generateRequestId() {
    // Текущее время в миллисекундах + случайное число
    return '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000000)}';
  }

  /// Проверяет, активна ли конечная точка
  bool get isActive => _transport.isAvailable;

  /// Закрывает конечную точку
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;

    // Выполняем все ожидающие запросы с ошибкой
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Endpoint closed');
      }
    }
    _pendingRequests.clear();

    // Закрываем все контроллеры потоков
    for (final controller in _streamControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streamControllers.clear();

    await _transport.close();
  }

  /// Отправляет данные в поток
  ///
  /// [streamId] - ID потока
  /// [data] - данные для отправки
  /// [metadata] - дополнительные метаданные
  Future<void> sendStreamData(
    String streamId,
    dynamic data, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = RpcMessage(
      type: RpcMessageType.streamData,
      id: streamId,
      payload: data,
      metadata: metadata,
    );

    await _sendMessage(message);
  }

  /// Отправляет сигнал об ошибке в поток
  ///
  /// [streamId] - ID потока
  /// [error] - сообщение об ошибке
  /// [metadata] - дополнительные метаданные
  Future<void> sendStreamError(
    String streamId,
    String error, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = RpcMessage(
      type: RpcMessageType.error,
      id: streamId,
      payload: error,
      metadata: metadata,
    );

    await _sendMessage(message);
  }

  /// Закрывает поток
  ///
  /// [streamId] - ID потока
  /// [metadata] - дополнительные метаданные
  Future<void> closeStream(
    String streamId, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = RpcMessage(
      type: RpcMessageType.streamEnd,
      id: streamId,
      metadata: metadata,
    );

    await _sendMessage(message);
  }
}
