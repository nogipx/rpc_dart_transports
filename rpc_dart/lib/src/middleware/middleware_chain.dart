// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Результат выполнения middleware
///
/// Содержит обработанную нагрузку и обновленный контекст
class RpcMiddlewareResult<T> {
  /// Обработанная полезная нагрузка
  final T payload;

  /// Обновленный контекст
  final IRpcContext context;

  /// Создает результат выполнения middleware
  const RpcMiddlewareResult(this.payload, this.context);
}

/// Класс для последовательного выполнения нескольких middleware
///
/// Позволяет добавлять несколько middleware и выполнять их в нужном порядке.
/// Для запросов middleware выполняются в порядке добавления.
/// Для ответов и ошибок - в обратном порядке.
final class RpcMiddlewareChain {
  /// Список middleware в цепочке
  final List<IRpcMiddleware> _middlewares = [];

  /// Добавляет middleware в цепочку
  ///
  /// [middleware] - объект реализующий RpcMiddleware
  void add(IRpcMiddleware middleware) {
    _middlewares.add(middleware);
  }

  /// Проверяет, есть ли middleware в цепочке
  bool get isEmpty => _middlewares.isEmpty;

  /// Выполняет цепочку middleware для обработки запроса
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [payload] - исходная полезная нагрузка
  /// [context] - контекст запроса
  ///
  /// Возвращает результат, содержащий обработанную полезную нагрузку
  /// и обновленный контекст
  Future<RpcMiddlewareResult<dynamic>> executeRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    IRpcContext context,
    RpcDataDirection direction,
  ) async {
    if (isEmpty) return RpcMiddlewareResult(payload, context);

    dynamic currentPayload = payload;
    IRpcContext currentContext = context;

    for (final middleware in _middlewares) {
      // Сохраняем состояние контекста до вызова middleware
      final beforeContext = currentContext;

      // Применяем middleware к текущему состоянию
      final processedPayload = await middleware.onRequest(
        serviceName,
        methodName,
        currentPayload,
        currentContext,
        direction,
      );

      // Обновляем payload для следующего middleware
      currentPayload = processedPayload;

      // Проверяем, не было ли изменения контекста внутри middleware
      // Переменная currentContext должна быть равна beforeContext если контекст
      // не был изменен внутри middleware
      if (currentContext != beforeContext) {
        // Middleware изменил контекст напрямую - используем обновленный
      } else if (processedPayload != currentPayload) {
        // Если middleware вернул другую полезную нагрузку, обновляем контекст
        if (currentContext is RpcMessage) {
          currentContext = currentContext.withPayload(processedPayload);
        }
      }
    }

    return RpcMiddlewareResult(currentPayload, currentContext);
  }

  /// Выполняет цепочку middleware для обработки ответа
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [response] - исходный ответ
  /// [context] - контекст запроса
  ///
  /// Возвращает результат, содержащий обработанный ответ и обновленный контекст
  Future<RpcMiddlewareResult<dynamic>> executeResponse(
    String serviceName,
    String methodName,
    dynamic response,
    IRpcContext context,
    RpcDataDirection direction,
  ) async {
    if (isEmpty) return RpcMiddlewareResult(response, context);

    dynamic currentResponse = response;
    IRpcContext currentContext = context;

    // Выполняем в обратном порядке (от самых свежих к самым ранним)
    for (final middleware in _middlewares.reversed) {
      // Сохраняем состояние контекста до вызова middleware
      final beforeContext = currentContext;

      // Применяем middleware к текущему состоянию
      final processedResponse = await middleware.onResponse(
        serviceName,
        methodName,
        currentResponse,
        currentContext,
        direction,
      );

      // Обновляем response для следующего middleware
      currentResponse = processedResponse;

      // Проверяем, не было ли изменения контекста внутри middleware
      if (currentContext != beforeContext) {
        // Middleware изменил контекст напрямую - используем обновленный
      }
    }

    return RpcMiddlewareResult(currentResponse, currentContext);
  }

  /// Выполняет цепочку middleware для обработки ошибки
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [error] - исходная ошибка
  /// [stackTrace] - трассировка стека (опционально)
  /// [context] - контекст запроса
  ///
  /// Возвращает результат, содержащий обработанную ошибку и обновленный контекст
  Future<RpcMiddlewareResult<dynamic>> executeError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    IRpcContext context,
    RpcDataDirection direction,
  ) async {
    if (isEmpty) return RpcMiddlewareResult(error, context);

    dynamic currentError = error;
    StackTrace? currentStackTrace = stackTrace;
    IRpcContext currentContext = context;

    try {
      // Выполняем в обратном порядке (от самых свежих к самым ранним)
      for (final middleware in _middlewares.reversed) {
        // Сохраняем состояние контекста до вызова middleware
        final beforeContext = currentContext;

        // Применяем middleware к текущему состоянию
        final processedError = await middleware.onError(
          serviceName,
          methodName,
          currentError,
          currentStackTrace,
          currentContext,
          direction,
        );

        // Обновляем error для следующего middleware
        currentError = processedError;

        // Проверяем, не было ли изменения контекста внутри middleware
        if (currentContext != beforeContext) {
          // Middleware изменил контекст напрямую - используем обновленный
        }
      }
      return RpcMiddlewareResult(currentError, currentContext);
    } catch (e, _) {
      // Если middleware повторно бросает ошибку, используем её
      return RpcMiddlewareResult(e, currentContext);
    }
  }

  /// Выполняет цепочку middleware для обработки данных потока
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [data] - исходные данные
  /// [streamId] - ID потока
  /// [direction] - направление потока данных
  ///
  /// Возвращает обработанные данные
  Future<dynamic> executeStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    RpcDataDirection direction,
  ) async {
    if (isEmpty) return data;

    dynamic currentData = data;

    for (final middleware in _middlewares) {
      currentData = await middleware.onStreamData(
        serviceName,
        methodName,
        currentData,
        streamId,
        direction,
      );
    }

    return currentData;
  }

  /// Выполняет цепочку middleware для завершения потока
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [streamId] - ID потока
  Future<void> executeStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) async {
    if (isEmpty) return;

    // Выполняем в обратном порядке
    for (final middleware in _middlewares.reversed) {
      await middleware.onStreamEnd(
        serviceName,
        methodName,
        streamId,
      );
    }
  }
}
