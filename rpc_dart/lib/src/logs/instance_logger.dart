// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_logs.dart';

/// Интерфейс для фильтрации логов
abstract class LogFilter {
  /// Проверяет, нужно ли логировать сообщение с указанным уровнем и источником
  bool shouldLog(RpcLogLevel level, String source);
}

/// Реализация фильтра по умолчанию, основанная на минимальном уровне логирования
class DefaultLogFilter implements LogFilter {
  final RpcLogLevel minLogLevel;

  DefaultLogFilter(this.minLogLevel);

  @override
  bool shouldLog(RpcLogLevel level, String source) {
    return level.index >= minLogLevel.index;
  }
}

/// Интерфейс для форматирования логов
abstract class LogFormatter {
  /// Форматирует сообщение лога
  String format(
      DateTime timestamp, RpcLogLevel level, String source, String message,
      {String? context});
}

/// Реализация форматтера по умолчанию
class DefaultLogFormatter implements LogFormatter {
  const DefaultLogFormatter();

  @override
  String format(
      DateTime timestamp, RpcLogLevel level, String source, String message,
      {String? context}) {
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
    return '[$formattedTime] $prefix [$source$contextStr] $message';
  }
}

/// Инстанцируемый логгер для библиотеки RpcDart
///
/// Позволяет создавать отдельные логгеры для разных компонентов
/// с независимыми настройками.
///
/// Пример использования:
/// ```dart
/// final logger = RpcLogger(name: 'MyComponent');
/// logger.info(message: 'Компонент инициализирован');
/// ```
class RpcLogger {
  /// Имя логгера, обычно название компонента или модуля
  final String name;

  /// Диагностический сервис для отправки логов
  IRpcDiagnosticService? _diagnosticService;

  /// Минимальный уровень логов для отправки
  RpcLogLevel _minLogLevel;

  /// Флаг вывода логов в консоль
  bool _consoleLoggingEnabled;

  /// Флаг использования цветов при выводе логов в консоль
  bool _coloredLoggingEnabled;

  /// Настройки цветов для разных уровней логирования
  RpcLogColors _logColors;

  /// Фильтр логов
  LogFilter _filter;

  /// Форматтер логов
  LogFormatter _formatter;

  /// Создает новый логгер с указанными параметрами
  RpcLogger({
    required this.name,
    IRpcDiagnosticService? diagnosticService,
    RpcLogLevel minLogLevel = RpcLogLevel.info,
    bool consoleLoggingEnabled = true,
    bool coloredLoggingEnabled = true,
    RpcLogColors logColors = const RpcLogColors(),
    LogFilter? filter,
    LogFormatter? formatter,
  })  : _diagnosticService = diagnosticService,
        _minLogLevel = minLogLevel,
        _consoleLoggingEnabled = consoleLoggingEnabled,
        _coloredLoggingEnabled = coloredLoggingEnabled,
        _logColors = logColors,
        _filter = filter ?? DefaultLogFilter(minLogLevel),
        _formatter = formatter ?? const DefaultLogFormatter();

  /// Устанавливает диагностический сервис для логирования
  void setDiagnosticService(IRpcDiagnosticService service) {
    _diagnosticService = service;
  }

  /// Устанавливает минимальный уровень логов
  void setMinLogLevel(RpcLogLevel level) {
    _minLogLevel = level;
    if (_filter is DefaultLogFilter) {
      _filter = DefaultLogFilter(level);
    }
  }

  /// Включает/выключает вывод логов в консоль
  void setConsoleLogging(bool enabled) {
    _consoleLoggingEnabled = enabled;
  }

  /// Включает/выключает цветной вывод логов в консоль
  void setColoredLogging(bool enabled) {
    _coloredLoggingEnabled = enabled;
  }

  /// Настраивает цвета для разных уровней логирования
  void setLogColors(RpcLogColors colors) {
    _logColors = colors;
  }

  /// Устанавливает фильтр логов
  void setFilter(LogFilter filter) {
    _filter = filter;
  }

  /// Устанавливает форматтер логов
  void setFormatter(LogFormatter formatter) {
    _formatter = formatter;
  }

  /// Отправляет лог с указанным уровнем в сервис диагностики
  Future<void> log({
    required RpcLogLevel level,
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    // Проверяем, нужно ли логировать это сообщение
    if (!_filter.shouldLog(level, name)) {
      return;
    }

    // Выводим в консоль, если включено
    if (_consoleLoggingEnabled) {
      _logToConsole(
        level: level,
        message: message,
        context: context,
        error: error,
        stackTrace: stackTrace,
        color: color,
      );
    }

    // Отправляем в диагностический сервис, если он установлен
    if (_diagnosticService != null) {
      await _diagnosticService!.log(
        level: level,
        message: message,
        source: name,
        context: context,
        requestId: requestId,
        error: error,
        stackTrace: stackTrace,
        data: data,
      );
    }
  }

  /// Отображает лог в консоли
  void _logToConsole({
    required RpcLogLevel level,
    required String message,
    String? context,
    Map<String, dynamic>? error,
    String? stackTrace,
    AnsiColor? color,
  }) {
    final timestamp = DateTime.now();
    final logMessage =
        _formatter.format(timestamp, level, name, message, context: context);

    // Если включен цветной вывод, используем цвет
    if (_coloredLoggingEnabled) {
      final actualColor = color ?? _logColors.colorForLevel(level);
      RpcColoredLogging.logColored(
        logMessage,
        actualColor,
        isError: level.index >= RpcLogLevel.error.index,
      );

      if (error != null) {
        RpcColoredLogging.logColored(
          '  Error details: $error',
          actualColor,
          isError: true,
        );
      }

      if (stackTrace != null) {
        RpcColoredLogging.logColored(
          '  Stack trace: \n$stackTrace',
          actualColor,
          isError: true,
        );
      }
    } else {
      // Обычный вывод без цвета
      print(logMessage);

      if (error != null) {
        print('  Error details: $error');
      }

      if (stackTrace != null) {
        print('  Stack trace: \n$stackTrace');
      }
    }
  }

  /// Отправляет лог уровня debug
  Future<void> debug({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLogLevel.debug,
      message: message,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  /// Отправляет лог уровня info
  Future<void> info({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLogLevel.info,
      message: message,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  /// Отправляет лог уровня warning
  Future<void> warning({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLogLevel.warning,
      message: message,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  /// Отправляет лог уровня error
  Future<void> error({
    required String message,
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
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
      color: color,
    );
  }

  /// Отправляет лог уровня critical
  Future<void> critical({
    required String message,
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
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
      color: color,
    );
  }
}
