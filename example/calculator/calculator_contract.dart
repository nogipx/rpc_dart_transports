import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import '_index.dart';

/// Декларативный контракт сервиса калькулятора
///
/// Обратите внимание, как методы объявлены в контракте с полными сигнатурами,
/// но без реализации
abstract base class CalculatorContract extends DeclarativeRpcServiceContract {
  RpcEndpoint? get endpoint;

  @override
  final String serviceName = 'CalculatorService';

  /// Регистрация методов на основе их сигнатур
  @override
  void registerMethodsFromClass() {
    addUnaryMethod<CalculatorRequest, CalculatorResponse>(
      methodName: 'add',
      handler: add,
      argumentParser: CalculatorRequest.fromJson,
      responseParser: CalculatorResponse.fromJson,
    );

    addUnaryMethod<CalculatorRequest, CalculatorResponse>(
      methodName: 'multiply',
      handler: multiply,
      argumentParser: CalculatorRequest.fromJson,
      responseParser: CalculatorResponse.fromJson,
    );

    addServerStreamingMethod<SequenceRequest, SequenceData>(
      methodName: 'generateSequence',
      handler: generateSequence,
      argumentParser: SequenceRequest.fromJson,
      responseParser: SequenceData.fromJson,
    );
  }

  Future<CalculatorResponse> add(CalculatorRequest request);

  Future<CalculatorResponse> multiply(CalculatorRequest request);

  Stream<SequenceData> generateSequence(SequenceRequest request);
}
