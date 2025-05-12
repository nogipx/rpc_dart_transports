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

  /// Находит метод по имени
  @override
  RpcMethodContract<Request, Response>?
      findMethod<Request extends T, Response extends T>(
    String methodName,
  ) {
    for (final method in methods) {
      if (method.methodName == methodName) {
        return method as RpcMethodContract<Request, Response>;
      }
    }
    return null;
  }

  /// Получает обработчик метода с типами Request и Response
  @override
  dynamic getMethodHandler<Request extends T, Response extends T>(
    String methodName,
  ) {
    final method = findMethod<Request, Response>(methodName);
    if (method == null) return null;

    return _handlers[methodName];
  }

  /// Получает функцию парсинга аргументов для метода
  @override
  RpcMethodArgumentParser<Request>? getMethodArgumentParser<Request extends T>(
    String methodName,
  ) {
    final method = findMethod<Request, T>(methodName);
    if (method == null) return null;

    final parser = _argumentParsers[methodName];
    return parser as RpcMethodArgumentParser<Request>?;
  }

  /// Получает функцию парсинга ответов для метода
  @override
  RpcMethodResponseParser<Response>?
      getMethodResponseParser<Response extends T>(
    String methodName,
  ) {
    final method = findMethod<T, Response>(methodName);
    if (method == null) return null;

    final parser = _responseParsers[methodName];
    return parser as RpcMethodResponseParser<Response>?;
  }

  /// Добавляет унарный метод в контракт
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

  /// Добавляет серверный стриминговый метод в контракт
  ///
  /// [methodName] - название метода
  /// [handler] - обработчик, возвращающий [ServerStreamingBidiStream]
  /// [argumentParser] - функция преобразования JSON в объект запроса
  /// [responseParser] - функция преобразования JSON в объект ответа
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
  ///
  /// [methodName] - название метода
  /// [handler] - обработчик, возвращающий [ClientStreamingBidiStream]
  /// [argumentParser] - функция преобразования JSON в объект запроса
  /// [responseParser] - функция преобразования JSON в объект ответа
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
