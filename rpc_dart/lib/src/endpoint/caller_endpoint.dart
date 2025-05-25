part of '_index.dart';

/// Клиентский RPC эндпоинт для отправки запросов
final class RpcCallerEndpoint extends RpcEndpointBase {
  @override
  RpcLogger get logger => RpcLogger(
        'RpcCallerEndpoint',
        colors: loggerColors,
        label: debugLabel,
      );

  RpcCallerEndpoint({
    required super.transport,
    super.debugLabel,
    super.loggerColors,
  });

  /// Создает унарный request builder
  Future<R> unaryRequest<C, R>({
    required String serviceName,
    required String methodName,
    required IRpcCodec<C> requestCodec,
    required IRpcCodec<R> responseCodec,
    required C request,
  }) {
    return UnaryCaller<C, R>(
      serviceName: serviceName,
      methodName: methodName,
      transport: transport,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    ).call(request);
  }

  /// Создает server stream builder
  ServerStreamCaller<C, R> serverStream<C, R>({
    required String serviceName,
    required String methodName,
    required IRpcCodec<C> requestCodec,
    required IRpcCodec<R> responseCodec,
  }) {
    return ServerStreamCaller<C, R>(
      serviceName: serviceName,
      methodName: methodName,
      transport: transport,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );
  }

  /// Создает client stream builder
  ClientStreamCaller<C, R> clientStream<C, R>({
    required String serviceName,
    required String methodName,
    required IRpcCodec<C> requestCodec,
    required IRpcCodec<R> responseCodec,
  }) {
    return ClientStreamCaller<C, R>(
      serviceName: serviceName,
      methodName: methodName,
      transport: transport,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );
  }

  /// Создает bidirectional stream builder
  Stream<R> bidirectionalStream<C, R>({
    required String serviceName,
    required String methodName,
    required IRpcCodec<C> requestCodec,
    required IRpcCodec<R> responseCodec,
  }) {
    return BidirectionalStreamCaller<C, R>(
      serviceName: serviceName,
      methodName: methodName,
      transport: transport,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    ).responses.where((e) => e.payload != null).map((e) => e.payload!);
  }
}
