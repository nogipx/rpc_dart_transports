import 'dart:async';
import '../contracts/_index.dart';
import 'calculator_contract.dart';

/// Общий интерфейс для контракта калькулятора
/// Определяет методы, которые должны быть реализованы
/// как на сервере, так и на клиенте
abstract interface class ICalculatorContract implements IRpcContract {
  // Имена методов
  static const methodCalculate = 'calculate';
  static const methodStreamCalculate = 'streamCalculate';

  /// Выполняет одиночную операцию
  Future<CalculationResponse> calculate(CalculationRequest request);

  /// Обрабатывает поток вычислений
  Stream<CalculationResponse> streamCalculate(
      Stream<CalculationRequest> requests);
}
