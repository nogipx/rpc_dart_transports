// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

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
    Stream<CalculationRequest> requests,
  );
}
