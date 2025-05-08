import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Middleware для отладки RPC-вызовов
///
/// Логирует все запросы, ответы, ошибки и потоковые данные
/// аналогично DebugTransport, но на уровне RPC-вызовов
class DebugMiddleware implements RpcMiddleware {
  /// Идентификатор для логов
  final String id;

  /// Функция для логирования
  final void Function(String message)? _logger;

  /// Создает middleware для отладки
  ///
  /// [id] - идентификатор для логов, помогает различать несколько экземпляров
  /// [logger] - опциональная функция для логирования, по умолчанию print
  DebugMiddleware({
    this.id = 'default',
    void Function(String message)? logger,
  }) : _logger = logger;

  /// Внутренний метод для логирования
  void _log(String message) {
    final logMessage = 'DebugMiddleware[$id]: $message';
    _logger != null ? _logger!(logMessage) : print(logMessage);
  }

  @override
  FutureOr<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
  ) {
    _log('ЗАПРОС: $serviceName.$methodName');
    _log('ID: ${context.messageId}');
    _log('Payload: $payload');

    if (context.metadata != null && context.metadata!.isNotEmpty) {
      _log('Metadata: ${context.metadata}');
    }

    return payload;
  }

  @override
  FutureOr<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
  ) {
    _log('ОТВЕТ: $serviceName.$methodName');
    _log('ID: ${context.messageId}');
    _log('Response: $response');

    if (context.metadata != null && context.metadata!.isNotEmpty) {
      _log('Metadata: ${context.metadata}');
    }

    return response;
  }

  @override
  FutureOr<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
  ) {
    _log('ОШИБКА: $serviceName.$methodName');
    _log('ID: ${context.messageId}');
    _log('Error: $error');

    if (stackTrace != null) {
      _log('StackTrace: $stackTrace');
    }

    if (context.metadata != null && context.metadata!.isNotEmpty) {
      _log('Metadata: ${context.metadata}');
    }

    return error;
  }

  @override
  FutureOr<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    StreamDataDirection direction,
  ) {
    final directionText = direction == StreamDataDirection.toRemote
        ? 'ОТПРАВКА В ПОТОК'
        : 'ПОЛУЧЕНИЕ ИЗ ПОТОКА';

    _log('$directionText: $serviceName.$methodName');
    _log('StreamID: $streamId');
    _log('Data: $data');

    return data;
  }

  @override
  FutureOr<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {
    _log('ПОТОК ЗАКРЫТ: $serviceName.$methodName');
    _log('StreamID: $streamId');
  }
}

/// Расширенная версия DebugMiddleware с замером производительности
class DebugWithTimingMiddleware extends DebugMiddleware {
  /// Хранилище времени начала запросов по ID сообщения
  final Map<String, DateTime> _requestStartTimes = {};

  /// Создает middleware для отладки с замером времени
  DebugWithTimingMiddleware({
    super.id = 'timing',
    super.logger,
  });

  @override
  FutureOr<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
  ) {
    _requestStartTimes[context.messageId] = DateTime.now();
    return super.onRequest(serviceName, methodName, payload, context);
  }

  @override
  FutureOr<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
  ) {
    _logTiming(serviceName, methodName, context.messageId);
    return super.onResponse(serviceName, methodName, response, context);
  }

  @override
  FutureOr<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
  ) {
    _logTiming(serviceName, methodName, context.messageId);
    return super.onError(serviceName, methodName, error, stackTrace, context);
  }

  /// Вычисляет и логирует время выполнения запроса
  void _logTiming(String serviceName, String methodName, String messageId) {
    final startTime = _requestStartTimes.remove(messageId);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _log(
          'ВРЕМЯ ВЫПОЛНЕНИЯ $serviceName.$methodName: ${duration.inMilliseconds}ms');
    }
  }
}
