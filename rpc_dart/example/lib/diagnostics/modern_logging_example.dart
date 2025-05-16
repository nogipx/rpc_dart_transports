// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

const String _source = 'LoggingExample';

/// Пример работы с новой системой логирования
///
/// Демонстрирует создание различных логгеров с независимыми настройками,
/// использование фильтров и форматтеров, а также методы управления логгерами.
Future<void> main() async {
  print('Пример использования новой системы логирования в RpcDart\n');

  // Настраиваем глобальные параметры логирования
  RpcLogManager.setDefaultMinLogLevel(RpcLogLevel.debug);

  // Создаем логгеры для разных компонентов
  final apiLogger = RpcLogManager.get('API');
  final dbLogger = RpcLogManager.get('Database');
  final uiLogger = RpcLogManager.get('UI');

  // Настраиваем каждый логгер индивидуально
  apiLogger.setLogColors(
    const RpcLogColors(info: AnsiColor.cyan, error: AnsiColor.brightRed),
  );

  dbLogger.setFilter(CustomLogFilter());

  uiLogger.setLogColors(
    const RpcLogColors(
      debug: AnsiColor.blue,
      info: AnsiColor.brightGreen,
      warning: AnsiColor.brightYellow,
    ),
  );

  // Демонстрация работы с логгерами
  print('=== Демонстрация работы с разными логгерами ===');
  await apiLogger.info(message: 'API запущен и готов к работе');
  await dbLogger.debug(message: 'Подключение к базе данных установлено');
  await dbLogger.warning(message: 'Медленный запрос к базе данных');
  await uiLogger.info(message: 'Пользовательский интерфейс инициализирован');

  try {
    throw Exception('Ошибка доступа к API');
  } catch (e, stackTrace) {
    await apiLogger.error(
      message: 'Не удалось выполнить запрос к серверу',
      error: {'exception': e.toString()},
      stackTrace: stackTrace.toString(),
    );
  }

  // Демонстрация создания кастомного логгера
  print('\n=== Создание кастомного логгера ===');
  final customLogger = RpcLogManager.createLogger(
    name: 'CustomLogger',
    minLogLevel: RpcLogLevel.warning,
    formatter: CustomLogFormatter(),
  );

  await customLogger.debug(message: 'Это сообщение не должно отображаться');
  await customLogger.warning(
    message: 'Это предупреждение должно отображаться в кастомном формате',
  );
  await customLogger.error(message: 'Ошибка в кастомном формате');

  // Демонстрация работы с глобальными настройками
  print('\n=== Изменение глобальных настроек ===');
  RpcLogManager.setDefaultMinLogLevel(RpcLogLevel.warning);
  RpcLogManager.setGlobalFormatter(TimestampOnlyFormatter());

  await apiLogger.debug(message: 'Этого сообщения не должно быть видно');
  await apiLogger.warning(
    message: 'Это предупреждение должно отображаться в новом формате',
  );

  // Информация о зарегистрированных логгерах
  print('\n=== Информация о зарегистрированных логгерах ===');
  final loggerNames = RpcLogManager.getLoggerNames();
  print('Зарегистрированные логгеры: ${loggerNames.join(', ')}');

  print('\nПример завершен');
}

/// Пример пользовательского фильтра логов
class CustomLogFilter implements LogFilter {
  @override
  bool shouldLog(RpcLogLevel level, String source) {
    // Пропускаем все сообщения для Database, кроме debug с определенным источником
    if (source == 'Database' && level == RpcLogLevel.debug) {
      // В реальном фильтре здесь может быть более сложная логика
      return true;
    }

    // Для всех остальных используем стандартную проверку по уровню
    return level.index >= RpcLogLevel.info.index;
  }
}

/// Пример пользовательского форматтера логов
class CustomLogFormatter implements LogFormatter {
  @override
  String format(
    DateTime timestamp,
    RpcLogLevel level,
    String source,
    String message, {
    String? context,
  }) {
    final emoji = _getEmojiForLevel(level);
    final levelName = level.name.toUpperCase().padRight(7);
    final time = '${timestamp.hour}:${timestamp.minute}:${timestamp.second}';

    return '【$time】$emoji [$levelName] $source: $message';
  }

  String _getEmojiForLevel(RpcLogLevel level) {
    switch (level) {
      case RpcLogLevel.debug:
        return '🔍';
      case RpcLogLevel.info:
        return 'ℹ️';
      case RpcLogLevel.warning:
        return '⚠️';
      case RpcLogLevel.error:
        return '🚨';
      case RpcLogLevel.critical:
        return '💀';
      default:
        return '📝';
    }
  }
}

/// Пример простого форматтера, который показывает только время и сообщение
class TimestampOnlyFormatter implements LogFormatter {
  @override
  String format(
    DateTime timestamp,
    RpcLogLevel level,
    String source,
    String message, {
    String? context,
  }) {
    final time = '${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
    return '[$time] $message';
  }
}
