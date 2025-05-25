import '../contracts/_index.dart';
import 'dart:convert';

/// Запрос на вычисление
class CalculationRequest implements IRpcJsonSerializable, IRpcSerializable {
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

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static CalculationRequest fromJson(Map<String, dynamic> json) {
    return CalculationRequest(
      a: json['a'] is int ? (json['a'] as int).toDouble() : json['a'],
      b: json['b'] is int ? (json['b'] as int).toDouble() : json['b'],
      operation: json['operation'],
    );
  }
}

/// Ответ на вычисление
class CalculationResponse implements IRpcJsonSerializable, IRpcSerializable {
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

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static CalculationResponse fromJson(Map<String, dynamic> json) {
    return CalculationResponse(
      result: json['result'],
      success: json['success'] ?? true,
      errorMessage: json['errorMessage'],
    );
  }
}

/// Пример с бинарной сериализацией
class BinaryCalculationRequest extends CalculationRequest {
  BinaryCalculationRequest({
    required super.a,
    required super.b,
    required super.operation,
  });

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.binary;

  static BinaryCalculationRequest fromJson(Map<String, dynamic> json) {
    return BinaryCalculationRequest(
      a: json['a'] is int ? (json['a'] as int).toDouble() : json['a'],
      b: json['b'] is int ? (json['b'] as int).toDouble() : json['b'],
      operation: json['operation'],
    );
  }
}
