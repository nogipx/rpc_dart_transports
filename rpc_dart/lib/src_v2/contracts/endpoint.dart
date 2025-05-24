part of '_index.dart';

/// Базовый класс для всех RPC эндпоинтов
abstract base class RpcEndpointBase {
  final IRpcTransport _transport;
  final List<IRpcMiddleware> _middlewares = [];
  final String? debugLabel;
  RpcLogger get logger;
  bool _isActive = true;

  RpcEndpointBase({
    required IRpcTransport transport,
    this.debugLabel,
  }) : _transport = transport;

  void addMiddleware(IRpcMiddleware middleware) {
    _middlewares.add(middleware);
    logger.info('Добавлен middleware: ${middleware.runtimeType}');
  }

  bool get isActive => _isActive;

  IRpcTransport get transport => _transport;

  Future<void> close() async {
    if (!_isActive) return;

    logger.info('Закрытие RpcEndpoint');
    _isActive = false;
    _middlewares.clear();

    try {
      await _transport.close();
    } catch (e) {
      logger.warning('Ошибка при закрытии транспорта: $e');
    }

    logger.info('RpcEndpoint закрыт');
  }
}

/// Клиентский RPC эндпоинт для отправки запросов
final class RpcClientEndpoint extends RpcEndpointBase {
  @override
  RpcLogger get logger =>
      RpcLogger('RpcClientEndpoint[${debugLabel ?? 'default'}]');

  RpcClientEndpoint({
    required super.transport,
    super.debugLabel,
  });

  /// Создает унарный request builder
  RpcUnaryRequestBuilder unaryRequest({
    required String serviceName,
    required String methodName,
    RpcSerializationFormat? preferredFormat,
  }) {
    return RpcUnaryRequestBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
      preferredFormat: preferredFormat,
    );
  }

  /// Создает server stream builder
  RpcServerStreamBuilder serverStream({
    required String serviceName,
    required String methodName,
    RpcSerializationFormat? preferredFormat,
  }) {
    return RpcServerStreamBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
      preferredFormat: preferredFormat,
    );
  }

  /// Создает client stream builder
  RpcClientStreamBuilder clientStream({
    required String serviceName,
    required String methodName,
    RpcSerializationFormat? preferredFormat,
  }) {
    return RpcClientStreamBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
      preferredFormat: preferredFormat,
    );
  }

  /// Создает bidirectional stream builder
  RpcBidirectionalStreamBuilder bidirectionalStream({
    required String serviceName,
    required String methodName,
    RpcSerializationFormat? preferredFormat,
  }) {
    return RpcBidirectionalStreamBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
      preferredFormat: preferredFormat,
    );
  }
}

/// Серверный RPC эндпоинт для обработки запросов
final class RpcServerEndpoint extends RpcEndpointBase {
  @override
  RpcLogger get logger =>
      RpcLogger('RpcServerEndpoint[${debugLabel ?? 'default'}]');

  final Map<String, dynamic> _contracts = {};
  final Map<String, RpcMethodRegistration> _methods = {};

  RpcServerEndpoint({
    required super.transport,
    super.debugLabel,
  });

  /// Регистрирует контракт сервиса
  void registerServiceContract(RpcServerContract contract) {
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

  @override
  Future<void> close() async {
    if (!isActive) return;
    _contracts.clear();
    _methods.clear();
    await super.close();
  }
}
