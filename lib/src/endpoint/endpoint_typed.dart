part of '_index.dart';

/// Типизированный Endpoint с поддержкой контрактов
class RpcEndpoint<T extends RpcSerializableMessage> implements _RpcEndpoint {
  /// Делегат для базовой функциональности
  final _RpcEndpointBase _delegate;

  /// Зарегистрированные контракты сервисов
  final Map<String, IRpcServiceContract<T>> _contracts = {};

  /// Зарегистрированные реализации методов
  final Map<String, Map<String, RpcMethodImplementation>> _implementations = {};

  /// Создает новый типизированный Endpoint
  RpcEndpoint(RpcTransport transport, RpcSerializer serializer)
      : _delegate = _RpcEndpointBase(transport, serializer);

  @override
  RpcTransport get transport => _delegate.transport;

  @override
  RpcSerializer get serializer => _delegate.serializer;

  @override
  void addMiddleware(RpcMiddleware middleware) =>
      _delegate.addMiddleware(middleware);

  @override
  Future<void> close() => _delegate.close();

  @override
  Future<void> closeStream(
    String streamId, {
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _delegate.closeStream(
        streamId,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  @override
  Future<dynamic> invoke(
    String serviceName,
    String methodName,
    dynamic request, {
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) =>
      _delegate.invoke(
        serviceName,
        methodName,
        request,
        timeout: timeout,
        metadata: metadata,
      );

  @override
  bool get isActive => _delegate.isActive;

  @override
  Stream<dynamic> openStream(
    String serviceName,
    String methodName, {
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) =>
      _delegate.openStream(
        serviceName,
        methodName,
        request: request,
        metadata: metadata,
        streamId: streamId,
      );

  @override
  void registerMethod(
    String serviceName,
    String methodName,
    Future<dynamic> Function(RpcMethodContext context) handler,
  ) =>
      _delegate.registerMethod(serviceName, methodName, handler);

  @override
  Future<void> sendStreamData(
    String streamId,
    dynamic data, {
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _delegate.sendStreamData(
        streamId,
        data,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  @override
  Future<void> sendStreamError(
    String streamId,
    String errorMessage, {
    Map<String, dynamic>? metadata,
  }) =>
      _delegate.sendStreamError(
        streamId,
        errorMessage,
        metadata: metadata,
      );

  /// Регистрирует контракт сервиса
  void registerServiceContract(IRpcServiceContract<T> contract) {
    // Сохраняем контракт
    _contracts[contract.serviceName] = contract;
    _implementations.putIfAbsent(contract.serviceName, () => {});

    // Проверяем, является ли контракт декларативным
    if (contract is RpcServiceContract<T>) {
      _registerDeclarativeContract(contract);
    }
  }

  /// Регистрирует методы из декларативного контракта
  void _registerDeclarativeContract(RpcServiceContract<T> contract) {
    // Регистрируем методы из класса
    contract.registerMethodsFromClass();

    // Для каждого метода в контракте
    for (final method in contract.methods) {
      final methodType = method.methodType;
      final methodName = method.methodName;
      final handler = contract.getHandler(method);
      final argumentParser = contract.getArgumentParser(method);
      final responseParser = contract.getResponseParser(method);

      if (methodType == RpcMethodType.unary) {
        // Унарный метод
        unary(contract.serviceName, methodName).register(
          handler: handler,
          requestParser: argumentParser,
          responseParser: responseParser,
        );
      } else if (methodType == RpcMethodType.serverStreaming) {
        // Серверный стриминг
        serverStreaming(contract.serviceName, methodName).register(
          handler: handler,
          requestParser: argumentParser,
          responseParser: responseParser,
        );
      } else if (methodType == RpcMethodType.clientStreaming) {
        // Клиентский стриминг
        clientStreaming(contract.serviceName, methodName).register(
          handler: handler,
          requestParser: argumentParser,
          responseParser: responseParser,
        );
      } else if (methodType == RpcMethodType.bidirectional) {
        // Двунаправленный стриминг
        bidirectional(contract.serviceName, methodName).register(
          handler: handler,
          requestParser: argumentParser,
          responseParser: responseParser,
        );
      }
    }
  }

  /// Получает контракт сервиса по имени
  IRpcServiceContract<T>? getServiceContract(String serviceName) {
    return _contracts[serviceName];
  }

  /// Регистрирует реализацию метода (для внутреннего использования)
  void registerMethodImplementation(
    String serviceName,
    String methodName,
    RpcMethodImplementation implementation,
  ) {
    _implementations.putIfAbsent(serviceName, () => {});
    _implementations[serviceName]![methodName] = implementation;
  }

  /// Создает объект унарного метода для указанного сервиса и метода
  @override
  UnaryRpcMethod<T> unary(
    String serviceName,
    String methodName,
  ) =>
      UnaryRpcMethod<T>(this, serviceName, methodName);

  /// Создает объект серверного стриминг метода для указанного сервиса и метода
  @override
  ServerStreamingRpcMethod<T> serverStreaming(
    String serviceName,
    String methodName,
  ) =>
      ServerStreamingRpcMethod<T>(this, serviceName, methodName);

  /// Создает объект клиентского стриминг метода для указанного сервиса и метода
  @override
  ClientStreamingRpcMethod<T> clientStreaming(
    String serviceName,
    String methodName,
  ) =>
      ClientStreamingRpcMethod<T>(this, serviceName, methodName);

  /// Создает объект двунаправленного стриминг метода для указанного сервиса и метода
  @override
  BidirectionalRpcMethod<T> bidirectional(
    String serviceName,
    String methodName,
  ) =>
      BidirectionalRpcMethod<T>(this, serviceName, methodName);
}
