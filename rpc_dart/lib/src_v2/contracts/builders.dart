part of '_index.dart';

/// Builder для унарных запросов
class RpcUnaryRequestBuilder {
  final RpcEndpoint endpoint;
  final String serviceName;
  final String methodName;

  RpcUnaryRequestBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
  });

  Future<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Map<String, dynamic>) responseParser,
  }) async {
    final client = UnaryClient<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: RpcBytesSerializer<TRequest>(
        fromJson: responseParser as TRequest Function(Map<String, dynamic>),
      ),
      responseSerializer: RpcBytesSerializer<TResponse>(
        fromJson: responseParser,
      ),
      logger: endpoint.logger,
    );

    try {
      final response = await client.call(request);
      return response;
    } finally {
      await client.close();
    }
  }
}

/// Builder для серверных стримов
class RpcServerStreamBuilder {
  final RpcEndpoint endpoint;
  final String serviceName;
  final String methodName;

  RpcServerStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
  });

  Stream<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Map<String, dynamic>) responseParser,
  }) async* {
    final client = ServerStreamClient<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: RpcBytesSerializer<TRequest>(
        fromJson: responseParser as TRequest Function(Map<String, dynamic>),
      ),
      responseSerializer: RpcBytesSerializer<TResponse>(
        fromJson: responseParser,
      ),
      logger: endpoint.logger,
    );

    try {
      await client.send(request);
      await for (final message in client.responses) {
        if (message.payload != null) {
          yield message.payload!;
        }
      }
    } finally {
      await client.close();
    }
  }
}

/// Builder для клиентских стримов
class RpcClientStreamBuilder {
  final RpcEndpoint endpoint;
  final String serviceName;
  final String methodName;

  RpcClientStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
  });

  Future<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Map<String, dynamic>) responseParser,
  }) async {
    final client = ClientStreamClient<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: RpcBytesSerializer<TRequest>(
        fromJson: responseParser as TRequest Function(Map<String, dynamic>),
      ),
      responseSerializer: RpcBytesSerializer<TResponse>(
        fromJson: responseParser,
      ),
      logger: endpoint.logger,
    );

    try {
      await for (final request in requests) {
        client.send(request);
      }
      final response = await client.finishSending();
      return response;
    } finally {
      await client.close();
    }
  }
}

/// Builder для двунаправленных стримов
class RpcBidirectionalStreamBuilder {
  final RpcEndpoint endpoint;
  final String serviceName;
  final String methodName;

  RpcBidirectionalStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
  });

  Stream<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Uint8List) responseParser,
  }) async* {
    final client = BidirectionalStreamClient<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: RpcBinarySerializer<TRequest>(
        fromBytes: responseParser as TRequest Function(Uint8List),
      ),
      responseSerializer: RpcBinarySerializer<TResponse>(
        fromBytes: responseParser,
      ),
      logger: endpoint.logger,
    );

    try {
      unawaited(() async {
        await for (final request in requests) {
          client.send(request);
        }
        client.finishSending();
      }());

      await for (final message in client.responses) {
        if (message.payload != null) {
          yield message.payload!;
        }
      }
    } finally {
      await client.close();
    }
  }
}
