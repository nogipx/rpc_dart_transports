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
    final allMethods = <RpcMethodContract<T, T>>[];
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
    throw UnsupportedError(
      'Нельзя напрямую добавить метод в композитный контракт. Используйте подконтракты.',
    );
  }

  @override
  void addServerStreamingMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodServerStreamHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    throw UnsupportedError(
      'Нельзя напрямую добавить метод в композитный контракт. Используйте подконтракты.',
    );
  }

  @override
  void addClientStreamingMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodClientStreamHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    throw UnsupportedError(
      'Нельзя напрямую добавить метод в композитный контракт. Используйте подконтракты.',
    );
  }

  @override
  void addBidirectionalStreamingMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodBidirectionalHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    throw UnsupportedError(
      'Нельзя напрямую добавить метод в композитный контракт. Используйте подконтракты.',
    );
  }
}
