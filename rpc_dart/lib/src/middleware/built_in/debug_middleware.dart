// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Middleware для отладки RPC-вызовов
///
/// Логирует все запросы, ответы, ошибки и потоковые данные
/// аналогично DebugTransport, но на уровне RPC-вызовов
class DebugMiddleware implements IRpcMiddleware {
  /// Функция для логирования
  final RpcLogger _logger;

  /// Создает middleware для отладки
  ///
  /// [logger] - опциональная функция для логирования, по умолчанию print
  DebugMiddleware(RpcLogger logger) : _logger = logger;

  /// Внутренний метод для логирования
  void _log(String message) {
    _logger.debug(message);
  }

  @override
  FutureOr<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    var message = '${direction.symbol} ЗАПРОС: $serviceName.$methodName\n'
        'ID: ${context.messageId}\n'
        'Payload: $payload';

    if (context.headerMetadata != null && context.headerMetadata!.isNotEmpty) {
      message += '\nMetadata: ${context.headerMetadata}';
    }

    _log('$message\n');

    return payload;
  }

  @override
  FutureOr<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    var message = '${direction.symbol} ОТВЕТ: $serviceName.$methodName\n'
        'ID: ${context.messageId}\n'
        'Response: $response';

    if (context.headerMetadata != null && context.headerMetadata!.isNotEmpty) {
      message += '\nMetadata: ${context.headerMetadata}';
    }

    _log('$message\n');

    return response;
  }

  @override
  FutureOr<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    var message = '${direction.symbol} ОШИБКА: $serviceName.$methodName\n'
        'ID: ${context.messageId}\n'
        'Error: $error';

    if (stackTrace != null) {
      message += '\nStackTrace: $stackTrace';
    }

    if (context.headerMetadata != null && context.headerMetadata!.isNotEmpty) {
      message += '\nMetadata: ${context.headerMetadata}';
    }

    _log('$message\n');

    return error;
  }

  @override
  FutureOr<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    RpcDataDirection direction,
  ) {
    final directionText = direction == RpcDataDirection.toRemote
        ? 'ОТПРАВКА В ПОТОК'
        : 'ПОЛУЧЕНИЕ ИЗ ПОТОКА';

    var message =
        '${direction.symbol} $directionText: $serviceName.$methodName\n'
        'StreamID: $streamId\n'
        'Data: $data';

    _log('$message\n');

    return data;
  }

  @override
  FutureOr<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {
    var message = 'ПОТОК ЗАКРЫТ: $serviceName.$methodName\n'
        'StreamID: $streamId';

    _log('$message\n');
  }
}
