part of '_metric.dart';

/// Типы ошибок, которые могут быть отслежены
enum RpcErrorMetricType {
  networkError,
  timeoutError,
  serializationError,
  contractError,
  unexpectedError,
  unknown;

  static RpcErrorMetricType fromJson(String json) {
    return values.firstWhere(
      (e) => e.name == json,
      orElse: () => unknown,
    );
  }
}

/// Метрика для отслеживания ошибок в работе RPC
class RpcErrorMetric implements IRpcSerializableMessage {
  /// Тип ошибки
  final RpcErrorMetricType errorType;

  /// Сообщение об ошибке
  final String message;

  /// Код ошибки (если доступен)
  final int? code;

  /// Идентификатор запроса, при котором произошла ошибка
  final String? requestId;

  /// Стэк-трейс ошибки (если доступен)
  final String? stackTrace;

  /// Методы, при вызове которых произошла ошибка
  final String? method;

  /// Дополнительные данные об ошибке
  final Map<String, dynamic>? details;

  const RpcErrorMetric({
    required this.errorType,
    required this.message,
    this.code,
    this.requestId,
    this.stackTrace,
    this.method,
    this.details,
  });

  /// Преобразование в JSON
  @override
  Map<String, dynamic> toJson() => {
        'error_type': errorType.name,
        'message': message,
        if (code != null) 'code': code,
        if (requestId != null) 'request_id': requestId,
        if (stackTrace != null) 'stack_trace': stackTrace,
        if (method != null) 'method': method,
        if (details != null) 'details': details,
      };

  /// Создание из JSON
  factory RpcErrorMetric.fromJson(Map<String, dynamic> json) {
    final errorTypeString = json['error_type'] as String;
    final errorType = RpcErrorMetricType.fromJson(errorTypeString);

    return RpcErrorMetric(
      errorType: errorType,
      message: json['message'] as String,
      code: json['code'] as int?,
      requestId: json['request_id'] as String?,
      stackTrace: json['stack_trace'] as String?,
      method: json['method'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}
