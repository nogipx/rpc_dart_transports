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
  Stream<R> serverStream<C, R>({
    required String serviceName,
    required String methodName,
    required IRpcCodec<C> requestCodec,
    required IRpcCodec<R> responseCodec,
    required C request,
  }) async* {
    final caller = ServerStreamCaller<C, R>(
      serviceName: serviceName,
      methodName: methodName,
      transport: transport,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );

    await caller.send(request);
    yield* caller.responses
        .where((e) => e.payload != null)
        .map((e) => e.payload!);
  }

  /// Создает client stream builder
  Future<R> Function() clientStream<C, R>({
    required String serviceName,
    required String methodName,
    required IRpcCodec<C> requestCodec,
    required IRpcCodec<R> responseCodec,
    required Stream<C> requests,
  }) {
    final caller = ClientStreamCaller<C, R>(
      serviceName: serviceName,
      methodName: methodName,
      transport: transport,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );
    StreamSubscription? sub;
    sub = requests.listen(
      caller.send,
      onDone: () async {
        await sub?.cancel();
      },
    );

    return () async {
      await sub?.cancel();
      return caller.finishSending();
    };
  }

  /// Создает bidirectional stream builder
  Stream<R> bidirectionalStream<C, R>({
    required String serviceName,
    required String methodName,
    required IRpcCodec<C> requestCodec,
    required IRpcCodec<R> responseCodec,
    required Stream<C> requests,
  }) async* {
    final caller = BidirectionalStreamCaller<C, R>(
      serviceName: serviceName,
      methodName: methodName,
      transport: transport,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );

    await requests.pipe(caller.requests);
    yield* caller.responses
        .where((e) => e.payload != null)
        .map((e) => e.payload!);
  }
}
