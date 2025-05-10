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
  }

  /// Абстрактный метод вычислений
  Future<ComputeResult> compute(ComputeRequest request);
}

/// Серверная реализация контракта базового сервиса
final class ServerBasicServiceContract extends BasicServiceContract {
  @override
  Future<ComputeResult> compute(ComputeRequest request) async {
    final value1 = request.value1;
    final value2 = request.value2;

    // Выполняем вычисления
    final sum = value1 + value2;
    final difference = value1 - value2;
    final product = value1 * value2;
    final quotient = value1 / value2;

    // Возвращаем результат
    return ComputeResult(sum: sum, difference: difference, product: product, quotient: quotient);
  }
}

/// Клиентская реализация контракта базового сервиса
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
}
