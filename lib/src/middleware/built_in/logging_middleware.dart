import 'package:rpc_dart/rpc_dart.dart'
    show RpcMethodContext, SimpleRpcMiddleware, StreamDataDirection;

/// Middleware для логирования RPC-вызовов
class LoggingMiddleware implements SimpleRpcMiddleware {
  final String id;

  /// Функция для логирования
  final void Function(String message)? _logger;

  /// Создает middleware для логирования
  ///
  /// [logger] - опциональная функция для логирования
  /// Если не указана, используется `print`
  LoggingMiddleware({void Function(String message)? logger, this.id = ""})
      : _logger = logger;

  /// Внутренний метод для логирования сообщений
  void _log(String message) {
    final prefix = id.isEmpty ? "LoggingMiddleware" : "LoggingMiddleware[$id]";
    _logger != null
        ? _logger!("$prefix: $message")
        : print("$prefix: $message");
  }

  @override
  Future<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
  ) {
    _log('[REQ] $serviceName.$methodName: $payload');
    return Future.value(payload);
  }

  @override
  Future<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
  ) {
    _log('[RES] $serviceName.$methodName: $response');
    return Future.value(response);
  }

  @override
  Future<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
  ) {
    _log('[ERR] $serviceName.$methodName: $error');
    if (stackTrace != null) {
      _log(stackTrace.toString());
    }
    return Future.value(error);
  }

  @override
  Future<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    StreamDataDirection direction,
  ) {
    final directionMark = direction == StreamDataDirection.toRemote ? '↗' : '↘';
    _log('[STR $directionMark] $serviceName.$methodName[$streamId]: $data');
    return Future.value(data);
  }

  @override
  Future<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {
    _log('[STR END] $serviceName.$methodName[$streamId]');
    return Future.value();
  }
}
