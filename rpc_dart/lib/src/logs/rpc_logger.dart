// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_logs.dart';

/// Уровни логирования
enum RpcLoggerLevel {
  debug,
  info,
  warning,
  error,
  critical,
  none;

  /// Создание из строки JSON
  static RpcLoggerLevel fromJson(String json) {
    return values.firstWhere(
      (e) => e.name == json,
      orElse: () => none,
    );
  }
}

typedef RpcLoggerFactory = RpcLogger Function(String loggerName);

/// Интерфейс для фильтрации логов
abstract interface class IRpcLoggerFilter {
  /// Проверяет, нужно ли логировать сообщение с указанным уровнем и источником
  bool shouldLog(RpcLoggerLevel level, String source);
}

/// Интерфейс для форматирования логов
abstract interface class IRpcLoggerFormatter {
  /// Форматирует сообщение лога
  String format(
      DateTime timestamp, RpcLoggerLevel level, String source, String message,
      {String? context});
}

/// {@template rpc_logger}
/// Логгер для RPC библиотеки
///
/// Позволяет создавать экземпляры логгеров с разными настройками
/// и независимо управлять логированием разных компонентов.
/// {@endtemplate}
///
abstract interface class RpcLogger {
  /// Имя логгера, обычно название компонента или модуля
  String get name;

  /// Создает новый логгер с измененными настройками
  RpcLogger withConfig({
    IRpcDiagnosticService? diagnosticService,
    RpcLoggerLevel? minLogLevel,
    bool? consoleLoggingEnabled,
    bool? coloredLoggingEnabled,
    RpcLoggerColors? logColors,
    IRpcLoggerFilter? filter,
    IRpcLoggerFormatter? formatter,
  });

  /// Отправляет лог с указанным уровнем в сервис диагностики
  Future<void> log({
    required RpcLoggerLevel level,
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  });

  /// Отправляет лог уровня debug
  Future<void> debug({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  });

  /// Отправляет лог уровня info
  Future<void> info({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  });

  /// Отправляет лог уровня warning
  Future<void> warning({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  });

  /// Отправляет лог уровня error
  Future<void> error({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  });

  /// Отправляет лог уровня critical
  Future<void> critical({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  });

  /// Статический фабричный метод для создания нового логгера
  static RpcLoggerFactory? _factory;

  /// Устанавливает фабрику для создания логгеров
  static set factory(RpcLoggerFactory newFactory) {
    _factory = newFactory;
  }

  /// Создает новый логгер с указанным именем
  factory RpcLogger(String loggerName) {
    if (_factory == null) {
      return DefaultRpcLogger(loggerName);
    }
    return _factory!(loggerName);
  }

  /// Получает логгер с указанным именем
  factory RpcLogger.get(String loggerName) {
    return RpcLogger(loggerName);
  }
}
