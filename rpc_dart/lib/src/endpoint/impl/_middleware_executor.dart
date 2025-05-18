// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Исполнитель middleware-цепочки для обработки запросов и ответов
final class _MiddlewareExecutor {
  /// Цепочка middleware для обработки запросов и ответов
  final RpcMiddlewareChain _middlewareChain = RpcMiddlewareChain();
  final RpcLogger _logger = RpcLogger('MiddlewareExecutor');

  /// Добавляет middleware в цепочку обработки
  void addMiddleware(IRpcMiddleware middleware) {
    _middlewareChain.add(middleware);
  }

  /// Выполняет обработку запроса через цепочку middleware
  Future<RpcMiddlewareResult> executeRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    IRpcContext context,
    RpcDataDirection direction,
  ) async {
    try {
      return await _middlewareChain.executeRequest(
          serviceName, methodName, payload, context, direction);
    } catch (e, stackTrace) {
      _logger.error(
        'Ошибка при выполнении middleware для запроса $serviceName.$methodName: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // В случае ошибки возвращаем исходные данные без изменений
      return RpcMiddlewareResult(payload, context);
    }
  }

  /// Выполняет обработку ответа через цепочку middleware
  Future<RpcMiddlewareResult> executeResponse(
    String serviceName,
    String methodName,
    dynamic payload,
    IRpcContext context,
    RpcDataDirection direction,
  ) async {
    try {
      return await _middlewareChain.executeResponse(
          serviceName, methodName, payload, context, direction);
    } catch (e, stackTrace) {
      _logger.error(
        'Ошибка при выполнении middleware для ответа $serviceName.$methodName: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // В случае ошибки возвращаем исходные данные без изменений
      return RpcMiddlewareResult(payload, context);
    }
  }

  /// Выполняет обработку данных потока через цепочку middleware
  Future<dynamic> executeStreamData(
    String serviceName,
    String methodName,
    dynamic payload,
    String streamId,
    RpcDataDirection direction,
  ) async {
    try {
      return await _middlewareChain.executeStreamData(
          serviceName, methodName, payload, streamId, direction);
    } catch (e, stackTrace) {
      _logger.error(
        'Ошибка при выполнении middleware для данных потока $serviceName.$methodName: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // В случае ошибки возвращаем исходные данные без изменений
      return payload;
    }
  }

  /// Выполняет обработку завершения потока через цепочку middleware
  Future<void> executeStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) async {
    try {
      await _middlewareChain.executeStreamEnd(
          serviceName, methodName, streamId);
    } catch (e, stackTrace) {
      _logger.error(
        'Ошибка при выполнении middleware для завершения потока $serviceName.$methodName: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Выполняет обработку ошибки через цепочку middleware
  Future<RpcMiddlewareResult> executeError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace stackTrace,
    IRpcContext context,
    RpcDataDirection direction,
  ) async {
    try {
      return await _middlewareChain.executeError(
          serviceName, methodName, error, stackTrace, context, direction);
    } catch (e, innerStackTrace) {
      _logger.error(
        'Ошибка при выполнении middleware для обработки ошибки $serviceName.$methodName: $e',
        error: e,
        stackTrace: innerStackTrace,
      );
      // В случае ошибки возвращаем исходную ошибку без изменений
      return RpcMiddlewareResult(error, context);
    }
  }
}
