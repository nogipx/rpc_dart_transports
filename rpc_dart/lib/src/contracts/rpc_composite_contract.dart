// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import '_index.dart'
    show
        RpcMethodContract,
        RpcMethodType,
        IRpcServiceContract,
        IRpcSerializableMessage;
import 'typedefs.dart';

/// Контракт, объединяющий несколько других контрактов
/// для модульной организации сервисов
final class RpcCompositeContract<T extends IRpcSerializableMessage>
    implements IRpcServiceContract<T> {
  @override
  final String serviceName;

  final List<IRpcServiceContract<T>> _subContracts = [];

  /// Кэш методов сервиса
  final List<RpcMethodContract<T, T>> _methods = [];

  /// Хранилище обработчиков для каждого метода
  final Map<String, dynamic> _handlers = {};

  /// Хранилище функций парсинга аргументов для каждого метода
  final Map<String, Function?> _argumentParsers = {};

  /// Хранилище функций парсинга ответов для каждого метода
  final Map<String, Function?> _responseParsers = {};

  RpcCompositeContract(this.serviceName);

  /// Добавляет подконтракт в композитный контракт
  void addSubContract(IRpcServiceContract<T> contract) {
    _subContracts.add(contract);
  }

  /// Инициализирует все подконтракты
  @override
  void setup() {
    for (final contract in _subContracts) {
      contract.setup();
    }
  }

  @override
  List<RpcMethodContract<T, T>> get methods {
    final allMethods = <RpcMethodContract<T, T>>[..._methods];
    for (final contract in _subContracts) {
      allMethods.addAll(contract.methods);
    }
    return allMethods;
  }

  @override
  RpcMethodContract<Request, Response>?
      findMethod<Request extends T, Response extends T>(
    String methodName,
  ) {
    // Сначала ищем в локальных методах
    for (final method in _methods) {
      if (method.methodName == methodName) {
        return method as RpcMethodContract<Request, Response>;
      }
    }

    // Затем в подконтрактах
    for (final contract in _subContracts) {
      final method = contract.findMethod<Request, Response>(methodName);
      if (method != null) {
        return method;
      }
    }
    return null;
  }

  @override
  dynamic getMethodHandler<Request extends T, Response extends T>(
    String methodName,
  ) {
    // Проверяем локальные обработчики
    final method = findMethod<Request, Response>(methodName);
    if (method != null && _handlers.containsKey(methodName)) {
      return _handlers[methodName];
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
  RpcMethodArgumentParser<Request>? getMethodArgumentParser<Request extends T>(
    String methodName,
  ) {
    // Проверяем локальные парсеры
    final method = findMethod<Request, T>(methodName);
    if (method != null && _argumentParsers.containsKey(methodName)) {
      final parser = _argumentParsers[methodName];
      return parser as RpcMethodArgumentParser<Request>?;
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
      getMethodResponseParser<Response extends T>(
    String methodName,
  ) {
    // Проверяем локальные парсеры
    final method = findMethod<T, Response>(methodName);
    if (method != null && _responseParsers.containsKey(methodName)) {
      final parser = _responseParsers[methodName];
      return parser as RpcMethodResponseParser<Response>?;
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
  void addUnaryRequestMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodUnaryHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    _methods.add(
      RpcMethodContract<Request, Response>(
        methodName: methodName,
        methodType: RpcMethodType.unary,
      ),
    );

    _handlers[methodName] = handler;
    _argumentParsers[methodName] = argumentParser;
    _responseParsers[methodName] = responseParser;
  }

  @override
  void addServerStreamingMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodServerStreamHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    _methods.add(
      RpcMethodContract<Request, Response>(
        methodName: methodName,
        methodType: RpcMethodType.serverStreaming,
      ),
    );

    _handlers[methodName] = handler;
    _argumentParsers[methodName] = argumentParser;
    _responseParsers[methodName] = responseParser;
  }

  @override
  void addClientStreamingMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodClientStreamHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    _methods.add(
      RpcMethodContract<Request, Response>(
        methodName: methodName,
        methodType: RpcMethodType.clientStreaming,
      ),
    );

    _handlers[methodName] = handler;
    _argumentParsers[methodName] = argumentParser;
    _responseParsers[methodName] = responseParser;
  }

  @override
  void addBidirectionalStreamingMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodBidirectionalHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    _methods.add(
      RpcMethodContract<Request, Response>(
        methodName: methodName,
        methodType: RpcMethodType.bidirectional,
      ),
    );

    _handlers[methodName] = handler;
    _argumentParsers[methodName] = argumentParser;
    _responseParsers[methodName] = responseParser;
  }
}
