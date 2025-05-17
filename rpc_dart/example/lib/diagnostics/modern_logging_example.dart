// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

/// Пример работы с новой системой логирования
///
/// Демонстрирует создание различных логгеров с независимыми настройками,
/// использование фильтров и форматтеров, а также методы управления логгерами.
Future<void> main() async {
  print('Пример использования новой системы логирования в RpcDart\n');

  // Настраиваем глобальные параметры логирования
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Создаем логгеры для разных компонентов
  final apiLogger = RpcLogger('API');
  final dbLogger = RpcLogger('Database');
  final uiLogger = RpcLogger('UI');

  // Демонстрация работы с логгерами
  print('=== Демонстрация работы с разными логгерами ===');
  await apiLogger.info('API запущен и готов к работе');
  await dbLogger.debug('Подключение к базе данных установлено');
  await dbLogger.warning('Медленный запрос к базе данных');
  await uiLogger.info('Пользовательский интерфейс инициализирован');

  try {
    throw Exception('Ошибка доступа к API');
  } catch (e, stackTrace) {
    await apiLogger.error(
      'Не удалось выполнить запрос к серверу',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Демонстрация создания кастомного логгера
  print('\n=== Создание кастомного логгера ===');
  final customLogger = RpcLogger('CustomLogger');

  await customLogger.log(
    level: RpcLoggerLevel.warning,
    message: 'Это предупреждение должно отображаться в кастомном формате',
  );
  await customLogger.log(
    level: RpcLoggerLevel.error,
    message: 'Ошибка в кастомном формате',
  );

  // Демонстрация работы с глобальными настройками
  print('\n=== Изменение глобальных настроек ===');
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.warning);

  await apiLogger.debug('Этого сообщения не должно быть видно');
  await apiLogger.warning(
    'Это предупреждение должно отображаться в новом формате',
  );

  print('\nПример завершен');
}

/// Пример пользовательского фильтра логов
class CustomLogFilter implements IRpcLoggerFilter {
  @override
  bool shouldLog(RpcLoggerLevel level, String source) {
    // Пропускаем все сообщения для Database, кроме debug с определенным источником
    if (source == 'Database' && level == RpcLoggerLevel.debug) {
      // В реальном фильтре здесь может быть более сложная логика
      return true;
    }

    // Для всех остальных используем стандартную проверку по уровню
    return level.index >= RpcLoggerLevel.info.index;
  }
}

/// Пример пользовательского форматтера логов
class CustomLogFormatter implements IRpcLoggerFormatter {
  @override
  String format(
    DateTime timestamp,
    RpcLoggerLevel level,
    String source,
    String message, {
    String? context,
  }) {
    final emoji = _getEmojiForLevel(level);
    final levelName = level.name.toUpperCase().padRight(7);
    final time = '${timestamp.hour}:${timestamp.minute}:${timestamp.second}';

    return '【$time】$emoji [$levelName] $source: $message';
  }

  String _getEmojiForLevel(RpcLoggerLevel level) {
    switch (level) {
      case RpcLoggerLevel.debug:
        return '🔍';
      case RpcLoggerLevel.info:
        return 'ℹ️';
      case RpcLoggerLevel.warning:
        return '⚠️';
      case RpcLoggerLevel.error:
        return '🚨';
      case RpcLoggerLevel.critical:
        return '💀';
      default:
        return '📝';
    }
  }
}

/// Пример простого форматтера, который показывает только время и сообщение
class TimestampOnlyFormatter implements IRpcLoggerFormatter {
  @override
  String format(
    DateTime timestamp,
    RpcLoggerLevel level,
    String source,
    String message, {
    String? context,
  }) {
    final time = '${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
    return '[$time] $message';
  }
}
