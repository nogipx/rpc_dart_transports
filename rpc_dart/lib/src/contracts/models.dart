// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Типы RPC методов
enum RpcMethodType {
  unaryRequest,
  serverStream,
  clientStream,
  bidirectionalStream,
}

/// Регистрация метода в контракте
class RpcMethodRegistration<TRequest extends IRpcSerializable,
    TResponse extends IRpcSerializable> {
  final String name;
  final RpcMethodType type;
  final Function handler;
  final String description;
  final IRpcCodec<TRequest> requestCodec;
  final IRpcCodec<TResponse> responseCodec;

  const RpcMethodRegistration({
    required this.name,
    required this.type,
    required this.handler,
    required this.description,
    required this.requestCodec,
    required this.responseCodec,
  });
}

/// Исключение для RpcEndpoint
class RpcException implements Exception {
  final String message;

  RpcException(this.message);

  @override
  String toString() => 'RpcException: $message';
}

/// Интерфейс для middleware
abstract class IRpcMiddleware {
  Future<dynamic> processRequest(
    String serviceName,
    String methodName,
    dynamic request,
  );

  Future<dynamic> processResponse(
    String serviceName,
    String methodName,
    dynamic response,
  );
}
