import 'package:rpc_dart/rpc_dart.dart';

import 'unary_models.dart';

/// Базовый контракт для базовых операций
abstract base class BasicServiceContract extends RpcServiceContract {
  @override
  String get serviceName => 'BasicService';

  @override
  void setup() {
    // Метод работы с примитивными числовыми значениями
    addUnaryMethod<ComputeRequest, ComputeResult>(
      methodName: 'compute',
      handler: compute,
      argumentParser: ComputeRequest.fromJson,
      responseParser: ComputeResult.fromJson,
    );

    // Метод работы со строками
    addUnaryMethod<TextTransformRequest, TextTransformResult>(
      methodName: 'transformText',
      handler: transformText,
      argumentParser: TextTransformRequest.fromJson,
      responseParser: TextTransformResult.fromJson,
    );

    // Метод с возможностью ошибки
    addUnaryMethod<DivideRequest, DivideResult>(
      methodName: 'divide',
      handler: divide,
      argumentParser: DivideRequest.fromJson,
      responseParser: DivideResult.fromJson,
    );
  }

  // Абстрактные методы, которые должны быть реализованы
  Future<ComputeResult> compute(ComputeRequest request);
  Future<TextTransformResult> transformText(TextTransformRequest request);
  Future<DivideResult> divide(DivideRequest request);
}

/// Базовый контракт для типизированных операций
abstract base class TypedServiceContract extends RpcServiceContract {
  @override
  String get serviceName => 'TypedService';

  @override
  void setup() {
    // Метод с пользовательскими типами данных
    addUnaryMethod<DataRequest, DataResponse>(
      methodName: 'processData',
      handler: processData,
      argumentParser: DataRequest.fromJson,
      responseParser: DataResponse.fromJson,
    );
  }

  // Абстрактный метод, который должен быть реализован
  Future<DataResponse> processData(DataRequest request);
}

/// Серверная реализация BasicServiceContract
final class ServerBasicServiceContract extends BasicServiceContract {
  @override
  Future<ComputeResult> compute(ComputeRequest request) async {
    final value1 = request.value1;
    final value2 = request.value2;

    return ComputeResult(
      sum: value1 + value2,
      difference: value1 - value2,
      product: value1 * value2,
      quotient: value2 != 0 ? value1 / value2 : null,
    );
  }

  @override
  Future<TextTransformResult> transformText(TextTransformRequest request) async {
    final text = request.text;
    final operation = request.operation;

    String result;
    switch (operation) {
      case 'uppercase':
        result = text.toUpperCase();
        break;
      case 'lowercase':
        result = text.toLowerCase();
        break;
      case 'reverse':
        result = text.split('').reversed.join();
        break;
      default:
        result = text;
    }

    return TextTransformResult(result: result, length: result.length);
  }

  @override
  Future<DivideResult> divide(DivideRequest request) async {
    final numerator = request.numerator;
    final denominator = request.denominator;

    if (denominator == 0) {
      throw Exception('Деление на ноль недопустимо');
    }

    return DivideResult(result: numerator / denominator);
  }
}

/// Серверная реализация TypedServiceContract
final class ServerTypedServiceContract extends TypedServiceContract {
  @override
  Future<DataResponse> processData(DataRequest request) async {
    return DataResponse(
      processedValue: request.value * 2,
      isSuccess: true,
      timestamp: DateTime.now().toIso8601String(),
    );
  }
}

/// Клиентская реализация BasicServiceContract
final class ClientBasicServiceContract extends BasicServiceContract {
  final RpcEndpoint _endpoint;

  ClientBasicServiceContract(this._endpoint);

  @override
  Future<ComputeResult> compute(ComputeRequest request) async {
    return _endpoint
        .unary(serviceName, 'compute')
        .call<ComputeRequest, ComputeResult>(
          request: request,
          responseParser: ComputeResult.fromJson,
        );
  }

  @override
  Future<TextTransformResult> transformText(TextTransformRequest request) async {
    return _endpoint
        .unary(serviceName, 'transformText')
        .call<TextTransformRequest, TextTransformResult>(
          request: request,
          responseParser: TextTransformResult.fromJson,
        );
  }

  @override
  Future<DivideResult> divide(DivideRequest request) async {
    return _endpoint
        .unary(serviceName, 'divide')
        .call<DivideRequest, DivideResult>(request: request, responseParser: DivideResult.fromJson);
  }
}

/// Клиентская реализация TypedServiceContract
final class ClientTypedServiceContract extends TypedServiceContract {
  final RpcEndpoint _endpoint;

  ClientTypedServiceContract(this._endpoint);

  @override
  Future<DataResponse> processData(DataRequest request) async {
    return _endpoint
        .unary(serviceName, 'processData')
        .call<DataRequest, DataResponse>(request: request, responseParser: DataResponse.fromJson);
  }
}
