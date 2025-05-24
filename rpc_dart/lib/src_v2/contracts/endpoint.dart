part of '_index.dart';

/// Основной RPC endpoint для работы с типобезопасными моделями
final class RpcEndpoint {
  final IRpcTransport _transport;
  final Map<String, dynamic> _contracts = {};
  final Map<String, RpcMethodRegistration> _methods = {};
  final List<IRpcMiddleware> _middlewares = [];
  final String? debugLabel;
  late final RpcLogger logger;
  bool _isActive = true;

  RpcEndpoint({
    required IRpcTransport transport,
    this.debugLabel,
  }) : _transport = transport {
    logger = RpcLogger('RpcEndpoint[${debugLabel ?? 'default'}]');
    logger.info('RpcEndpoint создан');
  }

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

  void addMiddleware(IRpcMiddleware middleware) {
    _middlewares.add(middleware);
    logger.info('Добавлен middleware: ${middleware.runtimeType}');
  }

  /// Создает унарный request builder
  RpcUnaryRequestBuilder unaryRequest({
    required String serviceName,
    required String methodName,
    RpcSerializationFormat? preferredFormat,
  }) {
    final methodKey = '$serviceName.$methodName';
    final method = _methods[methodKey];

    _validateMethodExists(serviceName, methodName, RpcMethodType.unary);

    // Если формат не указан, используем формат из регистрации метода
    final format = preferredFormat ?? method?.serializationFormat;

    return RpcUnaryRequestBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
      preferredFormat: format,
    );
  }

  /// Создает server stream builder
  RpcServerStreamBuilder serverStream({
    required String serviceName,
    required String methodName,
    RpcSerializationFormat? preferredFormat,
  }) {
    final methodKey = '$serviceName.$methodName';
    final method = _methods[methodKey];

    _validateMethodExists(serviceName, methodName, RpcMethodType.serverStream);

    // Если формат не указан, используем формат из регистрации метода
    final format = preferredFormat ?? method?.serializationFormat;

    return RpcServerStreamBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
      preferredFormat: format,
    );
  }

  /// Создает client stream builder
  RpcClientStreamBuilder clientStream({
    required String serviceName,
    required String methodName,
    RpcSerializationFormat? preferredFormat,
  }) {
    final methodKey = '$serviceName.$methodName';
    final method = _methods[methodKey];

    _validateMethodExists(serviceName, methodName, RpcMethodType.clientStream);

    // Если формат не указан, используем формат из регистрации метода
    final format = preferredFormat ?? method?.serializationFormat;

    return RpcClientStreamBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
      preferredFormat: format,
    );
  }

  /// Создает bidirectional stream builder
  RpcBidirectionalStreamBuilder bidirectionalStream({
    required String serviceName,
    required String methodName,
    RpcSerializationFormat? preferredFormat,
  }) {
    final methodKey = '$serviceName.$methodName';
    final method = _methods[methodKey];

    _validateMethodExists(serviceName, methodName, RpcMethodType.bidirectional);

    // Если формат не указан, используем формат из регистрации метода
    final format = preferredFormat ?? method?.serializationFormat;

    return RpcBidirectionalStreamBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
      preferredFormat: format,
    );
  }

  void _validateMethodExists(
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

  bool get isActive => _isActive;

  IRpcTransport get transport => _transport;

  Future<void> close() async {
    if (!_isActive) return;

    logger.info('Закрытие RpcEndpoint');
    _isActive = false;
    _contracts.clear();
    _methods.clear();
    _middlewares.clear();

    try {
      await _transport.close();
    } catch (e) {
      logger.warning('Ошибка при закрытии транспорта: $e');
    }

    logger.info('RpcEndpoint закрыт');
  }
}
