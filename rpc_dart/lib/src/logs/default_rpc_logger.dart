// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_logs.dart';

/// Реализация фильтра по умолчанию, основанная на минимальном уровне логирования
class DefaultRpcLoggerFilter implements IRpcLoggerFilter {
  final RpcLoggerLevel minLogLevel;

  DefaultRpcLoggerFilter(this.minLogLevel);

  @override
  bool shouldLog(RpcLoggerLevel level, String source) {
    return level.index >= minLogLevel.index;
  }
}

/// Реализация форматтера по умолчанию
class DefaultRpcLoggerFormatter implements IRpcLoggerFormatter {
  const DefaultRpcLoggerFormatter();

  @override
  String format(
      DateTime timestamp, RpcLoggerLevel level, String source, String message,
      {String? context}) {
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    String prefix;
    switch (level) {
      case RpcLoggerLevel.debug:
        prefix = 'DEBUG';
      case RpcLoggerLevel.info:
        prefix = 'INFO';
      case RpcLoggerLevel.warning:
        prefix = 'WARN';
      case RpcLoggerLevel.error:
        prefix = 'ERROR';
      case RpcLoggerLevel.critical:
        prefix = 'CRIT';
      default:
        prefix = '';
    }

    final contextStr = context != null ? ' ($context)' : '';
    return '[$formattedTime] ${prefix.padRight(5)} [$source$contextStr] $message';
  }
}

/// Консольная реализация логгера
class DefaultRpcLogger implements RpcLogger {
  @override
  final String name;

  @override
  IRpcDiagnosticClient? get diagnostic => RpcLoggerSettings.diagnostic;

  /// Флаг вывода логов в консоль
  final bool _consoleLoggingEnabled;

  /// Флаг использования цветов при выводе логов в консоль
  final bool _coloredLoggingEnabled;

  /// Настройки цветов для разных уровней логирования
  final RpcLoggerColors _logColors;

  /// Фильтр логов
  final IRpcLoggerFilter _filter;

  /// Форматтер логов
  final IRpcLoggerFormatter _formatter;

  /// Создает новый логгер с указанными параметрами
  DefaultRpcLogger(
    this.name, {
    RpcLoggerLevel? minLogLevel,
    bool consoleLoggingEnabled = true,
    bool coloredLoggingEnabled = true,
    RpcLoggerColors logColors = const RpcLoggerColors(),
    IRpcLoggerFilter? filter,
    IRpcLoggerFormatter? formatter,
  })  : _consoleLoggingEnabled = consoleLoggingEnabled,
        _coloredLoggingEnabled = coloredLoggingEnabled,
        _logColors = logColors,
        _formatter = formatter ?? const DefaultRpcLoggerFormatter(),
        _filter = filter ??
            DefaultRpcLoggerFilter(
              minLogLevel ?? RpcLoggerSettings.defaultMinLogLevel,
            );

  @override
  Future<void> log({
    required RpcLoggerLevel level,
    required String message,
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
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
    if (diagnostic != null) {
      await diagnostic!.log(
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
    required RpcLoggerLevel level,
    required String message,
    String? context,
    Object? error,
    StackTrace? stackTrace,
    AnsiColor? color,
  }) {
    final timestamp = DateTime.now();
    final logMessage =
        _formatter.format(timestamp, level, name, message, context: context);

    // Если включен цветной вывод, используем цвет
    if (_coloredLoggingEnabled) {
      final actualColor = color ?? _logColors.colorForLevel(level);
      _logColored(logMessage, actualColor);

      if (error != null) {
        _logColored('  Error details: $error', actualColor);
      }

      if (stackTrace != null) {
        _logColored('  Stack trace: \n$stackTrace', actualColor);
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

  @override
  Future<void> debug(
    String message, {
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.debug,
      message: message,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  @override
  Future<void> info(
    String message, {
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.info,
      message: message,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  @override
  Future<void> warning(
    String message, {
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.warning,
      message: message,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  @override
  Future<void> error(
    String message, {
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.error,
      message: message,
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
      color: color,
    );
  }

  @override
  Future<void> critical(
    String message, {
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.critical,
      message: message,
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
      color: color,
    );
  }

  /// Возвращает строку с применённым цветом
  ///
  /// Если цветное логирование выключено, возвращает исходную строку
  String _colorize(String message, AnsiColor color) {
    return '${color.code}$message${AnsiColor.reset.code}';
  }

  /// Выводит сообщение в консоль с указанным цветом
  void _logColored(String message, AnsiColor color) {
    final coloredMessage = _colorize(message, color);
    print(coloredMessage);
  }
}
