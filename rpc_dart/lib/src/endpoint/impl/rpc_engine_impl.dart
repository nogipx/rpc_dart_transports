// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Базовая реализация конечной точки для обмена сообщениями
///
/// Этот класс является внутренней реализацией и не должен использоваться напрямую.
/// Для публичного API используйте [RpcEndpoint].
final class _RpcEngineImpl implements IRpcEngine {
  /// Транспорт для отправки/получения сообщений
  final IRpcTransport _transport;
  @override
  IRpcTransport get transport => _transport;

  /// Сериализатор для преобразования сообщений
  final IRpcSerializer _serializer;
  @override
  IRpcSerializer get serializer => _serializer;

  /// Реестр методов
  final IRpcMethodRegistry _registry;
  @override
  IRpcMethodRegistry get registry => _registry;

  /// Метка для отладки
  final String? debugLabel;

  /// Менеджер запросов для хранения и управления запросами
  final _RequestManager _requestManager = _RequestManager();

  /// Менеджер потоков для хранения и управления потоками данных
  final _StreamManager _streamManager = _StreamManager();

  /// Обработчик сообщений для диспетчеризации
  late final _MessageDispatcher _messageDispatcher;

  /// Исполнитель middleware-цепочки
  final _MiddlewareExecutor _middlewareExecutor = _MiddlewareExecutor();

  /// Подписка на входящие сообщения
  StreamSubscription<Uint8List>? _subscription;

  /// Генератор уникальных ID
  late final RpcUniqueIdGenerator _uniqueIdGenerator;

  /// Логгер
  final RpcLogger _logger = RpcLogger('RpcEngine');

  /// Создаёт новую конечную точку
  ///
  /// [transport] - транспорт для обмена сообщениями
  /// [serializer] - сериализатор для преобразования сообщений
  /// [debugLabel] - опциональная метка для отладки и логирования
  _RpcEngineImpl({
    required IRpcTransport transport,
    required IRpcSerializer serializer,
    required IRpcMethodRegistry registry,
    this.debugLabel,
    RpcUniqueIdGenerator? uniqueIdGenerator,
  })  : _transport = transport,
        _serializer = serializer,
        _registry = registry {
    _uniqueIdGenerator = uniqueIdGenerator ?? _defaultUniqueIdGenerator;
    _messageDispatcher = _MessageDispatcher(this);
    _initialize();
  }

  @override
  String generateUniqueId([String? prefix]) => _uniqueIdGenerator(prefix);

  /// Инициализирует конечную точку
  void _initialize() {
    _subscription = _transport.receive().listen(_handleIncomingData);
  }

  /// Добавляет middleware для обработки запросов и ответов
  ///
  /// [middleware] - объект, реализующий интерфейс RpcMiddleware
  @override
  void addMiddleware(IRpcMiddleware middleware) {
    _middlewareExecutor.addMiddleware(middleware);
  }

  /// Регистрирует обработчик метода
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [handler] - функция обработки запроса, которая принимает контекст вызова
  @override
  void registerMethod({
    required String serviceName,
    required String methodName,
    required dynamic handler,
    RpcMethodType? methodType,
    Function? argumentParser,
    Function? responseParser,
  }) {
    // Регистрируем метод в реестре
    _registry.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: methodType,
      handler: handler,
      argumentParser: argumentParser,
      responseParser: responseParser,
    );
  }

  /// Вызывает удаленный метод и возвращает результат
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [request] - данные запроса
  /// [timeout] - таймаут ожидания ответа
  /// Возвращает Future с результатом вызова
  @override
  Future<dynamic> invoke({
    required String serviceName,
    required String methodName,
    required dynamic request,
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) async {
    final requestId = generateUniqueId('request');
    final completer = _requestManager.registerRequest(requestId);

    final message = RpcMessage(
      type: RpcMessageType.request,
      messageId: requestId,
      serviceName: serviceName,
      methodName: methodName,
      payload: request,
      headerMetadata: metadata,
      debugLabel: debugLabel,
    );

    // Отправляем запрос
    await _sendMessage(message);

    // Если указан таймаут, устанавливаем deadline
    if (timeout != null) {
      // Используем новый механизм установки дедлайна
      await setDeadline(
        requestId: requestId,
        timeout: timeout,
        serviceName: serviceName,
        methodName: methodName,
      );
    }

    return completer.future;
  }

  /// Открывает поток для обмена данными с удаленной стороной
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [request] - начальный запрос (опционально). Если это маркер инициализации стрима,
  ///             он будет отправлен как есть.
  /// [metadata] - дополнительные метаданные
  /// [streamId] - опциональный ID для потока, если не указан, будет сгенерирован
  /// Возвращает Stream с данными от удаленной стороны
  @override
  Stream<dynamic> openStream({
    required String serviceName,
    required String methodName,
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Используем переданный streamId или генерируем новый
    final actualStreamId = streamId ?? generateUniqueId('stream');

    // Создаем logger для отладки
    final logger = RpcLogger('RpcEngine.openStream');
    logger
        .debug('Открытие потока $actualStreamId для $serviceName.$methodName');

    // Получаем или создаем поток
    final stream = _streamManager.getOrCreateStream(actualStreamId);

    // Если стрим уже существует, убедимся что контроллер не закрыт
    if (!_streamManager.hasStream(actualStreamId)) {
      logger.debug('Контроллер для $actualStreamId не найден, создаем новый');
      _streamManager.getOrCreateStream(actualStreamId);
    } else {
      logger.debug('Контроллер для $actualStreamId уже существует');
    }

    // Проверяем, является ли запрос маркером инициализации стрима
    final isClientStreamInit = RpcMarkerHandler.isServiceMarker(request) &&
        (request is Map &&
                request['_markerType'] ==
                    RpcMarkerType.clientStreamingInit.name ||
            request is RpcClientStreamingMarker);

    final isBidirectionalInit = RpcMarkerHandler.isServiceMarker(request) &&
        (request is Map &&
                request['_markerType'] == RpcMarkerType.bidirectional.name ||
            request is RpcBidirectionalStreamingMarker);

    // Для bidirectional и client streaming маркеров мы отдельно регистрируем контроллер
    if (isClientStreamInit || isBidirectionalInit) {
      logger.debug(
          'Обнаружен маркер инициализации стрима: ${isClientStreamInit ? 'клиентский' : 'двунаправленный'}');
    }

    final message = RpcMessage(
      type: RpcMessageType.request,
      messageId: actualStreamId,
      serviceName: serviceName,
      methodName: methodName,
      payload: request,
      headerMetadata: metadata,
      debugLabel: debugLabel,
    );

    _sendMessage(message);

    return stream;
  }

  /// Обрабатывает входящие данные и направляет их в диспетчер сообщений
  Future<void> _handleIncomingData(Uint8List data) async {
    // Десериализуем данные в сообщение
    final Map<String, dynamic> json = _serializer.deserialize(data);
    final message = RpcMessage.fromJson(json);

    // Логирование типа сообщения для отладки
    _logger.debug(
        '← Получено сообщение типа ${message.type.name} [${message.messageId}] '
        '${message.serviceName != null ? "${message.serviceName}." : ""}${message.methodName ?? ""}');

    // Перенаправляем сообщение в диспетчер для обработки
    await _messageDispatcher.dispatch(message);
  }

  /// Отправляет сообщение об ошибке
  Future<void> _sendErrorMessage(
    String requestId,
    String errorMessage,
    Map<String, dynamic>? headerMetadata, [
    Map<String, dynamic>? trailerMetadata,
  ]) async {
    await _sendMessage(
      RpcMessage(
        type: RpcMessageType.error,
        messageId: requestId,
        payload: errorMessage,
        headerMetadata: headerMetadata,
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
    _requestManager.completeAllWithError('Endpoint closed');

    // Закрываем все контроллеры потоков
    _streamManager.closeAllStreams();

    final diagnostic = RpcLoggerSettings.diagnostic;
    if (diagnostic != null) {
      RpcLoggerSettings.removeDiagnostic();
      await diagnostic.dispose();
    }

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
  Future<void> sendStreamData({
    required String streamId,
    required dynamic data,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Проверка на null и конвертация в пустой объект для совместимости с MsgPack
    data ??= {'_empty': true};
    // Если указаны имена сервиса и метода, обрабатываем данные через middleware
    dynamic processedData = data;
    if (serviceName != null && methodName != null) {
      processedData = await _middlewareExecutor.executeStreamData(
        serviceName,
        methodName,
        data,
        streamId,
        RpcDataDirection.toRemote, // Данные отправляются удаленной стороне
      );
    }

    final message = RpcMessage(
      type: RpcMessageType.streamData,
      messageId: streamId,
      serviceName: serviceName,
      methodName: methodName,
      payload: processedData,
      headerMetadata: metadata,
      debugLabel: debugLabel,
    );

    await _sendMessage(message);
  }

  /// Отправляет сигнал об ошибке в поток
  ///
  /// [streamId] - ID потока
  /// [error] - сообщение об ошибке
  /// [metadata] - дополнительные метаданные
  /// [serviceName] - имя сервиса (опционально, для middleware)
  /// [methodName] - имя метода (опционально, для middleware)
  @override
  Future<void> sendStreamError({
    required String streamId,
    required String errorMessage,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    final message = RpcMessage(
      type: RpcMessageType.error,
      messageId: streamId,
      serviceName: serviceName,
      methodName: methodName,
      payload: errorMessage,
      headerMetadata: metadata,
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
  Future<void> closeStream({
    required String streamId,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Если указаны имена сервиса и метода, уведомляем middleware о закрытии потока
    if (serviceName != null && methodName != null) {
      await _middlewareExecutor.executeStreamEnd(
        serviceName,
        methodName,
        streamId,
      );
    }

    await _sendMessage(
      RpcMessage(
        type: RpcMessageType.streamEnd,
        messageId: streamId,
        serviceName: serviceName,
        methodName: methodName,
        headerMetadata: metadata,
        debugLabel: debugLabel,
      ),
    );
  }

  /// Отправляет ping-сообщение для проверки соединения
  /// Возвращает Future, который завершится когда придет ответ или произойдет таймаут
  @override
  Future<Duration> sendPing({Duration? timeout}) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final pingId = generateUniqueId('ping');
    final completer = _requestManager.registerRequest(pingId);

    // Устанавливаем таймаут (по умолчанию 5 секунд)
    final effectiveTimeout = timeout ?? const Duration(seconds: 5);
    final timer = Timer(effectiveTimeout, () {
      final pendingRequest = _requestManager.getAndRemoveRequest(pingId);
      if (pendingRequest != null && !pendingRequest.isCompleted) {
        pendingRequest
            .completeError(TimeoutException('Ping timeout', effectiveTimeout));
      }
    });

    // Создаем маркер ping и отправляем через универсальный метод
    final pingMarker = RpcPingMarker();
    await sendServiceMarker(
      streamId: pingId,
      marker: pingMarker,
      metadata: null,
    );

    try {
      // Ожидаем ответ и вычисляем RTT
      final response = await completer.future;
      timer.cancel();

      try {
        // Парсим ответ для получения временных меток
        if (response is Map<String, dynamic>) {
          final pongMarker = RpcPongMarker.fromJson(response);
          return Duration(
              milliseconds: pongMarker.responseTimestamp - startTime);
        } else {
          // Некорректный формат ответа
          throw FormatException('Invalid pong response format');
        }
      } catch (e) {
        rethrow;
      }
    } catch (e) {
      timer.cancel();
      rethrow;
    }
  }

  /// Отправляет маркер завершения потока в клиентском стриминге
  /// Это специальный метод, который избегает проблем с приведением типов
  @override
  Future<void> sendClientStreamEnd({
    required String streamId,
    String? serviceName,
    String? methodName,
    Map<String, dynamic>? metadata,
  }) async {
    // Используем новый универсальный метод с маркером RpcClientStreamEndMarker
    await sendServiceMarker(
      streamId: streamId,
      marker: const RpcClientStreamEndMarker(),
      serviceName: serviceName,
      methodName: methodName,
      metadata: metadata,
    );
  }

  /// Отправляет любой служебный маркер
  /// Унифицированный метод для отправки любых типов маркеров
  ///
  /// [streamId] - ID потока или соединения
  /// [marker] - служебный маркер для отправки
  /// [serviceName] - имя сервиса (опционально, для middleware)
  /// [methodName] - имя метода (опционально, для middleware)
  /// [metadata] - дополнительные метаданные
  @override
  Future<void> sendServiceMarker({
    required String streamId,
    required RpcServiceMarker marker,
    String? serviceName,
    String? methodName,
    Map<String, dynamic>? metadata,
  }) async {
    // В зависимости от типа маркера, может потребоваться специфическая логика
    RpcMessageType messageType = RpcMessageType.streamData;

    // Специальная обработка для ping маркера
    if (marker is RpcPingMarker) {
      messageType = RpcMessageType.ping;
    }

    // Отправляем маркер через стандартное сообщение
    await _sendMessage(
      RpcMessage(
        type: messageType,
        messageId: streamId,
        serviceName: serviceName,
        methodName: methodName,
        payload: marker.toJson(),
        headerMetadata: metadata,
        debugLabel: debugLabel,
      ),
    );
  }

  /// Отправляет маркер статуса операции
  ///
  /// [requestId] - ID запроса или операции
  /// [statusCode] - код статуса операции
  /// [message] - описание статуса или ошибки
  /// [details] - дополнительные детали (опционально)
  /// [metadata] - дополнительные метаданные (опционально)
  @override
  Future<void> sendStatus({
    required String requestId,
    required RpcStatusCode statusCode,
    required String message,
    Map<String, dynamic>? details,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Создаем маркер статуса
    final statusMarker = RpcStatusMarker(
      code: statusCode,
      message: message,
      details: details,
    );

    // Используем универсальный метод для отправки маркера
    await sendServiceMarker(
      streamId: requestId,
      marker: statusMarker,
      serviceName: serviceName,
      methodName: methodName,
      metadata: metadata,
    );

    // Если это ошибочный статус (не OK), также отправляем сообщение об ошибке
    // для обратной совместимости
    if (statusCode != RpcStatusCode.ok) {
      await _sendErrorMessage(
        requestId,
        message,
        metadata,
        details,
      );
    }
  }

  /// Устанавливает deadline для операции
  ///
  /// [requestId] - ID запроса или операции
  /// [timeout] - таймаут для операции
  /// [metadata] - дополнительные метаданные (опционально)
  @override
  Future<void> setDeadline({
    required String requestId,
    required Duration timeout,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Создаем маркер дедлайна
    final deadlineMarker = RpcDeadlineMarker.fromDuration(timeout);

    // Отправляем маркер
    await sendServiceMarker(
      streamId: requestId,
      marker: deadlineMarker,
      serviceName: serviceName,
      methodName: methodName,
      metadata: metadata,
    );

    // Устанавливаем таймер для автоматического прерывания операции
    Timer(timeout, () {
      // Проверяем, не завершена ли уже операция
      final completer = _requestManager.getRequest(requestId);
      if (completer != null && !completer.isCompleted) {
        // Отправляем статус о превышении времени ожидания
        sendStatus(
          requestId: requestId,
          statusCode: RpcStatusCode.deadlineExceeded,
          message: 'Превышено время ожидания (${timeout.inMilliseconds} мс)',
          serviceName: serviceName,
          methodName: methodName,
        );

        // Завершаем запрос с ошибкой
        _requestManager.completeRequestWithError(
            requestId, TimeoutException('Deadline exceeded', timeout));
      }
    });
  }

  /// Отменяет операцию
  ///
  /// [operationId] - ID операции для отмены
  /// [reason] - причина отмены (опционально)
  /// [details] - дополнительные детали (опционально)
  @override
  Future<void> cancelOperation({
    required String operationId,
    String? reason,
    Map<String, dynamic>? details,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Создаем маркер отмены
    final cancelMarker = RpcCancelMarker(
      operationId: operationId,
      reason: reason,
      details: details,
    );

    // Отправляем маркер
    await sendServiceMarker(
      streamId: operationId,
      marker: cancelMarker,
      serviceName: serviceName,
      methodName: methodName,
      metadata: metadata,
    );

    // Отправляем статус отмены для гарантированного завершения
    await sendStatus(
      requestId: operationId,
      statusCode: RpcStatusCode.cancelled,
      message: reason ?? 'Операция отменена клиентом',
      details: details,
      serviceName: serviceName,
      methodName: methodName,
    );

    // Завершаем ожидающий запрос, если он есть
    _requestManager.completeRequestWithError(
        operationId, reason ?? 'Operation cancelled');

    // Закрываем поток, если он есть
    final controller = _streamManager.getStreamController(operationId);
    if (controller != null && !controller.isClosed) {
      controller.addError(reason ?? 'Operation cancelled');
      _streamManager.closeStream(operationId);
    }
  }
}
