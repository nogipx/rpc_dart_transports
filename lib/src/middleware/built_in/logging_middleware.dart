import 'package:rpc_dart/rpc_dart.dart'
    show RpcMethodContext, SimpleRpcMiddleware;

/// Middleware для логирования RPC-вызовов
class LoggingMiddleware implements SimpleRpcMiddleware {
  /// Функция для логирования
  final void Function(String message)? _logger;

  /// Создает middleware для логирования
  ///
  /// [logger] - опциональная функция для логирования
  /// Если не указана, используется `print`
  LoggingMiddleware({void Function(String message)? logger}) : _logger = logger;

  /// Внутренний метод для логирования сообщений
  void _log(String message) {
    _logger != null ? _logger!(message) : print(message);
  }

  @override
  Future<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
  ) {
    _log('[RPC REQUEST] $serviceName.$methodName: $payload');
    return Future.value(payload);
  }

  @override
  Future<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
  ) {
    _log('[RPC RESPONSE] $serviceName.$methodName: $response');
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
    _log('[RPC ERROR] $serviceName.$methodName: $error');
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
  ) {
    _log('[RPC STREAM DATA] $serviceName.$methodName[$streamId]: $data');
    return Future.value(data);
  }

  @override
  Future<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {
    _log('[RPC STREAM END] $serviceName.$methodName[$streamId]');
    return Future.value();
  }
}
