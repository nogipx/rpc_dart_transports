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

final class SimpleRpcServiceContract
    extends RpcServiceContract<IRpcSerializableMessage> {
  @override
  final String serviceName;

  SimpleRpcServiceContract(this.serviceName);

  @override
  void setup() {}
}

/// Базовый интерфейс для декларативных контрактов
abstract base class RpcServiceContract<T extends IRpcSerializableMessage>
    extends _RpcServiceContractBase<T> {}

/// Базовый класс для определения контрактов сервисов
abstract base class _RpcServiceContractBase<T extends IRpcSerializableMessage>
    implements IRpcServiceContract<T> {
  _RpcServiceContractBase();

  /// Кэш методов сервиса
  final List<RpcMethodContract<T, T>> _methods = [];

  /// Хранилище обработчиков для каждого метода
  final Map<String, dynamic> _handlers = {};

  /// Хранилище функций парсинга аргументов для каждого метода
  final Map<String, Function?> _argumentParsers = {};

  /// Хранилище функций парсинга ответов для каждого метода
  final Map<String, Function?> _responseParsers = {};

  /// Имя сервиса, должно быть уникальным
  @override
  String get serviceName;

  /// Методы сервиса, заполняются автоматически
  @override
  List<RpcMethodContract<T, T>> get methods => _methods;

  @override
  dynamic getHandler(
    RpcMethodContract<T, T> method,
  ) =>
      _handlers[method.methodName];

  @override
  dynamic getArgumentParser(
    RpcMethodContract<T, T> method,
  ) =>
      _argumentParsers[method.methodName];

  @override
  dynamic getResponseParser(
    RpcMethodContract<T, T> method,
  ) =>
      _responseParsers[method.methodName];

  /// Находит метод по имени
  @override
  RpcMethodContract<Request, Response>?
      findMethodTyped<Request extends T, Response extends T>(
          String methodName) {
    for (final method in methods) {
      if (method.methodName == methodName &&
          method is RpcMethodContract<Request, Response>) {
        return method;
      }
    }
    return null;
  }

  /// Добавляет унарный метод в контракт
  @override
  void addUnaryMethod<Request extends T, Response extends T>({
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

  /// Добавляет серверный стриминговый метод в контракт
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

  /// Добавляет клиентский стриминговый метод в контракт
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

  /// Добавляет двунаправленный стриминговый метод в контракт
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
