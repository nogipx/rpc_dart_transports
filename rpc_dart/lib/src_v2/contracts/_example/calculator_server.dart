import 'dart:async';
import 'calculator_contract.dart';
import '../_index.dart';

/// Серверная реализация калькулятора
class CalculatorServer extends CalculatorContract {
  /// Настраиваемая задержка (мс) для имитации вычислений
  final int simulatedDelayMs;

  /// Конструктор с опциональной настройкой задержки
  CalculatorServer({this.simulatedDelayMs = 0});

  @override
  Future<CalculationResponse> calculate(CalculationRequest request) async {
    // Имитация задержки обработки на сервере
    if (simulatedDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: simulatedDelayMs));
    }

    // Проверяем валидность операции
    if (!request.isValid()) {
      return CalculationResponse(
        success: false,
        errorMessage: 'Invalid operation: ${request.operation}',
      );
    }

    try {
      final result =
          _performCalculation(request.a, request.b, request.operation);
      return CalculationResponse(result: result);
    } catch (e) {
      return CalculationResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Stream<CalculationResponse> streamCalculate(
      Stream<CalculationRequest> requests) async* {
    // Обрабатываем каждый запрос в потоке
    await for (final request in requests) {
      // Имитация задержки обработки на сервере
      if (simulatedDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: simulatedDelayMs));
      }

      // Проверяем валидность операции
      if (!request.isValid()) {
        yield CalculationResponse(
          success: false,
          errorMessage: 'Invalid operation: ${request.operation}',
        );
        continue;
      }

      try {
        final result =
            _performCalculation(request.a, request.b, request.operation);
        yield CalculationResponse(result: result);
      } catch (e) {
        yield CalculationResponse(
          success: false,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// Внутренний метод для выполнения вычисления
  double _performCalculation(double a, double b, String operation) {
    switch (operation) {
      case 'add':
        return a + b;
      case 'subtract':
        return a - b;
      case 'multiply':
        return a * b;
      case 'divide':
        if (b == 0) {
          throw Exception('Division by zero');
        }
        return a / b;
      default:
        throw Exception('Unsupported operation: $operation');
    }
  }
}

/// Пример использования сервера
void exampleServerUsage() {
  // Создаем сервер
  final server = CalculatorServer(simulatedDelayMs: 100);

  // Регистрируем сервер в эндпоинте
  // final endpoint = RpcEndpoint(transport: someTransport);
  // endpoint.registerServiceContract(server);

  print('Сервер калькулятора запущен и готов принимать запросы');
}
