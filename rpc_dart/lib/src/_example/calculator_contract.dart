import 'package:rpc_dart/rpc_dart.dart';

/// Запрос на вычисление
class CalculationRequest implements IRpcSerializable {
  final double a;
  final double b;
  final String operation;

  CalculationRequest({
    required this.a,
    required this.b,
    required this.operation,
  });

  /// Валидация операции
  bool isValid() {
    return ['add', 'subtract', 'multiply', 'divide'].contains(operation);
  }

  @override
  Map<String, dynamic> toJson() => {
        'a': a,
        'b': b,
        'operation': operation,
      };

  static CalculationRequest fromJson(Map<String, dynamic> json) {
    return CalculationRequest(
      a: json['a'] is int ? (json['a'] as int).toDouble() : json['a'],
      b: json['b'] is int ? (json['b'] as int).toDouble() : json['b'],
      operation: json['operation'],
    );
  }

  static RpcCodec<CalculationRequest> get codec =>
      RpcCodec(CalculationRequest.fromJson);
}

/// Ответ на вычисление
class CalculationResponse implements IRpcSerializable {
  final double? result;
  final bool success;
  final String? errorMessage;

  CalculationResponse({
    this.result,
    this.success = true,
    this.errorMessage,
  });

  @override
  Map<String, dynamic> toJson() => {
        'result': result,
        'success': success,
        'errorMessage': errorMessage,
      };

  static CalculationResponse fromJson(Map<String, dynamic> json) {
    return CalculationResponse(
      result: json['result'],
      success: json['success'] ?? true,
      errorMessage: json['errorMessage'],
    );
  }

  static RpcCodec<CalculationResponse> get codec =>
      RpcCodec(CalculationResponse.fromJson);
}
