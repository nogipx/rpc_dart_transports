part of '_index.dart';

typedef _MethodCallInfo = ({
  int streamId,
  String serviceName,
  String methodName,
  RpcMethodRegistration method,
  RpcTransportMessage? message,
});

/// Серверный RPC эндпоинт для обработки запросов
final class RpcResponderEndpoint extends RpcEndpointBase {
  @override
  RpcLogger get logger => RpcLogger(
        'RpcResponderEndpoint',
        colors: loggerColors,
        label: debugLabel,
      );

  final Map<String, dynamic> _contracts = {};
  final Map<String, RpcMethodRegistration> _methods = {};
  bool _isListening = false;

  /// Сохраняем информацию о методах для потоков
  final Map<int, String> _streamMethods = {};

  /// Сохраняем последнее сообщение с данными для каждого потока
  final Map<int, RpcTransportMessage> _streamMessages = {};

  Map<String, dynamic> get registeredContracts => Map.unmodifiable(_contracts);

  Map<String, RpcMethodRegistration> get registeredMethods =>
      Map.unmodifiable(_methods);

  RpcResponderEndpoint({
    required super.transport,
    super.debugLabel,
    super.loggerColors,
  });

  @override
  void start() {
    super.start();

    if (_isListening) {
      logger.warning(
        'RpcResponderEndpoint уже слушает входящие запросы',
      );
      return;
    }

    _isListening = true;
    transport.incomingMessages.listen(
      _handleIncomingMessage,
    );
  }

  /// Этап 2: Обрабатывает входящее сообщение от транспорта
  void _handleIncomingMessage(RpcTransportMessage message) {
    final streamId = message.streamId;

    // Обработка метаданных (заголовков) сообщения
    if (message.isMetadataOnly && message.methodPath != null) {
      _handleMetadataMessage(streamId, message);
      return;
    }

    // Обработка сообщения с данными
    if (!message.isMetadataOnly && message.payload != null) {
      // Сохраняем сообщение с данными
      _streamMessages[streamId] = message;
      _handleDataMessage(streamId, message);
    }

    // Очищаем информацию о потоке при его завершении
    if (message.isEndOfStream) {
      _cleanupStream(streamId);
    }
  }

  /// Этап 2.1: Обрабатывает метаданные сообщения (заголовки)
  void _handleMetadataMessage(int streamId, RpcTransportMessage message) {
    final methodPath = message.methodPath!;
    final methodInfo = _parseMethodPath(methodPath);

    if (methodInfo == null) {
      logger.warning(
        'Некорректный путь метода: $methodPath',
      );
      return;
    }

    final serviceName = methodInfo.$1;
    final methodName = methodInfo.$2;
    final methodKey = '$serviceName.$methodName';

    logger.info(
      'Получено сообщение метаданных: $methodKey [streamId: $streamId]',
    );

    // Сохраняем метод для этого потока
    _streamMethods[streamId] = methodKey;

    // Проверяем наличие метода
    if (!_methods.containsKey(methodKey)) {
      logger.error(
        'Метод $methodKey не зарегистрирован',
      );
      return;
    }
  }

  /// Этап 2.2: Обрабатывает сообщение с данными
  void _handleDataMessage(int streamId, RpcTransportMessage message) {
    // Если для этого потока еще не определен метод, и это первое сообщение,
    // проверяем наличие methodPath в сообщении
    if (!_streamMethods.containsKey(streamId) && message.methodPath != null) {
      final methodPath = message.methodPath!;
      final methodInfo = _parseMethodPath(methodPath);

      if (methodInfo == null) {
        logger.warning(
          'Некорректный путь метода: $methodPath',
        );
        return;
      }

      final serviceName = methodInfo.$1;
      final methodName = methodInfo.$2;
      final methodKey = '$serviceName.$methodName';

      logger.info(
        'Получено сообщение с данными и методом: $methodKey [streamId: $streamId]',
      );

      // Сохраняем метод для этого потока
      _streamMethods[streamId] = methodKey;

      // Проверяем наличие метода
      if (!_methods.containsKey(methodKey)) {
        logger.error(
          'Метод $methodKey не зарегистрирован',
        );
        return;
      }
    }

    // Обрабатываем данные, если для этого потока определен метод
    if (_streamMethods.containsKey(streamId)) {
      final methodKey = _streamMethods[streamId]!;
      final parts = methodKey.split(
        '.',
      );
      final serviceName = parts[0];
      final methodName = parts[1];

      logger.info(
        'Обработка данных для метода: $methodKey [streamId: $streamId]',
      );

      _routeMethodCall((
        method: _methods[methodKey]!,
        streamId: streamId,
        serviceName: serviceName,
        methodName: methodName,
        message: message,
      ));
    } else {
      logger.warning(
        'Получены данные для неизвестного метода [streamId: $streamId]',
      );
    }
  }

  /// Этап 2.3: Очищает информацию о потоке при его завершении
  void _cleanupStream(int streamId) {
    logger.debug(
      'Поток завершен [streamId: $streamId]',
    );
    _streamMethods.remove(streamId);
    _streamMessages.remove(streamId);
  }

  /// Этап 3: Парсинг пути метода из строки формата /service/method
  (String, String)? _parseMethodPath(String methodPath) {
    final parts = methodPath.split(
      '/',
    );

    if (parts.length != 3 || parts[0].isNotEmpty) {
      return null;
    }

    return (parts[1], parts[2]);
  }

  /// Этап 4: Маршрутизация вызова метода к нужному обработчику
  void _routeMethodCall(_MethodCallInfo i) {
    final serviceName = i.serviceName;
    final methodName = i.methodName;
    final streamId = i.streamId;

    logger.info(
      'Обработка вызова метода $serviceName.$methodName [streamId: $streamId]',
    );

    try {
      final handler = switch (i.method.type) {
        RpcMethodType.unaryRequest => _handleUnaryMethod,
        RpcMethodType.clientStream => _handleClientStreamMethod,
        RpcMethodType.serverStream => _handleServerStreamMethod,
        RpcMethodType.bidirectionalStream => _handleBidirectionalMethod,
      };

      handler(i);
    } catch (e, stackTrace) {
      logger.error(
        'Ошибка при создании обработчика для метода $serviceName.$methodName: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Этап 5.1: Обработка унарного метода
  Future<void> _handleUnaryMethod(_MethodCallInfo i) async {
    final serviceName = i.serviceName;
    final methodName = i.methodName;
    final streamId = i.streamId;

    final methodPath = '/$serviceName/$methodName';
    logger.debug(
      'Обработка унарного запроса $methodPath [streamId: $streamId]',
    );

    // Сначала отправляем начальные заголовки
    await _sendInitialHeaders(streamId);

    try {
      // Получаем данные запроса
      final requestData = await _extractRequestData(i);
      if (requestData == null) return;

      // Вызываем обработчик метода
      final response = await _invokeMethodHandler(i, requestData);

      // Отправляем ответ
      await _sendResponse(i, response);
    } catch (e, stackTrace) {
      _handleMethodError(streamId, methodPath, e, stackTrace);
    }
  }

  /// Этап 5.2: Обработка клиентского потокового метода
  void _handleClientStreamMethod(_MethodCallInfo i) {
    // Создаем обработчик клиентского потока
    ClientStreamResponder<IRpcSerializable, IRpcSerializable>(
      transport: transport,
      serviceName: i.serviceName,
      methodName: i.methodName,
      requestCodec: i.method.requestCodec,
      responseCodec: i.method.responseCodec,
      handler: (Stream<dynamic> requests) async {
        return await i.method.handler(requests);
      },
      logger: logger,
    );
  }

  /// Этап 5.3: Обработка серверного потокового метода
  void _handleServerStreamMethod(_MethodCallInfo i) async {
    final serviceName = i.serviceName;
    final methodName = i.methodName;
    final streamId = i.streamId;

    try {
      // Получаем данные запроса
      final requestData = await _extractRequestData(i);
      if (requestData == null) return;

      // Создаем обработчик серверного потока
      ServerStreamResponder(
        transport: transport,
        serviceName: serviceName,
        methodName: methodName,
        requestCodec: i.method.requestCodec,
        responseCodec: i.method.responseCodec,
        handler: (dynamic request, responder) {
          try {
            // Вызываем оригинальный обработчик потока
            final responseStream = i.method.handler();

            responseStream.listen(
              (dynamic response) {
                responder.send(response);
              },
              onError: (error) {
                logger.error(
                  'Ошибка в потоке ответов: $error',
                );
                responder.complete();
              },
              onDone: () {
                responder.complete();
              },
            );
          } catch (e, stack) {
            logger.error(
              'Ошибка при вызове обработчика: $e\n$stack',
            );
            responder.complete();
          }
        },
        logger: logger,
      );
    } catch (e, stackTrace) {
      final methodPath = '/$serviceName/$methodName';
      _handleMethodError(streamId, methodPath, e, stackTrace);
    }
  }

  /// Этап 5.4: Обработка двунаправленного потокового метода
  void _handleBidirectionalMethod(_MethodCallInfo i) {
    final serviceName = i.serviceName;
    final methodName = i.methodName;

    // Создаем обработчик двунаправленного потока
    final responder = BidirectionalStreamResponder(
      transport: transport,
      serviceName: serviceName,
      methodName: methodName,
      requestCodec: i.method.requestCodec,
      responseCodec: i.method.responseCodec,
      logger: logger,
    );

    try {
      // Вызываем оригинальный обработчик с потоком запросов
      final responseStream = i.method.handler();

      // Настраиваем обработку запросов и отправку ответов
      responseStream.listen(
        (dynamic response) {
          responder.send(response);
        },
        onError: (error) {
          logger.error(
            'Ошибка в потоке ответов: $error',
          );
        },
        onDone: () {
          // Просто завершаем обработку
        },
      );
    } catch (e, stack) {
      logger.error(
        'Ошибка при настройке двунаправленного потока: $e\n$stack',
      );
    }
  }

  /// Этап 6: Отправка начальных заголовков ответа
  Future<void> _sendInitialHeaders(int streamId) async {
    await transport.sendMetadata(
      streamId,
      RpcMetadata.forServerInitialResponse(),
    );
  }

  /// Этап 7: Извлечение данных запроса из сообщения
  Future<Uint8List?> _extractRequestData(_MethodCallInfo i) async {
    final streamId = i.streamId;
    final message = i.message;

    // Проверяем наличие сообщения с данными
    if (message == null || message.payload == null) {
      logger.error(
        'Нет сообщения с данными для обработки [streamId: $streamId]',
      );
      await _sendErrorTrailer(
        streamId,
        'Нет сообщения с данными для обработки',
      );
      return null;
    }
    final payload = message.payload ?? Uint8List(0);

    final parser = RpcMessageParser(logger: logger.child('Parser'));

    logger.debug(
      'Получено сообщение с запросом размером ${message.payload!.length} байт [streamId: $streamId]',
    );

    // Используем парсер для извлечения данных из фрейма с префиксом
    final payloads = parser(payload);

    if (payloads.isEmpty) {
      logger.error(
        'Не удалось извлечь данные из сообщения [streamId: $streamId]',
      );
      await _sendErrorTrailer(
        streamId,
        'Не удалось извлечь данные из сообщения',
      );
      return null;
    }

    // Получаем бинарные данные запроса
    return payloads.first;
  }

  /// Этап 8: Вызов обработчика метода
  Future<dynamic> _invokeMethodHandler(
    _MethodCallInfo i,
    Uint8List requestData,
  ) async {
    final streamId = i.streamId;
    final methodPath = i.message!.methodPath!;

    logger.debug(
      'Вызов обработчика для $methodPath [streamId: $streamId]',
    );

    // Десериализуем данные запроса
    final deserializedData = i.method.requestCodec.deserialize(requestData);

    // Вызываем обработчик с десериализованными данными
    final response = i.method.handler(deserializedData);

    logger.debug(
      'Обработчик вернул ответ [streamId: $streamId]',
    );

    return response;
  }

  /// Этап 9: Сериализация и отправка ответа
  Future<void> _sendResponse(_MethodCallInfo i, dynamic response) async {
    final streamId = i.streamId;
    final methodPath = i.message!.methodPath!;

    final serializedResponse = i.method.responseCodec.serialize(response);
    // Кодируем ответ в фрейм и отправляем
    final framedResponse = RpcMessageFrame.encode(serializedResponse);
    logger.debug(
      'Отправка ответа размером ${framedResponse.length} байт [streamId: $streamId]',
    );
    await transport.sendMessage(streamId, framedResponse);

    // Отправляем трейлер с успешным статусом
    await transport.sendMetadata(
      streamId,
      RpcMetadata.forTrailer(RpcStatus.OK),
      endStream: true,
    );

    logger.info(
      'Ответ успешно отправлен для $methodPath [streamId: $streamId]',
    );
  }

  /// Этап 10: Обработка ошибок метода
  Future<void> _handleMethodError(
    int streamId,
    String methodPath,
    dynamic error,
    StackTrace stackTrace,
  ) async {
    logger.error(
      'Ошибка при обработке запроса для $methodPath [streamId: $streamId]',
      error: error,
      stackTrace: stackTrace,
    );

    await _sendErrorTrailer(
      streamId,
      'Ошибка при обработке запроса: $error',
    );
  }

  /// Отправляет трейлер с ошибкой
  Future<void> _sendErrorTrailer(int streamId, String errorMessage) async {
    await transport.sendMetadata(
      streamId,
      RpcMetadata.forTrailer(
        RpcStatus.INTERNAL,
        message: errorMessage,
      ),
      endStream: true,
    );
  }

  /// Регистрирует контракт сервиса
  void registerServiceContract(RpcResponderContract contract) {
    final serviceName = contract.serviceName;

    if (_contracts.containsKey(serviceName)) {
      throw RpcException(
        'Контракт для сервиса $serviceName уже зарегистрирован',
      );
    }

    logger.info(
      'Регистрируем контракт сервиса: $serviceName',
    );
    _contracts[serviceName] = contract;

    // Вызываем setup для регистрации методов в контракте
    contract.setup();

    // Регистрируем методы контракта
    final methods = contract.methods;
    for (final entry in methods.entries) {
      final methodName = entry.key;
      final method = entry.value;

      final methodKey = '$serviceName.$methodName';

      if (_methods.containsKey(methodKey)) {
        throw RpcException(
          'Метод $methodKey уже зарегистрирован',
        );
      }

      logger.info(
        'Регистрируем метод: $methodKey (${method.type.name})',
      );
      _methods[methodKey] = method;
    }

    logger.info(
      'Контракт $serviceName зарегистрирован с ${methods.length} методами',
    );

    // Автоматически запускаем прослушивание после регистрации первого контракта
    if (!_isListening) {
      start();
    }
  }

  /// Проверяет существование метода и его тип
  void validateMethodExists(
    String serviceName,
    String methodName,
    RpcMethodType expectedType,
  ) {
    final methodKey = '$serviceName.$methodName';
    final method = _methods[methodKey];

    if (method == null) {
      throw RpcException(
        'Метод $methodKey не зарегистрирован',
      );
    }

    if (method.type != expectedType) {
      throw RpcException(
        'Метод $methodKey зарегистрирован как ${method.type.name}, '
        'а ожидается ${expectedType.name}',
      );
    }
  }

  /// Получает регистрацию метода по пути
  RpcMethodRegistration _getMethodRegistration(String methodPath) {
    final methodInfo = _parseMethodPath(methodPath);
    if (methodInfo == null) {
      throw RpcException('Некорректный путь метода: $methodPath');
    }

    final serviceName = methodInfo.$1;
    final methodName = methodInfo.$2;
    final methodKey = '$serviceName.$methodName';

    final method = _methods[methodKey];
    if (method == null) {
      throw RpcException('Метод $methodKey не зарегистрирован');
    }

    return method;
  }

  @override
  Future<void> close() async {
    if (!isActive) return;
    _contracts.clear();
    _methods.clear();
    _isListening = false;
    await super.close();
  }
}
