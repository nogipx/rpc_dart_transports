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
    final logMessage = 'DebugMiddleware[$id]: \n$message';
    _logger != null ? _logger!(logMessage) : print(logMessage);
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

    if (context.metadata != null && context.metadata!.isNotEmpty) {
      message += '\nMetadata: ${context.metadata}';
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

    if (context.metadata != null && context.metadata!.isNotEmpty) {
      message += '\nMetadata: ${context.metadata}';
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

    if (context.metadata != null && context.metadata!.isNotEmpty) {
      message += '\nMetadata: ${context.metadata}';
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
    RpcDataDirection direction,
  ) {
    _requestStartTimes[context.messageId] = DateTime.now();
    return super
        .onRequest(serviceName, methodName, payload, context, direction);
  }

  @override
  FutureOr<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    _logTiming(serviceName, methodName, context.messageId);
    return super
        .onResponse(serviceName, methodName, response, context, direction);
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
    _logTiming(serviceName, methodName, context.messageId);
    return super.onError(
        serviceName, methodName, error, stackTrace, context, direction);
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
