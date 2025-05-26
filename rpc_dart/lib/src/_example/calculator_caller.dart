// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import 'calculator_contract.dart';
import 'calculator_interface.dart';

/// Клиентская реализация калькулятора
class CalculatorCaller extends RpcCallerContract
    implements ICalculatorContract {
  /// Создает клиента с указанным эндпоинтом
  CalculatorCaller(RpcCallerEndpoint endpoint)
      : super('CalculatorService', endpoint);

  @override
  Future<CalculationResponse> calculate(CalculationRequest request) {
    return endpoint.unaryRequest<CalculationRequest, CalculationResponse>(
      serviceName: serviceName,
      methodName: ICalculatorContract.methodCalculate,
      requestCodec: CalculationRequest.codec,
      responseCodec: CalculationResponse.codec,
      request: request,
    );
  }

  @override
  Stream<CalculationResponse> streamCalculate(
      Stream<CalculationRequest> requests) {
    return endpoint
        .bidirectionalStream<CalculationRequest, CalculationResponse>(
      serviceName: serviceName,
      methodName: ICalculatorContract.methodStreamCalculate,
      requestCodec: CalculationRequest.codec,
      responseCodec: CalculationResponse.codec,
      requests: requests,
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
}
