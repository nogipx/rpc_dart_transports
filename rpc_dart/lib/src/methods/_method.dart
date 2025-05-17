// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

part '_method_implementation.dart';
part 'bidirectional_streaming_method.dart';
part 'client_streaming_method.dart';
part 'server_streaming_method.dart';
part 'unary_request_method.dart';

/// Базовый абстрактный класс для всех типов RPC методов
abstract base class RpcMethod<T extends IRpcSerializableMessage> {
  /// Endpoint, с которым связан метод
  final IRpcEndpoint<T> _endpoint;

  /// Название сервиса
  final String serviceName;

  /// Название метода
  final String methodName;

  /// Логгер для этого инстанса метода
  late final RpcLogger _logger;

  /// Создает новый объект RPC метода
  RpcMethod(this._endpoint, this.serviceName, this.methodName) {
    _logger = RpcLogger('$serviceName.$methodName.base');
  }

  /// Получает контракт метода
  RpcMethodContract<Request, Response>
      getMethodContract<Request extends T, Response extends T>(
    RpcMethodType type,
  ) {
    // Получаем контракт сервиса
    final contract = _endpoint.getServiceContract(serviceName);
    if (contract == null) {
      throw Exception('Контракт сервиса $serviceName не найден');
    }

    // Ищем контракт метода
    final methodContract = contract.findMethod<Request, Response>(methodName);
    if (methodContract == null) {
      // Если метод не найден, создаем временный контракт на основе параметров
      return RpcMethodContract<Request, Response>(
        serviceName: serviceName,
        methodName: methodName,
        methodType: type,
      );
    }

    return methodContract;
  }

  IRpcEndpointCore get _core {
    if (_endpoint is! IRpcEndpointCore) {
      throw ArgumentError('Is not valid subtype');
    }
    return _endpoint as IRpcEndpointCore;
  }

  IRpcRegistrar<T> get _registrar {
    if (_endpoint is! IRpcRegistrar<T>) {
      throw ArgumentError('Is not valid subtype');
    }
    return _endpoint as IRpcRegistrar<T>;
  }
}
