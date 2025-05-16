// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart'
    show RpcMethodContext, SimpleRpcMiddleware, RpcDataDirection;
import 'package:rpc_dart/diagnostics.dart' show RpcLog;

/// Middleware для измерения времени выполнения RPC-вызовов
class TimingMiddleware implements SimpleRpcMiddleware {
  /// Хранилище времени начала запросов по ID сообщения
  final Map<String, DateTime> _requestStartTimes = {};

  /// Функция для логирования результатов измерений
  final void Function(String message, Duration duration)? _onTiming;

  /// Создает middleware для измерения времени
  ///
  /// [onTiming] - опциональная функция для логирования результатов измерений
  TimingMiddleware({void Function(String message, Duration duration)? onTiming})
      : _onTiming = onTiming;

  /// Внутренний метод логирования результатов измерений
  void _logTiming(String message, Duration duration) {
    if (_onTiming != null) {
      _onTiming!(message, duration);
    } else {
      RpcLog.info(
        message: '$message: ${duration.inMilliseconds}ms',
        source: 'TimingMiddleware',
      );
    }
  }

  @override
  Future<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    _requestStartTimes[context.messageId] = DateTime.now();
    return Future.value(payload);
  }

  @override
  Future<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    final startTime = _requestStartTimes.remove(context.messageId);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _logTiming('$serviceName.$methodName completed', duration);
    }
    return Future.value(response);
  }

  @override
  Future<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    final startTime = _requestStartTimes.remove(context.messageId);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _logTiming('$serviceName.$methodName failed', duration);
    }
    return Future.value(error);
  }

  @override
  Future<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    RpcDataDirection direction,
  ) {
    // Для стрим-данных не замеряем время, просто пропускаем
    return Future.value(data);
  }

  @override
  Future<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {
    // Для завершения стрима не делаем специальных действий
    return Future.value();
  }
}
