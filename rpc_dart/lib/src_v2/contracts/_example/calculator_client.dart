import 'dart:async';
import 'calculator_contract.dart';
import 'calculator_interface.dart';
import '../_index.dart';

/// Клиентская реализация калькулятора
class CalculatorClient extends RpcClientContract
    implements ICalculatorContract {
  /// Создает клиента с указанным эндпоинтом
  CalculatorClient(RpcClientEndpoint endpoint)
      : super('CalculatorService', endpoint);

  @override
  Future<CalculationResponse> calculate(CalculationRequest request) {
    return endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: ICalculatorContract.methodCalculate,
        )
        .call(
          request: request,
          responseParser: CalculationResponse.fromJson,
        );
  }

  @override
  Stream<CalculationResponse> streamCalculate(
      Stream<CalculationRequest> requests) {
    return endpoint
        .bidirectionalStream(
          serviceName: serviceName,
          methodName: ICalculatorContract.methodStreamCalculate,
        )
        .call(
          requests: requests,
          responseParser: CalculationResponse.fromJson,
        );
  }

  /// Удобный метод для сложения
  Future<double> add(double a, double b) async {
    final request = CalculationRequest(a: a, b: b, operation: 'add');
    final response = await calculate(request);
    if (!response.success || response.result == null) {
      throw Exception(response.errorMessage ?? 'Failed to calculate');
    }
    return response.result!;
  }

  /// Удобный метод для вычитания
  Future<double> subtract(double a, double b) async {
    final request = CalculationRequest(a: a, b: b, operation: 'subtract');
    final response = await calculate(request);
    if (!response.success || response.result == null) {
      throw Exception(response.errorMessage ?? 'Failed to calculate');
    }
    return response.result!;
  }

  /// Удобный метод для умножения
  Future<double> multiply(double a, double b) async {
    final request = CalculationRequest(a: a, b: b, operation: 'multiply');
    final response = await calculate(request);
    if (!response.success || response.result == null) {
      throw Exception(response.errorMessage ?? 'Failed to calculate');
    }
    return response.result!;
  }

  /// Удобный метод для деления
  Future<double> divide(double a, double b) async {
    final request = CalculationRequest(a: a, b: b, operation: 'divide');
    final response = await calculate(request);
    if (!response.success || response.result == null) {
      throw Exception(response.errorMessage ?? 'Failed to calculate');
    }
    return response.result!;
  }

  /// Пример использования клиента с бинарной сериализацией
  Future<CalculationResponse> calculateBinary({
    required double a,
    required double b,
    required String operation,
  }) {
    final request = BinaryCalculationRequest(
      a: a,
      b: b,
      operation: operation,
    );

    return endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: ICalculatorContract.methodCalculate,
          preferredFormat: RpcSerializationFormat.binary,
        )
        .call(
          request: request,
          responseParser: CalculationResponse.fromJson,
        );
  }
}
