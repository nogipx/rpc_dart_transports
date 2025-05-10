// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Базовая реализация конечной точки для обмена сообщениями
///
/// Этот класс является внутренней реализацией и не должен использоваться напрямую.
/// Для публичного API используйте [RpcEndpoint].
final class _RpcEndpointCoreImpl<T extends IRpcSerializableMessage>
    implements _IRpcEndpointCore<T> {
  /// Транспорт для отправки/получения сообщений
  final RpcTransport _transport;
  @override
  RpcTransport get transport => _transport;

  /// Сериализатор для преобразования сообщений
  final RpcSerializer _serializer;
  @override
  RpcSerializer get serializer => _serializer;

  /// Метка для отладки
  final String? debugLabel;

  /// Обработчики ожидающих ответов
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  /// Контроллеры потоков данных
  final Map<String, StreamController<dynamic>> _streamControllers = {};

  /// Обработчики методов по имени сервиса и метода
  final Map<String, Map<String, Future<dynamic> Function(RpcMethodContext)>>
      _methodHandlers = {};

  /// Цепочка middleware для обработки запросов и ответов
  final RpcMiddlewareChain _middlewareChain = RpcMiddlewareChain();

  /// Подписка на входящие сообщения
  StreamSubscription<Uint8List>? _subscription;

  /// Создаёт новую конечную точку
  ///
  /// [transport] - транспорт для обмена сообщениями
  /// [serializer] - сериализатор для преобразования сообщений
  /// [debugLabel] - опциональная метка для отладки и логирования
  _RpcEndpointCoreImpl(this._transport, this._serializer, {this.debugLabel}) {
    _initialize();
  }

  /// Инициализирует конечную точку
  void _initialize() {
    _subscription = _transport.receive().listen(_handleIncomingData);
  }

  /// Добавляет middleware для обработки запросов и ответов
  ///
  /// [middleware] - объект, реализующий интерфейс RpcMiddleware
  @override
  void addMiddleware(IRpcMiddleware middleware) {
    _middlewareChain.add(middleware);
  }

  /// Регистрирует обработчик метода
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [handler] - функция обработки запроса, которая принимает контекст вызова
  @override
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
  @override
  Future<dynamic> invoke(
    String serviceName,
    String methodName,
    dynamic request, {
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) async {
    final requestId = RpcMethod.generateUniqueId('request');
    final completer = Completer<dynamic>();
    _pendingRequests[requestId] = completer;

    final message = RpcMessage(
      type: RpcMessageType.request,
      id: requestId,
      service: serviceName,
      method: methodName,
      payload: request,
      metadata: metadata,
      debugLabel: debugLabel,
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
  @override
  Stream<dynamic> openStream(
    String serviceName,
    String methodName, {
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Используем переданный streamId или генерируем новый
    final actualStreamId = streamId ?? RpcMethod.generateUniqueId('stream');

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
      debugLabel: debugLabel,
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
        message.id,
        'Не указаны serviceName или methodName',
        message.metadata,
      );
      return;
    }

    final methodHandler = _methodHandlers[serviceName]?[methodName];
    if (methodHandler == null) {
      await _sendErrorMessage(
        message.id,
        'Метод не найден: $serviceName.$methodName',
        message.metadata,
      );
      return;
    }

    var direction = RpcDataDirection.fromRemote;

    try {
      // Создаем контекст вызова метода
      final context = RpcMethodContext(
        messageId: message.id,
        metadata: message.metadata,
        headerMetadata: message.metadata,
        payload: message.payload,
        serviceName: serviceName,
        methodName: methodName,
      );

      // Применяем middleware для обработки запроса
      dynamic processedPayload = await _middlewareChain.executeRequest(
        serviceName,
        methodName,
        message.payload,
        context,
        RpcDataDirection.fromRemote,
      );

      // Создаем обновленный контекст с обработанной полезной нагрузкой
      final updatedContext = MutableRpcMethodContext(
        messageId: message.id,
        metadata: message.metadata,
        headerMetadata: context.headerMetadata,
        payload: processedPayload,
        serviceName: serviceName,
        methodName: methodName,
      );

      // Вызываем обработчик с обновленным контекстом
      final result = await methodHandler(updatedContext);

      // Изменяем направление на отправку
      direction = RpcDataDirection.toRemote;

      // Применяем middleware для обработки ответа
      final processedResult = await _middlewareChain.executeResponse(
        serviceName,
        methodName,
        result,
        updatedContext,
        RpcDataDirection.toRemote,
      );

      await _sendMessage(
        RpcMessage(
          type: RpcMessageType.response,
          id: message.id,
          payload: processedResult,
          metadata: updatedContext.headerMetadata,
          trailerMetadata: updatedContext.trailerMetadata,
          debugLabel: debugLabel,
        ),
      );
    } catch (e, stackTrace) {
      // Создаем контекст для ошибки
      final errorContext = RpcMethodContext(
        messageId: message.id,
        metadata: message.metadata,
        headerMetadata: message.metadata,
        payload: message.payload,
        serviceName: serviceName,
        methodName: methodName,
      );

      // Применяем middleware для обработки ошибки
      final processedError = await _middlewareChain.executeError(
        serviceName,
        methodName,
        e,
        stackTrace,
        errorContext,
        direction,
      );

      // Если errorContext был преобразован в мутабельный внутри middleware,
      // нам нужно получить актуальные метаданные
      final mutableErrorContext = errorContext is MutableRpcMethodContext
          ? errorContext
          : errorContext.toMutable();

      await _sendErrorMessage(
        message.id,
        processedError.toString(),
        mutableErrorContext.headerMetadata,
        mutableErrorContext.trailerMetadata,
      );
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
      // Если известны имена сервиса и метода, применяем middleware
      if (message.service != null && message.method != null) {
        _middlewareChain
            .executeStreamData(
          message.service!,
          message.method!,
          message.payload,
          message.id,
          RpcDataDirection.fromRemote, // Данные получены от удаленной стороны
        )
            .then((processedData) {
          controller.add(processedData);
        }).catchError((error) {
          controller.addError(error);
        });
      } else {
        controller.add(message.payload);
      }
    }
  }

  /// Обрабатывает завершение потока
  void _handleStreamEnd(RpcMessage message) {
    final controller = _streamControllers.remove(message.id);
    if (controller != null && !controller.isClosed) {
      // Если известны имена сервиса и метода, применяем middleware
      if (message.service != null && message.method != null) {
        _middlewareChain
            .executeStreamEnd(
          message.service!,
          message.method!,
          message.id,
        )
            .then((_) {
          controller.close();
        }).catchError((error) {
          controller.addError(error);
          controller.close();
        });
      } else {
        controller.close();
      }
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
        debugLabel: debugLabel,
      ),
    );
  }

  /// Отправляет сообщение об ошибке
  Future<void> _sendErrorMessage(String requestId, String errorMessage,
      Map<String, dynamic>? headerMetadata,
      [Map<String, dynamic>? trailerMetadata]) async {
    await _sendMessage(
      RpcMessage(
        type: RpcMessageType.error,
        id: requestId,
        payload: errorMessage,
        metadata: headerMetadata,
        trailerMetadata: trailerMetadata,
        debugLabel: debugLabel,
      ),
    );
  }

  /// Отправляет сообщение через транспорт
  Future<void> _sendMessage(RpcMessage message) async {
    final data = _serializer.serialize(message.toJson());
    await _transport.send(data);
  }

  /// Проверяет, активна ли конечная точка
  @override
  bool get isActive => _transport.isAvailable;

  /// Закрывает конечную точку
  @override
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
  /// [serviceName] - имя сервиса (опционально, для middleware)
  /// [methodName] - имя метода (опционально, для middleware)
  @override
  Future<void> sendStreamData(
    String streamId,
    dynamic data, {
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Если указаны имена сервиса и метода, обрабатываем данные через middleware
    dynamic processedData = data;
    if (serviceName != null && methodName != null) {
      processedData = await _middlewareChain.executeStreamData(
        serviceName,
        methodName,
        data,
        streamId,
        RpcDataDirection.toRemote, // Данные отправляются удаленной стороне
      );
    }

    final message = RpcMessage(
      type: RpcMessageType.streamData,
      id: streamId,
      service: serviceName,
      method: methodName,
      payload: processedData,
      metadata: metadata,
      debugLabel: debugLabel,
    );

    await _sendMessage(message);
  }

  /// Отправляет сигнал об ошибке в поток
  ///
  /// [streamId] - ID потока
  /// [error] - сообщение об ошибке
  /// [metadata] - дополнительные метаданные
  @override
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
      debugLabel: debugLabel,
    );

    await _sendMessage(message);
  }

  /// Закрывает поток
  ///
  /// [streamId] - ID потока
  /// [metadata] - дополнительные метаданные
  /// [serviceName] - имя сервиса (опционально, для middleware)
  /// [methodName] - имя метода (опционально, для middleware)
  @override
  Future<void> closeStream(
    String streamId, {
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Если указаны имена сервиса и метода, уведомляем middleware о закрытии потока
    if (serviceName != null && methodName != null) {
      await _middlewareChain.executeStreamEnd(
        serviceName,
        methodName,
        streamId,
      );
    }

    final message = RpcMessage(
      type: RpcMessageType.streamEnd,
      id: streamId,
      service: serviceName,
      method: methodName,
      metadata: metadata,
      debugLabel: debugLabel,
    );

    await _sendMessage(message);
  }

  @override
  BidirectionalRpcMethod<T> bidirectional(
    String serviceName,
    String methodName,
  ) {
    throw UnimplementedError();
  }

  @override
  ClientStreamingRpcMethod<T> clientStreaming(
    String serviceName,
    String methodName,
  ) {
    throw UnimplementedError();
  }

  @override
  ServerStreamingRpcMethod<T> serverStreaming(
    String serviceName,
    String methodName,
  ) {
    throw UnimplementedError();
  }

  @override
  UnaryRpcMethod<T> unary(
    String serviceName,
    String methodName,
  ) {
    throw UnimplementedError();
  }
}
