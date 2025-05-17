// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_logs.dart';

/// ANSI цвета для вывода в консоль
///
/// Предоставляет константы для цветного форматирования текста в консоли
/// с использованием ANSI escape-последовательностей.
///
/// Пример использования:
/// ```dart
/// print('${AnsiColor.green.code}Текст зеленого цвета${AnsiColor.reset.code}');
/// ```
enum AnsiColor {
  reset('\x1B[0m'),
  black('\x1B[30m'),
  red('\x1B[31m'),
  green('\x1B[32m'),
  yellow('\x1B[33m'),
  blue('\x1B[34m'),
  magenta('\x1B[35m'),
  cyan('\x1B[36m'),
  white('\x1B[37m'),
  brightBlack('\x1B[90m'),
  brightRed('\x1B[91m'),
  brightGreen('\x1B[92m'),
  brightYellow('\x1B[93m'),
  brightBlue('\x1B[94m'),
  brightMagenta('\x1B[95m'),
  brightCyan('\x1B[96m'),
  brightWhite('\x1B[97m');

  final String code;
  const AnsiColor(this.code);
}

/// Настройки цветов для разных уровней логирования
class RpcLoggerColors {
  /// Цвет для логов уровня debug
  final AnsiColor debug;

  /// Цвет для логов уровня info
  final AnsiColor info;

  /// Цвет для логов уровня warning
  final AnsiColor warning;

  /// Цвет для логов уровня error
  final AnsiColor error;

  /// Цвет для логов уровня critical
  final AnsiColor critical;

  /// Создаёт настройки цветов с указанными значениями
  const RpcLoggerColors({
    this.debug = AnsiColor.cyan,
    this.info = AnsiColor.green,
    this.warning = AnsiColor.yellow,
    this.error = AnsiColor.red,
    this.critical = AnsiColor.brightRed,
  });

  /// Цвета по умолчанию
  static const defaultColors = RpcLoggerColors();

  /// Получает цвет для указанного уровня логирования
  AnsiColor colorForLevel(RpcLoggerLevel level) {
    switch (level) {
      case RpcLoggerLevel.debug:
        return debug;
      case RpcLoggerLevel.info:
        return info;
      case RpcLoggerLevel.warning:
        return warning;
      case RpcLoggerLevel.error:
        return error;
      case RpcLoggerLevel.critical:
        return critical;
      default:
        return AnsiColor.white;
    }
  }
}

/// Утилиты для цветного логирования
class RpcColoredLogging {
  /// Настройки цветов для логирования
  static RpcLoggerColors logColors = RpcLoggerColors.defaultColors;

  /// Флаг, указывающий, включено ли цветное логирование
  static bool enabled = true;

  /// Устанавливает новые настройки цветов
  static void setLogColors(RpcLoggerColors colors) {
    logColors = colors;
  }

  /// Включает или выключает цветное логирование
  static void setEnabled(bool isEnabled) {
    enabled = isEnabled;
  }

  /// Настраивает поддержку ANSI цветов для текущей платформы
  ///
  /// На Windows нужно специально включить поддержку ANSI цветов
  static void setupConsoleStyling() {
    // На Windows нужно включить ANSI цвета через команду cmd
    if (Platform.isWindows) {
      try {
        Process.runSync('cmd', ['/c', 'color']);
      } catch (_) {}
    }
  }

  /// Возвращает строку с применённым цветом
  ///
  /// Если цветное логирование выключено, возвращает исходную строку
  static String colorize(String message, AnsiColor color) {
    if (!enabled) return message;
    return '${color.code}$message${AnsiColor.reset.code}';
  }

  /// Выводит сообщение в консоль с указанным цветом
  ///
  /// Если [isError] == true, выводит в stderr, иначе в stdout
  static void logColored(
    String message,
    AnsiColor color, {
    bool isError = false,
  }) {
    final coloredMessage = colorize(message, color);
    isError ? stderr.writeln(coloredMessage) : print(coloredMessage);
  }

  /// Выводит сообщение с цветом, соответствующим уровню логирования
  static void logWithLevel(String message, RpcLoggerLevel level) {
    final color = logColors.colorForLevel(level);
    logColored(message, color,
        isError: level.index >= RpcLoggerLevel.error.index);
  }
}
