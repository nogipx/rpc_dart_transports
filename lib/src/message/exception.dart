/// Базовый класс для всех исключений RPC
class RpcException implements Exception {
  /// Код ошибки
  final String code;

  /// Сообщение об ошибке
  final String message;

  /// Дополнительные детали ошибки
  final Map<String, dynamic>? details;

  /// Создает новый экземпляр [RpcException]
  const RpcException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'RpcException[$code]: $message';

  /// Создает объект, представляющий исключение в JSON-формате
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'code': code,
      'message': message,
    };

    if (details != null) {
      result['details'] = details;
    }

    return result;
  }

  /// Создает [RpcException] из JSON-объекта
  factory RpcException.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    final message = json['message'] as String;
    final details = json['details'] as Map<String, dynamic>?;

    // Проверяем код и создаем соответствующий подкласс
    switch (code) {
      case 'INVALID_ARGUMENT':
        return RpcInvalidArgumentException(message, details);
      case 'NOT_FOUND':
        return RpcNotFoundException(message, details);
      case 'INTERNAL':
        return RpcInternalException(message, details);
      case 'TIMEOUT':
        return RpcTimeoutException(message, details);
      case 'UNSUPPORTED_OPERATION':
        final operation = json['operation'] as String? ?? message;
        final type =
            json['type'] as String? ?? details?['type'] as String? ?? 'Unknown';
        return RpcUnsupportedOperationException(
          operation: operation,
          type: type,
          details: details,
        );
      default:
        return RpcException(code: code, message: message, details: details);
    }
  }
}

/// Исключение, выбрасываемое при передаче неверных аргументов
class RpcInvalidArgumentException extends RpcException {
  /// Создает исключение о неверных аргументах
  const RpcInvalidArgumentException(String message,
      [Map<String, dynamic>? details])
      : super(
          code: 'INVALID_ARGUMENT',
          message: message,
          details: details,
        );
}

/// Исключение, выбрасываемое когда запрашиваемый ресурс не найден
class RpcNotFoundException extends RpcException {
  /// Создает исключение о том, что ресурс не найден
  const RpcNotFoundException(String message, [Map<String, dynamic>? details])
      : super(
          code: 'NOT_FOUND',
          message: message,
          details: details,
        );
}

/// Исключение, выбрасываемое при внутренней ошибке системы
class RpcInternalException extends RpcException {
  /// Создает исключение о внутренней ошибке
  const RpcInternalException(String message, [Map<String, dynamic>? details])
      : super(
          code: 'INTERNAL',
          message: message,
          details: details,
        );
}

/// Исключение, выбрасываемое при превышении времени ожидания
class RpcTimeoutException extends RpcException {
  /// Создает исключение о превышении времени ожидания
  const RpcTimeoutException(String message, [Map<String, dynamic>? details])
      : super(
          code: 'TIMEOUT',
          message: message,
          details: details,
        );
}

/// Исключение, выбрасываемое, когда операция не поддерживается
class RpcUnsupportedOperationException extends RpcException {
  /// Название операции
  final String operation;

  /// Тип объекта, к которому применялась операция
  final String type;

  /// Создает исключение о неподдерживаемой операции
  const RpcUnsupportedOperationException({
    required this.operation,
    required this.type,
    Map<String, dynamic>? details,
  }) : super(
          code: 'UNSUPPORTED_OPERATION',
          message: 'Operation "$operation" is not supported for type "$type"',
          details: details,
        );
}
