part of '_logs.dart';

/// Глобальный логгер для доступа к функциям логирования из любой части библиотеки
///
/// Предоставляет упрощенный интерфейс для отправки сообщений разных уровней
/// в диагностический сервис.
///
/// Пример использования:
/// ```dart
/// import 'package:rpc_dart/diagnostics.dart';
///
/// void someFunction() {
///   RpcLog.debug(
///     message: 'Отладочное сообщение',
///     source: 'MyComponent',
///   );
/// }
/// ```
///
/// ПРИМЕЧАНИЕ: Этот класс сохранен для обратной совместимости.
/// Для новых проектов рекомендуется использовать [RpcLogManager] и [RpcLogger].
abstract interface class RpcLog {
  /// Имя логгера по умолчанию
  static const String _defaultLoggerName = 'RpcDart';

  /// Получает логгер по умолчанию
  static RpcLogger get _defaultLogger => RpcLogManager.get(_defaultLoggerName);

  /// Отправляет лог с указанным уровнем в сервис диагностики
  static Future<void> log({
    required RpcLogLevel level,
    required String message,
    String? source,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    if (source != null && source != _defaultLoggerName) {
      // Если указан другой источник, используем отдельный логгер для него
      final logger = RpcLogManager.get(source);
      await logger.log(
        level: level,
        message: message,
        context: context,
        requestId: requestId,
        error: error,
        stackTrace: stackTrace,
        data: data,
        color: color,
      );
    } else {
      // Иначе используем логгер по умолчанию
      await _defaultLogger.log(
        level: level,
        message: message,
        context: context,
        requestId: requestId,
        error: error,
        stackTrace: stackTrace,
        data: data,
        color: color,
      );
    }
  }

  /// Отправляет лог уровня debug
  static Future<void> debug({
    required String message,
    String? source,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLogLevel.debug,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  /// Отправляет лог уровня info
  static Future<void> info({
    required String message,
    String? source,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLogLevel.info,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  /// Отправляет лог уровня warning
  static Future<void> warning({
    required String message,
    String? source,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLogLevel.warning,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  /// Отправляет лог уровня error
  static Future<void> error({
    required String message,
    String? source,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLogLevel.error,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
      color: color,
    );
  }

  /// Отправляет лог уровня critical
  static Future<void> critical({
    required String message,
    String? source,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLogLevel.critical,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
      color: color,
    );
  }
}
