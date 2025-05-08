import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Класс для последовательного выполнения нескольких middleware
///
/// Позволяет добавлять несколько middleware и выполнять их в нужном порядке.
/// Для запросов middleware выполняются в порядке добавления.
/// Для ответов и ошибок - в обратном порядке.
final class RpcMiddlewareChain {
  /// Список middleware в цепочке
  final List<RpcMiddleware> _middlewares = [];

  /// Добавляет middleware в цепочку
  ///
  /// [middleware] - объект реализующий RpcMiddleware
  void add(RpcMiddleware middleware) {
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
  /// Возвращает обработанную полезную нагрузку
  Future<dynamic> executeRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
  ) async {
    if (isEmpty) return payload;

    dynamic currentPayload = payload;

    for (final middleware in _middlewares) {
      currentPayload = await middleware.onRequest(
        serviceName,
        methodName,
        currentPayload,
        context,
      );
    }

    return currentPayload;
  }

  /// Выполняет цепочку middleware для обработки ответа
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [response] - исходный ответ
  /// [context] - контекст запроса
  ///
  /// Возвращает обработанный ответ
  Future<dynamic> executeResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
  ) async {
    if (isEmpty) return response;

    dynamic currentResponse = response;

    // Выполняем в обратном порядке (от самых свежих к самым ранним)
    for (final middleware in _middlewares.reversed) {
      currentResponse = await middleware.onResponse(
        serviceName,
        methodName,
        currentResponse,
        context,
      );
    }

    return currentResponse;
  }

  /// Выполняет цепочку middleware для обработки ошибки
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [error] - исходная ошибка
  /// [stackTrace] - трассировка стека (опционально)
  /// [context] - контекст запроса
  ///
  /// Возвращает обработанную ошибку или преобразованный ответ
  Future<dynamic> executeError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
  ) async {
    if (isEmpty) return error;

    dynamic currentError = error;
    StackTrace? currentStackTrace = stackTrace;

    try {
      // Выполняем в обратном порядке (от самых свежих к самым ранним)
      for (final middleware in _middlewares.reversed) {
        currentError = await middleware.onError(
          serviceName,
          methodName,
          currentError,
          currentStackTrace,
          context,
        );
      }
      return currentError;
    } catch (e, _) {
      // Если middleware повторно бросает ошибку, используем её
      return e;
    }
  }

  /// Выполняет цепочку middleware для обработки данных потока
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [data] - исходные данные
  /// [streamId] - ID потока
  ///
  /// Возвращает обработанные данные
  Future<dynamic> executeStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
  ) async {
    if (isEmpty) return data;

    dynamic currentData = data;

    for (final middleware in _middlewares) {
      currentData = await middleware.onStreamData(
        serviceName,
        methodName,
        currentData,
        streamId,
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
