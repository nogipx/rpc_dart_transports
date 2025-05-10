import 'package:rpc_dart/rpc_dart.dart';

/// Класс для результата агрегации
class AggregationResult implements IRpcSerializableMessage {
  final int count;
  final int sum;
  final double average;
  final int min;
  final int max;

  AggregationResult({
    required this.count,
    required this.sum,
    required this.average,
    required this.min,
    required this.max,
  });

  @override
  Map<String, dynamic> toJson() => {
    'count': count,
    'sum': sum,
    'average': average,
    'min': min,
    'max': max,
  };

  static AggregationResult fromJson(Map<String, dynamic> json) {
    return AggregationResult(
      count: json['count'] as int? ?? 0,
      sum: json['sum'] as int? ?? 0,
      average: (json['average'] as num?)?.toDouble() ?? 0.0,
      min: json['min'] as int? ?? 0,
      max: json['max'] as int? ?? 0,
    );
  }
}

/// Сериализуемый класс для объекта Item
class SerializableItem implements IRpcSerializableMessage {
  final String name;
  final int value;
  final bool active;

  SerializableItem({required this.name, required this.value, required this.active});

  @override
  Map<String, dynamic> toJson() => {'name': name, 'value': value, 'active': active};

  static SerializableItem fromJson(Map<String, dynamic> json) {
    return SerializableItem(
      name: json['name'] as String? ?? '',
      value: json['value'] as int? ?? 0,
      active: json['active'] as bool? ?? false,
    );
  }
}

/// Класс с результатом обработки
class ProcessingSummary implements IRpcSerializableMessage {
  final int processedCount;
  final int totalValue;
  final List<String> names;
  final String timestamp;

  ProcessingSummary({
    required this.processedCount,
    required this.totalValue,
    required this.names,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
    'processedCount': processedCount,
    'totalValue': totalValue,
    'names': names,
    'timestamp': timestamp,
  };

  static ProcessingSummary fromJson(Map<String, dynamic> json) {
    return ProcessingSummary(
      processedCount: json['processedCount'] as int? ?? 0,
      totalValue: json['totalValue'] as int? ?? 0,
      names: (json['names'] as List<dynamic>?)?.whereType<String>().toList() ?? [],
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

/// Класс блока данных
class DataBlock implements IRpcSerializableMessage {
  final int index;
  final List<int> data;
  final String metadata;

  DataBlock({required this.index, required this.data, required this.metadata});

  @override
  Map<String, dynamic> toJson() => {'index': index, 'data': data, 'metadata': metadata};

  static DataBlock fromJson(Map<String, dynamic> json) {
    return DataBlock(
      index: json['index'] as int? ?? 0,
      data: (json['data'] as List<dynamic>).cast<int>(),
      metadata: json['metadata'] as String? ?? '',
    );
  }
}

/// Класс результата обработки блоков данных
class DataBlockResult implements IRpcSerializableMessage {
  final int blockCount;
  final int totalSize;
  final String metadata;
  final String processingTime;

  DataBlockResult({
    required this.blockCount,
    required this.totalSize,
    required this.metadata,
    required this.processingTime,
  });

  @override
  Map<String, dynamic> toJson() => {
    'blockCount': blockCount,
    'totalSize': totalSize,
    'metadata': metadata,
    'processingTime': processingTime,
  };

  static DataBlockResult fromJson(Map<String, dynamic> json) {
    return DataBlockResult(
      blockCount: json['blockCount'] as int,
      totalSize: json['totalSize'] as int,
      metadata: json['metadata'] as String,
      processingTime: json['processingTime'] as String,
    );
  }
}

/// Класс результата валидации
class ValidationResult implements IRpcSerializableMessage {
  final bool valid;
  final int processedCount;
  final List<String> errors;

  ValidationResult({required this.valid, required this.processedCount, required this.errors});

  @override
  Map<String, dynamic> toJson() => {
    'valid': valid,
    'processedCount': processedCount,
    'errors': errors,
  };

  static ValidationResult fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      valid: json['valid'] as bool,
      processedCount: json['processedCount'] as int,
      errors: (json['errors'] as List<dynamic>).cast<String>(),
    );
  }
}
