import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Базовый интерфейс для middleware RPC
///
/// Middleware используется для перехвата и обработки запросов, ответов и ошибок
/// в конвейере RPC.
abstract class RpcMiddleware {
  /// Вызывается перед обработкой запроса
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [payload] - исходная полезная нагрузка
  /// [context] - контекст запроса
  ///
  /// Возвращает либо модифицированный payload, либо исходный если не требуется изменений.
  /// Может кинуть исключение для прерывания обработки запроса.
  FutureOr<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
  );

  /// Вызывается после успешной обработки запроса
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [response] - исходный ответ
  /// [context] - контекст запроса
  ///
  /// Возвращает либо модифицированный результат, либо исходный.
  FutureOr<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
  );

  /// Вызывается при возникновении ошибки в обработке запроса
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [error] - исходная ошибка
  /// [stackTrace] - трассировка стека (опционально)
  /// [context] - контекст запроса
  ///
  /// Может вернуть новый ответ (чтобы преобразовать ошибку) или повторно выбросить ошибку.
  FutureOr<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
  );

  /// Вызывается при получении данных потока
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [data] - данные потока
  /// [streamId] - ID потока
  ///
  /// Возвращает либо модифицированные данные, либо исходные.
  FutureOr<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
  );

  /// Вызывается при завершении потока
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [streamId] - ID потока
  FutureOr<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  );
}

/// Упрощенный интерфейс middleware с пустыми реализациями по умолчанию
///
/// Используется для случаев, когда нужно перехватить только часть операций
abstract class SimpleRpcMiddleware implements RpcMiddleware {
  @override
  FutureOr<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
  ) =>
      payload;

  @override
  FutureOr<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
  ) =>
      response;

  @override
  FutureOr<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
  ) =>
      error;

  @override
  FutureOr<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
  ) =>
      data;

  @override
  FutureOr<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {}
}
