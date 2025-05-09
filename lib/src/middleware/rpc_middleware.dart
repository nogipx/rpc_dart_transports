// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Направление потока данных
enum RpcDataDirection {
  /// Данные отправляются удаленной стороне
  toRemote('↗'),

  /// Данные получены от удаленной стороны
  fromRemote('↘');

  final String symbol;

  const RpcDataDirection(this.symbol);
}

/// Базовый интерфейс для middleware RPC
///
/// Middleware используется для перехвата и обработки запросов, ответов и ошибок
/// в конвейере RPC.
abstract interface class IRpcMiddleware {
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
    RpcDataDirection direction,
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
    RpcDataDirection direction,
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
    RpcDataDirection direction,
  );

  /// Вызывается при получении данных потока
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [data] - данные потока
  /// [streamId] - ID потока
  /// [direction] - направление потока данных (к удаленной стороне или от нее)
  ///
  /// Возвращает либо модифицированные данные, либо исходные.
  FutureOr<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    RpcDataDirection direction,
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
abstract class SimpleRpcMiddleware implements IRpcMiddleware {
  @override
  FutureOr<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) =>
      payload;

  @override
  FutureOr<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) =>
      response;

  @override
  FutureOr<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) =>
      error;

  @override
  FutureOr<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    RpcDataDirection direction,
  ) =>
      data;

  @override
  FutureOr<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {}
}
