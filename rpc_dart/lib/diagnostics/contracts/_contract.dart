import 'package:rpc_dart/diagnostics.dart';
import 'package:rpc_dart/rpc_dart.dart';

abstract class RpcDiagnosticContract extends RpcServiceContract {
  RpcDiagnosticContract() : super('RpcDiagnosticContract');

  static const methodSendError = 'sendError';
  static const methodSendLatency = 'sendLatency';
  static const methodSendStream = 'sendStream';
  static const methodSendResource = 'sendResource';
  static const methodSendTrace = 'sendTrace';

  @override
  void setup() {
    addUnaryRequestMethod<RpcTraceMetric, RpcBool>(
      methodName: methodSendTrace,
      handler: sendTrace,
      argumentParser: RpcTraceMetric.fromJson,
      responseParser: RpcBool.fromJson,
    );

    super.setup();
  }

  Future<RpcBool> sendTrace(RpcTraceMetric p1);
}
