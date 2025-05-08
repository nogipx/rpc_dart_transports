import 'dart:math';

import 'package:rpc_dart/rpc_dart.dart';

import '_index.dart';

final class ServerCalculatorContract extends CalculatorContract {
  @override
  RpcEndpoint? get endpoint => null;

  /// Реализация метода сложения
  @override
  Future<CalculatorResponse> add(CalculatorRequest request) async {
    return CalculatorResponse(request.a + request.b);
  }

  /// Реализация метода умножения
  @override
  Future<CalculatorResponse> multiply(CalculatorRequest request) async {
    return CalculatorResponse(request.a * request.b);
  }

  /// Реализация метода генерации последовательности
  @override
  Stream<SequenceData> generateSequence(SequenceRequest request) {
    final random = Random();
    return Stream.periodic(
      const Duration(milliseconds: 300),
      (i) => SequenceData(random.nextInt(100)),
    ).take(request.count);
  }
}
