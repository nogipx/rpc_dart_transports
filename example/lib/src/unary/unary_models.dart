import 'package:rpc_dart/rpc_dart.dart';

/// Класс запроса с данными
class DataRequest implements IRpcSerializableMessage {
  final int value;
  final String label;

  DataRequest({required this.value, required this.label});

  @override
  Map<String, dynamic> toJson() => {'value': value, 'label': label};

  static DataRequest fromJson(Map<String, dynamic> json) {
    return DataRequest(value: json['value'] as int, label: json['label'] as String);
  }
}

/// Класс ответа с данными
class DataResponse implements IRpcSerializableMessage {
  final int processedValue;
  final bool isSuccess;
  final String timestamp;

  DataResponse({required this.processedValue, required this.isSuccess, required this.timestamp});

  @override
  Map<String, dynamic> toJson() => {
    'processedValue': processedValue,
    'isSuccess': isSuccess,
    'timestamp': timestamp,
  };

  static DataResponse fromJson(Map<String, dynamic> json) {
    return DataResponse(
      processedValue: json['processedValue'] as int,
      isSuccess: json['isSuccess'] as bool,
      timestamp: json['timestamp'] as String,
    );
  }
}

/// Запрос для метода compute
class ComputeRequest implements IRpcSerializableMessage {
  final int value1;
  final int value2;

  ComputeRequest({required this.value1, required this.value2});

  @override
  Map<String, dynamic> toJson() => {'value1': value1, 'value2': value2};

  static ComputeRequest fromJson(Map<String, dynamic> json) {
    return ComputeRequest(value1: json['value1'] as int? ?? 0, value2: json['value2'] as int? ?? 0);
  }
}

/// Результат метода compute
class ComputeResult implements IRpcSerializableMessage {
  final int sum;
  final int difference;
  final int product;
  final double? quotient;

  ComputeResult({
    required this.sum,
    required this.difference,
    required this.product,
    this.quotient,
  });

  @override
  Map<String, dynamic> toJson() => {
    'sum': sum,
    'difference': difference,
    'product': product,
    if (quotient != null) 'quotient': quotient,
  };

  static ComputeResult fromJson(Map<String, dynamic> json) {
    return ComputeResult(
      sum: json['sum'] as int? ?? 0,
      difference: json['difference'] as int? ?? 0,
      product: json['product'] as int? ?? 0,
      quotient: json['quotient'] != null ? (json['quotient'] as num).toDouble() : null,
    );
  }
}

/// Запрос для метода transformText
class TextTransformRequest implements IRpcSerializableMessage {
  final String text;
  final String operation;

  TextTransformRequest({required this.text, required this.operation});

  @override
  Map<String, dynamic> toJson() => {'text': text, 'operation': operation};

  static TextTransformRequest fromJson(Map<String, dynamic> json) {
    return TextTransformRequest(
      text: json['text'] as String? ?? '',
      operation: json['operation'] as String? ?? '',
    );
  }
}

/// Результат метода transformText
class TextTransformResult implements IRpcSerializableMessage {
  final String result;
  final int length;

  TextTransformResult({required this.result, required this.length});

  @override
  Map<String, dynamic> toJson() => {'result': result, 'length': length};

  static TextTransformResult fromJson(Map<String, dynamic> json) {
    return TextTransformResult(
      result: json['result'] as String? ?? '',
      length: json['length'] as int? ?? 0,
    );
  }
}

/// Запрос для метода divide
class DivideRequest implements IRpcSerializableMessage {
  final int numerator;
  final int denominator;

  DivideRequest({required this.numerator, required this.denominator});

  @override
  Map<String, dynamic> toJson() => {'numerator': numerator, 'denominator': denominator};

  static DivideRequest fromJson(Map<String, dynamic> json) {
    return DivideRequest(
      numerator: json['numerator'] as int? ?? 0,
      denominator: json['denominator'] as int? ?? 1,
    );
  }
}

/// Результат метода divide
class DivideResult implements IRpcSerializableMessage {
  final double result;

  DivideResult({required this.result});

  @override
  Map<String, dynamic> toJson() => {'result': result};

  static DivideResult fromJson(Map<String, dynamic> json) {
    return DivideResult(result: (json['result'] as num?)?.toDouble() ?? 0.0);
  }
}
