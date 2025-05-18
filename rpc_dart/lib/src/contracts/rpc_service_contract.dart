// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

// ignore: depend_on_referenced_packages
import 'package:meta/meta.dart';

/// Контракт, объединяющий несколько других контрактов
/// для модульной организации сервисов
abstract class RpcServiceContract
    implements IRpcServiceContract<IRpcSerializableMessage> {
  @override
  final String serviceName;

  final List<IRpcServiceContract<IRpcSerializableMessage>> _subContracts = [];

  /// Реестр методов
  final IRpcMethodRegistry _methodRegistry;

  /// Создает новый сервисный контракт с указанным именем
  /// Если [methodRegistry] не указан, создается новый экземпляр [RpcMethodRegistry]
  RpcServiceContract(
    this.serviceName, {
    IRpcMethodRegistry? methodRegistry,
  }) : _methodRegistry = methodRegistry ?? RpcMethodRegistry();

  /// Объединяет реестр методов этого контракта с реестром другого контракта или эндпоинта
  ///
  /// Переносит все методы и контракты из текущего реестра в целевой
  /// Возвращает целевой реестр для удобства цепочки вызовов
  IRpcMethodRegistry mergeInto(IRpcMethodRegistry targetRegistry) {
    // Вызываем setup для инициализации всех методов
    setup();

    // Собираем все методы из нашего реестра
    final serviceMethods = _methodRegistry.getMethodsForService(serviceName);

    // Регистрируем каждый метод отдельно, чтобы избежать двойной регистрации контракта
    for (final method in serviceMethods) {
      final existingMethod =
          targetRegistry.findMethod(serviceName, method.methodName);
      if (existingMethod == null) {
        targetRegistry.registerMethod(
          serviceName: method.serviceName,
          methodName: method.methodName,
          methodType: method.methodType,
          handler: method.getHandler(),
          argumentParser: method.argumentParser,
          responseParser: method.responseParser,
        );
      }
    }

    // Обрабатываем все подконтракты
    for (final subContract in _subContracts) {
      if (subContract is RpcServiceContract) {
        subContract.mergeInto(targetRegistry);
      } else {
        // Для обратной совместимости с обычными IRpcServiceContract
        targetRegistry.registerContract(subContract);
      }
    }

    return targetRegistry;
  }

  /// Добавляет подконтракт в композитный контракт
  void addSubContract(IRpcServiceContract<IRpcSerializableMessage> contract) {
    _subContracts.add(contract);

    // Если подконтракт - это RpcServiceContract, передаем ему наш реестр
    if (contract is RpcServiceContract) {
      contract.mergeInto(_methodRegistry);
    }
  }

  /// Возвращает список всех подконтрактов (непосредственных дочерних)
  List<IRpcServiceContract<IRpcSerializableMessage>> getSubContracts() {
    return List.unmodifiable(_subContracts);
  }

  /// Инициализирует все подконтракты
  /// Должен быть вызван строго после добавления всех подконтрактов
  @override
  @mustCallSuper
  void setup() {
    for (final contract in _subContracts) {
      contract.setup();
    }
  }

  @override
  List<RpcMethodContract<IRpcSerializableMessage, IRpcSerializableMessage>>
      get methods {
    final allMethods =
        <RpcMethodContract<IRpcSerializableMessage, IRpcSerializableMessage>>[];

    // Получаем методы из реестра
    final registeredMethods = _methodRegistry.getMethodsForService(serviceName);

    for (final method in registeredMethods) {
      final methodType = method.methodType;
      final contract =
          RpcMethodContract<IRpcSerializableMessage, IRpcSerializableMessage>(
        serviceName: method.serviceName,
        methodName: method.methodName,
        methodType: methodType,
      );
      allMethods.add(contract);
    }

    // Добавляем методы из подконтрактов
    for (final contract in _subContracts) {
      allMethods.addAll(contract.methods);
    }

    return allMethods;
  }

  @override
  RpcMethodContract<Request, Response>? findMethod<
      Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>(
    String methodName,
  ) {
    // Ищем метод в реестре
    final registered = _methodRegistry.findMethod(serviceName, methodName);
    if (registered != null) {
      final methodType = registered.methodType;
      return RpcMethodContract<Request, Response>(
        serviceName: registered.serviceName,
        methodName: registered.methodName,
        methodType: methodType,
      );
    }

    // Ищем в подконтрактах
    for (final contract in _subContracts) {
      final method = contract.findMethod<Request, Response>(methodName);
      if (method != null) {
        return method;
      }
    }
    return null;
  }

  @override
  dynamic getMethodHandler<Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>(
    String methodName,
  ) {
    // Получаем обработчик из реестра
    final registered = _methodRegistry.findMethod(serviceName, methodName);
    if (registered != null && registered.getHandler() != null) {
      return registered.getHandler();
    }

    // Ищем в подконтрактах
    for (final contract in _subContracts) {
      final handler = contract.getMethodHandler<Request, Response>(methodName);
      if (handler != null) {
        return handler;
      }
    }
    return null;
  }

  @override
  RpcMethodArgumentParser<Request>?
      getMethodArgumentParser<Request extends IRpcSerializableMessage>(
    String methodName,
  ) {
    // Получаем парсер аргументов из реестра
    final registered = _methodRegistry.findMethod(serviceName, methodName);
    if (registered != null && registered.argumentParser != null) {
      return registered.argumentParser as RpcMethodArgumentParser<Request>?;
    }

    // Ищем в подконтрактах
    for (final contract in _subContracts) {
      final parser = contract.getMethodArgumentParser<Request>(methodName);
      if (parser != null) {
        return parser;
      }
    }
    return null;
  }

  @override
  RpcMethodResponseParser<Response>?
      getMethodResponseParser<Response extends IRpcSerializableMessage>(
    String methodName,
  ) {
    // Получаем парсер ответов из реестра
    final registered = _methodRegistry.findMethod(serviceName, methodName);
    if (registered != null && registered.responseParser != null) {
      return registered.responseParser as RpcMethodResponseParser<Response>?;
    }

    // Ищем в подконтрактах
    for (final contract in _subContracts) {
      final parser = contract.getMethodResponseParser<Response>(methodName);
      if (parser != null) {
        return parser;
      }
    }
    return null;
  }

  @override
  void addUnaryRequestMethod<Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>({
    required String methodName,
    required RpcMethodUnaryHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    final handlerAdapter = RpcMethodAdapterFactory.createUnaryHandlerAdapter(
      handler,
      argumentParser,
      'RpcServiceContract.addUnaryRequestMethod',
    );

    _methodRegistry.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: RpcMethodType.unary,
      handler: handlerAdapter,
      argumentParser: argumentParser,
      responseParser: responseParser,
    );
  }

  @override
  void addServerStreamingMethod<Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>({
    required String methodName,
    required RpcMethodServerStreamHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    // Передаем обработчик напрямую без создания адаптера
    _methodRegistry.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: RpcMethodType.serverStreaming,
      handler: handler,
      argumentParser: argumentParser,
      responseParser: responseParser,
    );
  }

  @override
  void addClientStreamingMethod<Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>({
    required String methodName,
    required RpcMethodClientStreamHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    // Передаем обработчик напрямую без создания адаптера
    _methodRegistry.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: RpcMethodType.clientStreaming,
      handler: handler,
      argumentParser: argumentParser,
      responseParser: responseParser,
    );
  }

  @override
  void addBidirectionalStreamingMethod<Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>({
    required String methodName,
    required RpcMethodBidirectionalHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    // Передаем обработчик напрямую без создания адаптера
    _methodRegistry.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: RpcMethodType.bidirectional,
      handler: handler,
      argumentParser: argumentParser,
      responseParser: responseParser,
    );
  }
}
