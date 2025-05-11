// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

final _random = Random();
String _defaultUniqueIdGenerator([String? prefix]) {
  // Текущее время в миллисекундах + случайное число
  return '${prefix != null ? '${prefix}_' : ''}${DateTime.now().toUtc().toIso8601String()}_${_random.nextInt(1000000)}';
}

typedef RpcUniqueIdGenerator = String Function([String? prefix]);

/// Типизированный Endpoint с поддержкой контрактов
class _RpcEndpointImpl<T extends IRpcSerializableMessage>
    implements _IRpcEndpointCore<T>, IRpcEndpoint<T> {
  /// Делегат для базовой функциональности
  final _RpcEndpointCoreImpl<T> _delegate;

  /// Зарегистрированные контракты сервисов
  final Map<String, IRpcServiceContract<T>> _contracts = {};

  /// Зарегистрированные реализации методов
  final Map<String, Map<String, RpcMethodImplementation>> _implementations = {};

  /// Метка для отладки
  @override
  final String? debugLabel;

  /// Создает новый типизированный Endpoint
  _RpcEndpointImpl({
    required RpcTransport transport,
    required RpcSerializer serializer,
    this.debugLabel,
    RpcUniqueIdGenerator? uniqueIdGenerator,
  }) : _delegate = _RpcEndpointCoreImpl(
          transport,
          serializer,
          debugLabel: debugLabel,
          uniqueIdGenerator: uniqueIdGenerator,
        );

  @override
  RpcTransport get transport => _delegate.transport;

  @override
  RpcSerializer get serializer => _delegate.serializer;

  @override
  void addMiddleware(IRpcMiddleware middleware) =>
      _delegate.addMiddleware(middleware);

  @override
  String generateUniqueId([String? prefix]) =>
      _delegate.generateUniqueId(prefix);

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
  void registerServiceContract(
    IRpcServiceContract<T> contract,
  ) {
    // Проверяем, не зарегистрирован ли уже контракт с таким именем
    if (_contracts.containsKey(contract.serviceName)) {
      throw RpcInternalException(
        'Контракт для сервиса ${contract.serviceName} уже зарегистрирован',
      );
    }

    _registerContract(contract);
  }

  /// Регистрирует методы из декларативного контракта
  void _registerContract(
    IRpcServiceContract<T> contract,
  ) {
    _contracts[contract.serviceName] = contract;
    _implementations.putIfAbsent(contract.serviceName, () => {});

    // Регистрируем методы из класса
    contract.setup();

    // Для каждого метода в контракте
    for (final method in contract.methods) {
      final methodType = method.methodType;
      final methodName = method.methodName;
      final handler = contract.getMethodHandler(methodName);
      final argumentParser = contract.getMethodArgumentParser(methodName);
      final responseParser = contract.getMethodResponseParser(methodName);

      if (handler == null || argumentParser == null || responseParser == null) {
        // Пропускаем методы без полной информации
        continue;
      }

      try {
        // Типобезопасная регистрация каждого типа метода
        if (methodType == RpcMethodType.unary) {
          unary(contract.serviceName, methodName).register(
            handler: handler,
            requestParser: argumentParser,
            responseParser: responseParser,
          );
        } else if (methodType == RpcMethodType.serverStreaming) {
          serverStreaming(contract.serviceName, methodName).register(
            handler: handler,
            requestParser: argumentParser,
            responseParser: responseParser,
          );
        } else if (methodType == RpcMethodType.clientStreaming) {
          clientStreaming(contract.serviceName, methodName).register(
            handler: handler,
            requestParser: argumentParser,
            responseParser: responseParser,
          );
        } else if (methodType == RpcMethodType.bidirectional) {
          bidirectional(contract.serviceName, methodName).register(
            handler: handler,
            requestParser: argumentParser,
            responseParser: responseParser,
          );
        }
      } catch (e) {
        print('Ошибка при регистрации метода $methodName: $e');
        continue;
      }
    }
  }

  /// Получает контракт сервиса по имени
  @override
  IRpcServiceContract<T>? getServiceContract(
    String serviceName,
  ) {
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
