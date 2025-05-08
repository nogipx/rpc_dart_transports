import 'dart:math';

import 'package:rpc_dart/rpc_dart.dart';

import '_index.dart';

final class ServerCalculatorContract extends CalculatorContract {
  @override
  TypedRpcEndpoint? get endpoint => null;

  /// Реализация метода сложения
  @override
  Future<CalculatorResponse> add(CalculatorRequest request) async {
    print('⚙️ Сервер: метод add с параметрами ${request.a} и ${request.b}');
    return CalculatorResponse(request.a + request.b);
  }

  /// Реализация метода умножения
  @override
  Future<CalculatorResponse> multiply(CalculatorRequest request) async {
    print(
        '⚙️ Сервер: метод multiply с параметрами ${request.a} и ${request.b}');
    return CalculatorResponse(request.a * request.b);
  }

  /// Реализация метода генерации последовательности
  @override
  Stream<SequenceData> generateSequence(SequenceRequest request) {
    final random = Random();
    print(
        '⚙️ Сервер: начало стриминга последовательности (count: ${request.count})');
    return Stream.periodic(
      const Duration(milliseconds: 300),
      (i) => SequenceData(random.nextInt(100)),
    ).take(request.count);
  }
}
