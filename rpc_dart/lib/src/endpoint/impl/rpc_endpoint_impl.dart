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
class _RpcEndpointImpl
    implements
        _IRpcEndpointCore<IRpcSerializableMessage>,
        IRpcEndpoint<IRpcSerializableMessage> {
  /// Делегат для базовой функциональности
  final _RpcEndpointCoreImpl<IRpcSerializableMessage> _delegate;

  /// Зарегистрированные контракты сервисов
  final Map<String, IRpcServiceContract<IRpcSerializableMessage>> _contracts =
      {};

  /// Зарегистрированные реализации методов
  final Map<String, Map<String, RpcMethodImplementation>> _implementations = {};

  /// Логгер
  RpcLogger get _logger => RpcLogger('RpcEndpoint[${debugLabel ?? ''}]');

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
  Future<void> closeStream({
    required String streamId,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _delegate.closeStream(
        streamId: streamId,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  @override
  Future<dynamic> invoke({
    required String serviceName,
    required String methodName,
    required dynamic request,
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) =>
      _delegate.invoke(
        serviceName: serviceName,
        methodName: methodName,
        request: request,
        timeout: timeout,
        metadata: metadata,
      );

  @override
  bool get isActive => _delegate.isActive;

  @override
  Stream<dynamic> openStream({
    required String serviceName,
    required String methodName,
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) =>
      _delegate.openStream(
        serviceName: serviceName,
        methodName: methodName,
        request: request,
        metadata: metadata,
        streamId: streamId,
      );

  @override
  void registerMethod({
    required String serviceName,
    required String methodName,
    required Future<dynamic> Function(RpcMethodContext context) handler,
  }) =>
      _delegate.registerMethod(
        serviceName: serviceName,
        methodName: methodName,
        handler: handler,
      );

  void registerMethodImplementation({
    required String serviceName,
    required String methodName,
    required RpcMethodImplementation implementation,
  }) {
    _implementations
        .putIfAbsent(serviceName, () => {})
        .putIfAbsent(methodName, () => implementation);
  }

  @override
  Future<void> sendStreamData({
    required String streamId,
    required dynamic data,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _delegate.sendStreamData(
        streamId: streamId,
        data: data,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  @override
  Future<void> sendStreamError({
    required String streamId,
    required String errorMessage,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _delegate.sendStreamError(
        streamId: streamId,
        errorMessage: errorMessage,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  /// Регистрирует контракт сервиса
  void registerServiceContract(
    IRpcServiceContract<IRpcSerializableMessage> contract,
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
    IRpcServiceContract<IRpcSerializableMessage> contract,
  ) {
    _contracts[contract.serviceName] = contract;
    _implementations.putIfAbsent(contract.serviceName, () => {});

    // Регистрируем методы из класса
    contract.setup();

    // Регистрируем все подконтракты, если они есть
    if (contract is RpcServiceContract) {
      for (final subContract in contract.getSubContracts()) {
        if (!_contracts.containsKey(subContract.serviceName)) {
          // Рекурсивно регистрируем подконтракт (только если он еще не зарегистрирован)
          _registerContract(subContract);
        }
      }
    }

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
          unaryRequest(
            serviceName: contract.serviceName,
            methodName: methodName,
          ).register(
            handler: handler,
            requestParser: argumentParser,
            responseParser: responseParser,
          );
        } else if (methodType == RpcMethodType.serverStreaming) {
          serverStreaming(
            serviceName: contract.serviceName,
            methodName: methodName,
          ).register(
            handler: handler,
            requestParser: argumentParser,
            responseParser: responseParser,
          );
        } else if (methodType == RpcMethodType.clientStreaming) {
          clientStreaming(
            serviceName: contract.serviceName,
            methodName: methodName,
          ).register(
            handler: handler,
            requestParser: argumentParser,
          );
        } else if (methodType == RpcMethodType.bidirectional) {
          bidirectionalStreaming(
            serviceName: contract.serviceName,
            methodName: methodName,
          ).register(
            handler: handler,
            requestParser: argumentParser,
            responseParser: responseParser,
          );
        }
      } catch (error, trace) {
        _logger.error(
          'Ошибка при регистрации метода $methodName: $error',
          error: error,
          stackTrace: trace,
        );
        continue;
      }
    }
  }

  /// Получает контракт сервиса по имени
  @override
  IRpcServiceContract<IRpcSerializableMessage>? getServiceContract(
    String serviceName,
  ) {
    return _contracts[serviceName];
  }

  /// Создает объект унарного метода для указанного сервиса и метода
  @override
  UnaryRequestRpcMethod<IRpcSerializableMessage> unaryRequest({
    required String serviceName,
    required String methodName,
  }) =>
      UnaryRequestRpcMethod<IRpcSerializableMessage>(
          this, serviceName, methodName);

  /// Создает объект серверного стриминг метода для указанного сервиса и метода
  @override
  ServerStreamingRpcMethod<IRpcSerializableMessage> serverStreaming({
    required String serviceName,
    required String methodName,
  }) =>
      ServerStreamingRpcMethod<IRpcSerializableMessage>(
          this, serviceName, methodName);

  /// Создает объект клиентского стриминг метода для указанного сервиса и метода
  @override
  ClientStreamingRpcMethod<IRpcSerializableMessage> clientStreaming({
    required String serviceName,
    required String methodName,
  }) =>
      ClientStreamingRpcMethod<IRpcSerializableMessage>(
          this, serviceName, methodName);

  /// Создает объект двунаправленного стриминг метода для указанного сервиса и метода
  @override
  BidirectionalStreamingRpcMethod<IRpcSerializableMessage>
      bidirectionalStreaming({
    required String serviceName,
    required String methodName,
  }) =>
          BidirectionalStreamingRpcMethod<IRpcSerializableMessage>(
              this, serviceName, methodName);
}
