part of '_index.dart';

/// Клиентский RPC эндпоинт для отправки запросов
final class RpcCallerEndpoint extends RpcEndpointBase {
  @override
  RpcLogger get logger => RpcLogger(
        'RpcCallerEndpoint[${debugLabel ?? ''}]',
        colors: loggerColors,
      );

  RpcCallerEndpoint({
    required super.transport,
    super.debugLabel,
    super.loggerColors,
  });

  /// Создает унарный request builder
  RpcUnaryRequestBuilder unaryRequest({
    required String serviceName,
    required String methodName,
  }) {
    return RpcUnaryRequestBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
    );
  }

  /// Создает server stream builder
  RpcServerStreamBuilder serverStream({
    required String serviceName,
    required String methodName,
  }) {
    return RpcServerStreamBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
    );
  }

  /// Создает client stream builder
  RpcClientStreamBuilder clientStream({
    required String serviceName,
    required String methodName,
  }) {
    return RpcClientStreamBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
    );
  }

  /// Создает bidirectional stream builder
  RpcBidirectionalStreamBuilder bidirectionalStream({
    required String serviceName,
    required String methodName,
  }) {
    return RpcBidirectionalStreamBuilder(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
    );
  }
}
