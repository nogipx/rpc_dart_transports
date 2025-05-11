// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

enum RpcExceptionCode {
  invalidArgument,
  notFound,
  internal,
  timeout,
  unsupportedOperation,
  custom,
  unknown;

  static RpcExceptionCode fromString(String value) {
    for (final code in RpcExceptionCode.values) {
      if (code.name == value) {
        return code;
      }
    }
    return unknown;
  }
}

/// Базовый класс для всех исключений RPC
class RpcException implements Exception {
  /// Код ошибки
  final RpcExceptionCode code;

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
    final code = RpcExceptionCode.fromString(json['code'] as String? ?? '');
    final message = json['message'] as String;
    final details = json['details'] as Map<String, dynamic>?;

    // Проверяем код и создаем соответствующий подкласс
    switch (code) {
      case RpcExceptionCode.invalidArgument:
        return RpcInvalidArgumentException(message, details: details);
      case RpcExceptionCode.notFound:
        return RpcNotFoundException(message, details: details);
      case RpcExceptionCode.internal:
        return RpcInternalException(message, details: details);
      case RpcExceptionCode.timeout:
        return RpcTimeoutException(message, details: details);
      case RpcExceptionCode.custom:
        return RpcCustomException(
          customMessage: json['customMessage'] as String? ??
              details?['customMessage'] as String? ??
              '',
          debugLabel: json['debugLabel'] as String? ??
              details?['debugLabel'] as String? ??
              '',
          error: json['error'] as Object?,
          stackTrace:
              StackTrace.fromString(json['stackTrace'] as String? ?? ''),
          details: details,
        );
      case RpcExceptionCode.unsupportedOperation:
        final operation = json['operation'] as String? ?? message;
        final type =
            json['type'] as String? ?? details?['type'] as String? ?? 'Unknown';
        return RpcUnsupportedOperationException(
          operation: operation,
          type: type,
          details: details,
        );
      default:
        return RpcException(
          code: code,
          message: message,
          details: details,
        );
    }
  }
}

/// Исключение, выбрасываемое при передаче неверных аргументов
class RpcInvalidArgumentException extends RpcException {
  /// Создает исключение о неверных аргументах
  const RpcInvalidArgumentException(String message,
      {Map<String, dynamic>? details})
      : super(
          code: RpcExceptionCode.invalidArgument,
          message: message,
          details: details,
        );
}

/// Исключение, выбрасываемое когда запрашиваемый ресурс не найден
class RpcNotFoundException extends RpcException {
  /// Создает исключение о том, что ресурс не найден
  const RpcNotFoundException(String message, {Map<String, dynamic>? details})
      : super(
          code: RpcExceptionCode.notFound,
          message: message,
          details: details,
        );
}

/// Исключение, выбрасываемое при внутренней ошибке системы
class RpcInternalException extends RpcException {
  /// Создает исключение о внутренней ошибке
  const RpcInternalException(String message, {Map<String, dynamic>? details})
      : super(
          code: RpcExceptionCode.internal,
          message: message,
          details: details,
        );
}

/// Исключение, выбрасываемое при превышении времени ожидания
class RpcTimeoutException extends RpcException {
  /// Создает исключение о превышении времени ожидания
  const RpcTimeoutException(String message, {Map<String, dynamic>? details})
      : super(
          code: RpcExceptionCode.timeout,
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
          code: RpcExceptionCode.unsupportedOperation,
          message: 'Operation "$operation" is not supported for type "$type"',
          details: details,
        );
}

/// Исключение, связанное с критическими ошибками
class RpcCustomException extends RpcException {
  /// Метка для отладки
  final String? debugLabel;

  /// Ошибка, которая возникла при критической ошибке
  final Object? error;

  /// Стек-трейс, который возник при критической ошибке
  final StackTrace? stackTrace;

  /// Сообщение, которое будет отображено в исключении
  final String customMessage;

  /// Создает исключение о критической ошибке
  RpcCustomException({
    required this.customMessage,
    this.debugLabel,
    this.error,
    this.stackTrace,
    Map<String, dynamic>? details,
  }) : super(
          code: RpcExceptionCode.custom,
          message: () {
            var result = '';
            if (debugLabel != null) {
              result += '($debugLabel) ';
            }
            result += 'Custom exception. $customMessage \n';
            if (error != null) {
              result += 'Error: $error \n';
            }
            if (stackTrace != null) {
              result += 'StackTrace: $stackTrace';
            }
            return result;
          }(),
          details: {
            'customMessage': customMessage,
            'debugLabel': debugLabel,
            'error': error,
            'stackTrace': stackTrace?.toString(),
          },
        );
}
