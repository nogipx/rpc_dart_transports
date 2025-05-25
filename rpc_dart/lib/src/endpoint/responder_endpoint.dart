part of '_index.dart';

/// Серверный RPC эндпоинт для обработки запросов
final class RpcResponderEndpoint extends RpcEndpointBase {
  @override
  RpcLogger get logger =>
      RpcLogger('RpcResponderEndpoint[${debugLabel ?? ''}]');

  final Map<String, dynamic> _contracts = {};
  final Map<String, RpcMethodRegistration> _methods = {};

  RpcResponderEndpoint({
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
