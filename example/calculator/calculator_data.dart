import 'package:rpc_dart/rpc_dart.dart';

/// Пример класса запроса для калькулятора
class CalculatorRequest implements RpcSerializableMessage {
  final int a;
  final int b;

  CalculatorRequest(this.a, this.b);

  @override
  Map<String, dynamic> toJson() => {'a': a, 'b': b};

  static CalculatorRequest fromJson(Map<String, dynamic> json) {
    return CalculatorRequest(
      json['a'] as int,
      json['b'] as int,
    );
  }

  @override
  String toString() => 'CalculatorRequest(a: $a, b: $b)';
}

/// Пример класса ответа для калькулятора
class CalculatorResponse implements RpcSerializableMessage {
  final int result;

  CalculatorResponse(this.result);

  @override
  Map<String, dynamic> toJson() => {'result': result};

  static CalculatorResponse fromJson(Map<String, dynamic> json) {
    return CalculatorResponse(json['result'] as int);
  }

  @override
  String toString() => 'CalculatorResponse(result: $result)';
}

/// Пример запроса для генерации последовательности
class SequenceRequest implements RpcSerializableMessage {
  final int count;

  SequenceRequest(this.count);

  @override
  Map<String, dynamic> toJson() => {'count': count};

  static SequenceRequest fromJson(Map<String, dynamic> json) {
    return SequenceRequest(json['count'] as int);
  }

  @override
  String toString() => 'SequenceRequest(count: $count)';
}

/// Пример запроса для генерации последовательности
class SequenceData implements RpcSerializableMessage {
  final int count;

  SequenceData(this.count);

  @override
  Map<String, dynamic> toJson() => {'count': count};

  static SequenceData fromJson(Map<String, dynamic> json) {
    return SequenceData(json['count'] as int);
  }

  @override
  String toString() => 'SequenceData(count: $count)';
}
