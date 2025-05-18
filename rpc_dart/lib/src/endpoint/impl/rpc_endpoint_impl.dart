// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Типизированный Endpoint с поддержкой контрактов
final class _RpcEndpointImpl
    implements IRpcEngine, IRpcEndpoint, IRpcMethodRegistry {
  /// Делегат для базовой функциональности
  final IRpcEngine _engine;

  final IRpcMethodRegistry _registry;

  /// Логгер
  RpcLogger get _logger => RpcLogger('RpcEndpoint[${debugLabel ?? ''}]');

  /// Метка для отладки
  @override
  final String? debugLabel;

  /// Создает новый типизированный Endpoint
  _RpcEndpointImpl({
    required IRpcTransport transport,
    required IRpcSerializer serializer,
    required IRpcMethodRegistry methodRegistry,
    this.debugLabel,
    RpcUniqueIdGenerator? uniqueIdGenerator,
  })  : _engine = _RpcEngineImpl(
          transport: transport,
          serializer: serializer,
          registry: methodRegistry,
          debugLabel: debugLabel,
          uniqueIdGenerator: uniqueIdGenerator,
        ),
        _registry = methodRegistry;

  @override
  IRpcTransport get transport => _engine.transport;

  @override
  IRpcSerializer get serializer => _engine.serializer;

  @override
  IRpcMethodRegistry get registry => _registry;

  @override
  void addMiddleware(IRpcMiddleware middleware) =>
      _engine.addMiddleware(middleware);

  @override
  String generateUniqueId([String? prefix]) => _engine.generateUniqueId(prefix);

  @override
  Future<void> close() => _engine.close();

  @override
  Future<void> closeStream({
    required String streamId,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _engine.closeStream(
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
      _engine.invoke(
        serviceName: serviceName,
        methodName: methodName,
        request: request,
        timeout: timeout,
        metadata: metadata,
      );

  @override
  bool get isActive => _engine.isActive;

  @override
  Stream<dynamic> openStream({
    required String serviceName,
    required String methodName,
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) =>
      _engine.openStream(
        serviceName: serviceName,
        methodName: methodName,
        request: request,
        metadata: metadata,
        streamId: streamId,
      );

  @override
  Future<void> sendStreamData({
    required String streamId,
    required dynamic data,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _engine.sendStreamData(
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
      _engine.sendStreamError(
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
    if (_registry.getServiceContract(contract.serviceName) != null) {
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
    _registry.registerContract(contract);

    // Если это RpcServiceContract, используем объединение реестров
    if (contract is RpcServiceContract) {
      // Объединяем реестр контракта с реестром эндпоинта
      contract.mergeInto(_registry);
    } else {
      // Для старых типов контрактов используем прежнюю логику
      contract.setup();

      // Регистрируем все подконтракты, если они есть
      if (contract is RpcServiceContract) {
        for (final subContract in contract.getSubContracts()) {
          if (_registry.getServiceContract(subContract.serviceName) == null) {
            // Рекурсивно регистрируем подконтракт (только если он еще не зарегистрирован)
            _registerContract(subContract);
          }
        }
      }
    }

    // Проверяем методы в реестре эндпоинта для этого сервиса
    final registeredMethods =
        _registry.getMethodsForService(contract.serviceName);

    // Для каждого метода создаем реализацию
    for (final method in registeredMethods) {
      final methodType = method.methodType;
      final methodName = method.methodName;
      final handler = method.getHandler();
      final argumentParser = method.argumentParser;
      final responseParser = method.responseParser;

      if (handler == null || argumentParser == null) {
        _logger.debug(
            'Пропускаем метод ${contract.serviceName}.$methodName из-за отсутствия обязательных компонентов');
        continue;
      }

      try {
        // Типобезопасная регистрация каждого типа метода
        if (methodType == RpcMethodType.unary) {
          if (responseParser == null) {
            _logger.debug(
                'Пропускаем унарный метод ${contract.serviceName}.$methodName из-за отсутствия responseParser');
            continue;
          }

          _logger.debug(
              'Регистрация унарного метода ${contract.serviceName}.$methodName:');
          _logger.debug('  - Handler type: ${handler.runtimeType}');
          _logger.debug('  - ArgParser type: ${argumentParser.runtimeType}');
          _logger.debug('  - RespParser type: ${responseParser.runtimeType}');

          unaryRequest(
            serviceName: contract.serviceName,
            methodName: methodName,
          ).register(
            handler: handler,
            requestParser: argumentParser
                as RpcMethodArgumentParser<IRpcSerializableMessage>,
            responseParser: responseParser
                as RpcMethodResponseParser<IRpcSerializableMessage>,
          );
        } else if (methodType == RpcMethodType.serverStreaming) {
          if (responseParser == null) {
            _logger.debug(
                'Пропускаем серверный стриминг метод ${contract.serviceName}.$methodName из-за отсутствия responseParser');
            continue;
          }

          serverStreaming(
            serviceName: contract.serviceName,
            methodName: methodName,
          ).register(
            handler: handler,
            requestParser: argumentParser
                as RpcMethodArgumentParser<IRpcSerializableMessage>,
            responseParser: responseParser
                as RpcMethodResponseParser<IRpcSerializableMessage>,
          );
        } else if (methodType == RpcMethodType.clientStreaming) {
          clientStreaming(
            serviceName: contract.serviceName,
            methodName: methodName,
          ).register(
            handler: handler,
            requestParser: argumentParser
                as RpcMethodArgumentParser<IRpcSerializableMessage>,
          );
        } else if (methodType == RpcMethodType.bidirectional) {
          if (responseParser == null) {
            _logger.debug(
                'Пропускаем двунаправленный стриминг метод ${contract.serviceName}.$methodName из-за отсутствия responseParser');
            continue;
          }

          bidirectionalStreaming(
            serviceName: contract.serviceName,
            methodName: methodName,
          ).register(
            handler: handler,
            requestParser: argumentParser
                as RpcMethodArgumentParser<IRpcSerializableMessage>,
            responseParser: responseParser
                as RpcMethodResponseParser<IRpcSerializableMessage>,
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
    return _registry.getServiceContract(serviceName);
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

  @override
  void clearMethodsRegistry() {
    _registry.clearMethodsRegistry();
  }

  @override
  MethodRegistration? findMethod(String serviceName, String methodName) {
    return _registry.findMethod(serviceName, methodName);
  }

  @override
  Map<String, IRpcServiceContract<IRpcSerializableMessage>> getAllContracts() {
    return _registry.getAllContracts();
  }

  @override
  Iterable<MethodRegistration> getAllMethods() {
    return _registry.getAllMethods();
  }

  @override
  Iterable<MethodRegistration> getMethodsForService(String serviceName) {
    return _registry.getMethodsForService(serviceName);
  }

  @override
  void registerContract(IRpcServiceContract<IRpcSerializableMessage> contract) {
    _registry.registerContract(contract);
  }

  @override
  void registerMethod({
    required String serviceName,
    required String methodName,
    required handler,
    RpcMethodType? methodType,
    Function? argumentParser,
    Function? responseParser,
  }) {
    // Регистрируем метод в реестре методов
    _registry.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: methodType,
      handler: handler,
      argumentParser: argumentParser,
      responseParser: responseParser,
    );
  }

  @override
  Future<void> sendClientStreamEnd({
    required String streamId,
    String? serviceName,
    String? methodName,
    Map<String, dynamic>? metadata,
  }) =>
      _engine.sendClientStreamEnd(
        streamId: streamId,
        serviceName: serviceName,
        methodName: methodName,
        metadata: metadata,
      );

  @override
  Future<void> cancelOperation({
    required String operationId,
    String? reason,
    Map<String, dynamic>? details,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _engine.cancelOperation(
        operationId: operationId,
        reason: reason,
        details: details,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  @override
  Future<Duration> sendPing({Duration? timeout}) =>
      _engine.sendPing(timeout: timeout);

  @override
  Future<void> sendServiceMarker({
    required String streamId,
    required RpcServiceMarker marker,
    String? serviceName,
    String? methodName,
    Map<String, dynamic>? metadata,
  }) =>
      _engine.sendServiceMarker(
        streamId: streamId,
        marker: marker,
        serviceName: serviceName,
        methodName: methodName,
        metadata: metadata,
      );

  @override
  Future<void> sendStatus({
    required String requestId,
    required RpcStatusCode statusCode,
    required String message,
    Map<String, dynamic>? details,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _engine.sendStatus(
        requestId: requestId,
        statusCode: statusCode,
        message: message,
        details: details,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  @override
  Future<void> setDeadline({
    required String requestId,
    required Duration timeout,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) =>
      _engine.setDeadline(
        requestId: requestId,
        timeout: timeout,
        metadata: metadata,
        serviceName: serviceName,
        methodName: methodName,
      );

  @override
  void registerDirectMethod<Req extends IRpcSerializableMessage,
      Resp extends IRpcSerializableMessage>({
    required String serviceName,
    required String methodName,
    required RpcMethodType methodType,
    required handler,
    required Req Function(dynamic p) argumentParser,
    Resp Function(dynamic p)? responseParser,
    RpcMethodContract<Req, Resp>? methodContract,
  }) {
    _registry.registerDirectMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: methodType,
      handler: handler,
      argumentParser: argumentParser,
      responseParser: responseParser,
      methodContract: methodContract,
    );
  }
}
