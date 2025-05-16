// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/diagnostics.dart';

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
class RpcLog {
  /// Диагностический сервис для отправки логов
  static IRpcDiagnosticService? _diagnosticService;

  /// Источник логов по умолчанию
  static String _defaultSource = 'RpcDart';

  /// Минимальный уровень логов для отправки
  static RpcLogLevel _minLogLevel = RpcLogLevel.info;

  /// Флаг вывода логов в консоль
  static bool _consoleLoggingEnabled = true;

  /// Устанавливает диагностический сервис для логирования
  static void setDiagnosticService(IRpcDiagnosticService service) {
    _diagnosticService = service;
    _minLogLevel = service.options.minLogLevel;
    _consoleLoggingEnabled = service.options.consoleLoggingEnabled;
  }

  /// Устанавливает источник логов по умолчанию
  static void setDefaultSource(String source) {
    _defaultSource = source;
  }

  /// Устанавливает минимальный уровень логов для консольного вывода
  static void setMinLogLevel(RpcLogLevel level) {
    _minLogLevel = level;
  }

  /// Включает/выключает вывод логов в консоль
  static void setConsoleLogging(bool enabled) {
    _consoleLoggingEnabled = enabled;
  }

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
  }) async {
    final actualSource = source ?? _defaultSource;

    // Проверяем минимальный уровень для консоли
    if (_consoleLoggingEnabled && level.index >= _minLogLevel.index) {
      _logToConsole(
        level: level,
        message: message,
        source: actualSource,
        context: context,
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Отправляем в диагностический сервис, если он установлен
    if (_diagnosticService != null) {
      await _diagnosticService!.log(
        level: level,
        message: message,
        source: actualSource,
        context: context,
        requestId: requestId,
        error: error,
        stackTrace: stackTrace,
        data: data,
      );
    }
  }

  /// Отображает лог в консоли
  static void _logToConsole({
    required RpcLogLevel level,
    required String message,
    required String source,
    String? context,
    Map<String, dynamic>? error,
    String? stackTrace,
  }) {
    final timestamp = DateTime.now();
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    String prefix;
    switch (level) {
      case RpcLogLevel.debug:
        prefix = '🔍 DEBUG';
      case RpcLogLevel.info:
        prefix = '📝 INFO ';
      case RpcLogLevel.warning:
        prefix = '⚠️ WARN ';
      case RpcLogLevel.error:
        prefix = '❌ ERROR';
      case RpcLogLevel.critical:
        prefix = '🔥 CRIT ';
      default:
        prefix = '     ';
    }

    final contextStr = context != null ? ' ($context)' : '';
    print('[$formattedTime] $prefix [$source$contextStr] $message');

    if (error != null) {
      print('  Error details: $error');
    }

    if (stackTrace != null) {
      print('  Stack trace: \n$stackTrace');
    }
  }

  /// Отправляет лог уровня debug
  static Future<void> debug({
    required String message,
    String? source,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
  }) async {
    await log(
      level: RpcLogLevel.debug,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      data: data,
    );
  }

  /// Отправляет лог уровня info
  static Future<void> info({
    required String message,
    String? source,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
  }) async {
    await log(
      level: RpcLogLevel.info,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      data: data,
    );
  }

  /// Отправляет лог уровня warning
  static Future<void> warning({
    required String message,
    String? source,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
  }) async {
    await log(
      level: RpcLogLevel.warning,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      data: data,
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
    );
  }
}
