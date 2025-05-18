// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Обертка для быстрого создания middleware с функциональным подходом
///
/// Позволяет создавать middleware, указав только нужные обработчики,
/// без необходимости реализовывать полный интерфейс [IRpcMiddleware].
///
/// Пример использования:
/// ```dart
/// final authMiddleware = RpcMiddlewareWrapper(
///   debugLabel: 'Auth',
///   onRequestHandler: (serviceName, methodName, payload, context, direction) {
///     // Проверка авторизации
///     if (context.metadata?['token'] != 'valid-token') {
///       throw Exception('Unauthorized');
///     }
///     return payload;
///   },
/// );
/// ```
class RpcMiddlewareWrapper implements SimpleRpcMiddleware {
  /// Метка для отладки
  final String? debugLabel;

  /// Обработчик запросов
  final FutureOr<dynamic> Function(
    String serviceName,
    String methodName,
    dynamic payload,
    IRpcContext context,
    RpcDataDirection direction,
  )? onRequestHandler;

  /// Обработчик ответов
  final FutureOr<dynamic> Function(
    String serviceName,
    String methodName,
    dynamic response,
    IRpcContext context,
    RpcDataDirection direction,
  )? onResponseHandler;

  /// Обработчик ошибок
  final FutureOr<dynamic> Function(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    IRpcContext context,
    RpcDataDirection direction,
  )? onErrorHandler;

  /// Обработчик данных потока
  final FutureOr<dynamic> Function(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    RpcDataDirection direction,
  )? onStreamDataHandler;

  /// Обработчик завершения потока
  final FutureOr<void> Function(
    String serviceName,
    String methodName,
    String streamId,
  )? onStreamEndHandler;

  /// Создает новую обертку middleware
  ///
  /// [debugLabel] - метка для отладки
  /// [onRequestHandler] - обработчик запросов
  /// [onResponseHandler] - обработчик ответов
  /// [onErrorHandler] - обработчик ошибок
  /// [onStreamDataHandler] - обработчик данных потока
  /// [onStreamEndHandler] - обработчик завершения потока
  RpcMiddlewareWrapper({
    this.debugLabel,
    this.onRequestHandler,
    this.onResponseHandler,
    this.onErrorHandler,
    this.onStreamDataHandler,
    this.onStreamEndHandler,
  });

  @override
  FutureOr<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    IRpcContext context,
    RpcDataDirection direction,
  ) {
    return onRequestHandler?.call(
          serviceName,
          methodName,
          payload,
          context,
          direction,
        ) ??
        payload;
  }

  @override
  FutureOr<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    IRpcContext context,
    RpcDataDirection direction,
  ) {
    return onResponseHandler?.call(
          serviceName,
          methodName,
          response,
          context,
          direction,
        ) ??
        response;
  }

  @override
  FutureOr<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    IRpcContext context,
    RpcDataDirection direction,
  ) {
    return onErrorHandler?.call(
          serviceName,
          methodName,
          error,
          stackTrace,
          context,
          direction,
        ) ??
        error;
  }

  @override
  FutureOr<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    RpcDataDirection direction,
  ) {
    return onStreamDataHandler?.call(
          serviceName,
          methodName,
          data,
          streamId,
          direction,
        ) ??
        data;
  }

  @override
  FutureOr<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {
    onStreamEndHandler?.call(serviceName, methodName, streamId);
  }

  @override
  String toString() =>
      'RpcMiddlewareWrapper${debugLabel != null ? "($debugLabel)" : ""}';
}
