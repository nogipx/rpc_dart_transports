part of '../_index.dart';

extension UnaryRpcEndpoint<T extends RpcSerializableMessage> on RpcEndpoint<T> {
  /// Регистрирует типизированную реализацию унарного метода
  void registerUnaryMethod<Request extends T, Response extends T>(
    String serviceName,
    String methodName,
    Future<Response> Function(Request) handler,
    Request Function(Map<String, dynamic>)? argumentParser,
    Response Function(Map<String, dynamic>)? responseParser,
  ) {
    final contract = _getMethodContract<Request, Response>(
      serviceName,
      methodName,
      RpcMethodType.unary,
    );

    final implementation = RpcMethodImplementation.unary(contract, handler);

    _implementations[serviceName]![methodName] = implementation;

    // Регистрируем обертку для стандартного endpoint
    _delegate.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        try {
          // Если request - это Map и мы получили функцию fromJson, преобразуем объект
          final typedRequest = (context.payload is Map<String, dynamic> &&
                  argumentParser != null)
              ? argumentParser(context.payload)
              : context.payload;

          // Получаем типизированный ответ от обработчика
          final response = await implementation.invoke(typedRequest);

          // Преобразуем ответ в формат для передачи (JSON для RpcMessage)
          final result = response is RpcMessage ? response.toJson() : response;

          return result;
        } catch (e) {
          rethrow;
        }
      },
    );
  }
}
