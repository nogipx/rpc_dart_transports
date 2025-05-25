part of '_index.dart';

/// Серверный RPC эндпоинт для обработки запросов
final class RpcResponderEndpoint extends RpcEndpointBase {
  @override
  RpcLogger get logger => RpcLogger(
        'RpcResponderEndpoint[${debugLabel ?? ''}]',
        colors: loggerColors,
      );

  final Map<String, dynamic> _contracts = {};
  final Map<String, RpcMethodRegistration> _methods = {};

  RpcResponderEndpoint({
    required super.transport,
    super.debugLabel,
    super.loggerColors,
  });

  /// Регистрирует контракт сервиса
  void registerServiceContract(RpcResponderContract contract) {
    final serviceName = contract.serviceName;

    if (_contracts.containsKey(serviceName)) {
      throw RpcException(
        'Контракт для сервиса $serviceName уже зарегистрирован',
      );
    }

    logger.info('Регистрируем контракт сервиса: $serviceName');
    _contracts[serviceName] = contract;
    contract.setup();

    final methods = contract.methods;
    for (final entry in methods.entries) {
      final methodName = entry.key;
      final method = entry.value;
      _registerMethod(
        serviceName: serviceName,
        methodName: methodName,
        method: method,
      );
    }

    logger.info(
      'Контракт $serviceName зарегистрирован с ${methods.length} методами',
    );

    // Автоматически запускаем прослушивание после регистрации первого контракта
    if (!_isListening) {
      start();
    }
  }

  void _registerMethod({
    required String serviceName,
    required String methodName,
    required RpcMethodRegistration method,
  }) {
    final methodKey = '$serviceName.$methodName';
    if (_methods.containsKey(methodKey)) {
      throw RpcException('Метод $methodKey уже зарегистрирован');
    }
    _methods[methodKey] = method;
    logger.info('Зарегистрирован метод: $methodKey (${method.type.name})');
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
      throw RpcException('Метод $methodKey не зарегистрирован');
    }

    if (method.type != expectedType) {
      throw RpcException(
        'Метод $methodKey зарегистрирован как ${method.type.name}, '
        'а ожидается ${expectedType.name}',
      );
    }
  }

  Map<String, dynamic> get registeredContracts => Map.unmodifiable(_contracts);

  Map<String, RpcMethodRegistration> get registeredMethods =>
      Map.unmodifiable(_methods);

  bool _isListening = false;

  @override
  Future<void> close() async {
    if (!isActive) return;
    _contracts.clear();
    _methods.clear();
    _isListening = false;
    await super.close();
  }

  void start() {
    if (_isListening) {
      logger.warning('RpcResponderEndpoint уже слушает входящие запросы');
      return;
    }

    logger.info('Запуск прослушивания входящих RPC-запросов');
    _isListening = true;

    _transport.incomingMessages.listen((message) {
      if (message.isMetadataOnly && message.methodPath != null) {
        // Получили запрос на новый метод, надо определить какой это метод и создать соответствующий обработчик
        final methodPath = message.methodPath!;
        final parts = methodPath.split('/');
        if (parts.length != 3 || parts[0].isNotEmpty) {
          logger.warning('Некорректный путь метода: $methodPath');
          return;
        }

        final serviceName = parts[1];
        final methodName = parts[2];
        final methodKey = '$serviceName.$methodName';

        final method = _methods[methodKey];
        if (method == null) {
          logger.warning('Метод $methodKey не зарегистрирован');
          return;
        }

        // Создаем соответствующий обработчик в зависимости от типа метода
        // и передаем ему управление
        _handleMethodCall(method, message.streamId, serviceName, methodName);
      }
    });

    logger.info('RpcResponderEndpoint запущен и слушает входящие запросы');
  }

  /// Создает и настраивает обработчик RPC метода в зависимости от его типа
  void _handleMethodCall(
    RpcMethodRegistration method,
    int streamId,
    String serviceName,
    String methodName,
  ) {
    logger.info(
        'Обработка вызова метода $serviceName.$methodName [streamId: $streamId]');

    // Получаем сериализаторы для типов сообщений
    try {
      switch (method.type) {
        case RpcMethodType.unary:
          logger.debug('Создание UnaryResponder для $serviceName.$methodName');
          final handler = method.handler as Future<dynamic> Function(dynamic);

          // Создаем унарный обработчик
          UnaryResponder(
            transport: transport,
            serviceName: serviceName,
            methodName: methodName,
            requestSerializer:
                _createDynamicSerializer(method.serializationFormat),
            responseSerializer:
                _createDynamicSerializer(method.serializationFormat),
            handler: handler,
            logger: logger,
          );
          break;

        case RpcMethodType.serverStream:
          logger.debug(
              'Создание ServerStreamResponder для $serviceName.$methodName');
          final handler = method.handler as Stream<dynamic> Function(dynamic);

          // Создаем обработчик серверного стрима
          ServerStreamResponder(
            transport: transport,
            serviceName: serviceName,
            methodName: methodName,
            requestSerializer:
                _createDynamicSerializer(method.serializationFormat),
            responseSerializer:
                _createDynamicSerializer(method.serializationFormat),
            handler: (request, responder) {
              final responseStream = handler(request);
              responseStream.listen(
                responder.send,
                onError: (error) {
                  logger.error('Ошибка в потоке ответов: $error');
                  responder.complete();
                },
                onDone: () {
                  responder.complete();
                },
              );
            },
            logger: logger,
          );
          break;

        case RpcMethodType.clientStream:
          logger.debug(
              'Создание ClientStreamResponder для $serviceName.$methodName');
          final handler =
              method.handler as Future<dynamic> Function(Stream<dynamic>);

          // Создаем обработчик клиентского стрима
          ClientStreamResponder(
            transport: transport,
            serviceName: serviceName,
            methodName: methodName,
            requestSerializer:
                _createDynamicSerializer(method.serializationFormat),
            responseSerializer:
                _createDynamicSerializer(method.serializationFormat),
            handler: handler,
            logger: logger,
          );
          break;

        case RpcMethodType.bidirectional:
          logger.debug(
              'Создание BidirectionalStreamResponder для $serviceName.$methodName');

          // Создаем двунаправленный стрим
          final responder = BidirectionalStreamResponder(
            transport: transport,
            serviceName: serviceName,
            methodName: methodName,
            requestSerializer:
                _createDynamicSerializer(method.serializationFormat),
            responseSerializer:
                _createDynamicSerializer(method.serializationFormat),
            logger: logger,
          );

          // Подключаем обработчик к потоку запросов
          final handler = method.handler as void Function(
              Stream<dynamic>, void Function(dynamic));

          // Настраиваем обработку запросов и отправку ответов
          handler(responder.requests, responder.send);
          break;
      }

      logger.info(
          'Успешно создан обработчик для метода $serviceName.$methodName [streamId: $streamId]');
    } catch (e, stackTrace) {
      logger.error(
        'Ошибка при создании обработчика для метода $serviceName.$methodName: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Создает сериализатор для указанного формата, поддерживающий динамические типы
  IRpcSerializer<dynamic> _createDynamicSerializer(
      RpcSerializationFormat format) {
    switch (format) {
      case RpcSerializationFormat.json:
        // Простой сериализатор для тестирования
        return SimpleDynamicSerializer();
      case RpcSerializationFormat.binary:
        // Простой бинарный сериализатор для тестирования
        return SimpleDynamicSerializer();
    }
  }
}

/// Простой сериализатор для динамических типов (для тестирования)
class SimpleDynamicSerializer implements IRpcSerializer<dynamic> {
  @override
  Uint8List serialize(dynamic message) {
    if (message is IRpcSerializable) {
      return message.serialize();
    }
    // Для простоты превращаем в JSON и затем в байты
    final jsonStr = jsonEncode(message is Map ? message : {'value': message});
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  @override
  dynamic deserialize(Uint8List bytes) {
    // Для простоты считаем, что всё в JSON
    final jsonStr = utf8.decode(bytes);
    return jsonDecode(jsonStr);
  }
}
