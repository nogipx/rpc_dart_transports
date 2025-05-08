import 'package:rpc_dart/rpc_dart.dart';

import '_index.dart';

final class ClientCalculatorContract extends CalculatorContract {
  @override
  final RpcEndpoint endpoint;

  ClientCalculatorContract(this.endpoint);

  @override
  Future<CalculatorResponse> add(CalculatorRequest request) {
    return endpoint.invokeTyped<CalculatorRequest, CalculatorResponse>(
      serviceName: serviceName,
      methodName: 'add',
      request: request,
    );
  }

  @override
  Future<CalculatorResponse> multiply(CalculatorRequest request) {
    return endpoint.invokeTyped<CalculatorRequest, CalculatorResponse>(
      serviceName: serviceName,
      methodName: 'multiply',
      request: request,
    );
  }

  @override
  Stream<SequenceData> generateSequence(SequenceRequest request) {
    return endpoint.openTypedStream<SequenceRequest, SequenceData>(
      serviceName,
      'generateSequence',
      request,
    );
  }
}
