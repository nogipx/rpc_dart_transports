import 'package:rpc_dart/rpc_dart.dart';

import '_index.dart';

final class ClientCalculatorContract extends CalculatorContract {
  @override
  final RpcEndpoint endpoint;

  ClientCalculatorContract(this.endpoint);

  @override
  Future<CalculatorResponse> add(CalculatorRequest request) {
    return endpoint
        .unary(serviceName, 'add')
        .call<CalculatorRequest, CalculatorResponse>(
          request: request,
          responseParser: CalculatorResponse.fromJson,
        );
  }

  @override
  Future<CalculatorResponse> multiply(CalculatorRequest request) {
    return endpoint
        .unary(serviceName, 'multiply')
        .call<CalculatorRequest, CalculatorResponse>(
          request: request,
          responseParser: CalculatorResponse.fromJson,
        );
  }

  @override
  Stream<SequenceData> generateSequence(SequenceRequest request) {
    return endpoint
        .serverStreaming(serviceName, 'generateSequence')
        .openStream<SequenceRequest, SequenceData>(
          request: request,
          responseParser: SequenceData.fromJson,
        );
  }
}
