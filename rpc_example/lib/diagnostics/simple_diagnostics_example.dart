// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

/// Простой пример использования системы диагностики
///
/// Демонстрирует:
/// - Настройку системы логирования
/// - Различные уровни логов
/// - Использование цветного вывода в консоль
/// - Фильтрацию логов по уровню
void main() async {
  print('\n=== Простой пример использования системы диагностики ===\n');

  // Настройка системы логирования
  // Устанавливаем минимальный уровень логов (все логи ниже этого уровня будут игнорироваться)
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Создаем логгер с именем компонента
  final mainLogger = RpcLogger('MainComponent');

  // Демонстрация различных уровней логирования
  print('\n> Демонстрация различных уровней логирования:');

  mainLogger.debug('Это отладочное сообщение - полезно при разработке');
  mainLogger.info('Это информационное сообщение - обычные события приложения');
  mainLogger.warning(
    'Это предупреждение - что-то не критичное, но заслуживающее внимания',
  );
  mainLogger.error(
    'Это сообщение об ошибке - что-то пошло не так',
    error: Exception('Пример ошибки'),
    context: 'AuthService',
    data: {'userId': '12345', 'operation': 'login'},
  );

  // Создаем несколько логгеров для разных компонентов
  final networkLogger = RpcLogger('NetworkService');
  final dbLogger = RpcLogger('DatabaseService');
  final authLogger = RpcLogger('AuthService');

  // Демонстрация логирования из разных компонентов
  print('\n> Логи из разных компонентов системы:');

  networkLogger.info('Установление соединения с сервером');
  dbLogger.info('Выполнение запроса к базе данных');
  authLogger.info('Аутентификация пользователя');

  // Измерение времени выполнения операции
  print('\n> Измерение времени выполнения операции:');

  // Ручное измерение с использованием Stopwatch
  final stopwatch = Stopwatch()..start();

  await performSlowOperation();

  stopwatch.stop();
  mainLogger.info(
    'Операция выполнена за ${stopwatch.elapsedMilliseconds}мс',
    data: {'operationName': 'performSlowOperation'},
  );

  // Демонстрация обработки ошибок
  print('\n> Обработка и логирование ошибок:');

  try {
    await riskyOperation();
  } catch (e, stackTrace) {
    mainLogger.error(
      'Произошла ошибка при выполнении рискованной операции',
      error: e,
      stackTrace: stackTrace,
      context: 'ErrorHandling',
    );
  }

  // Изменение уровня логирования
  print('\n> Изменение минимального уровня логирования до INFO:');
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.info);

  mainLogger.debug(
    'Этот отладочный лог не будет отображаться, т.к. уровень поднят до INFO',
  );
  mainLogger.info('Этот информационный лог будет отображаться');

  // Создание кастомного логгера с цветным выводом
  print('\n> Демонстрация цветного вывода:');

  final customLogger = DefaultRpcLogger(
    'ColorLogger',
    coloredLoggingEnabled: true,
    colors: RpcLoggerColors(
      debug: AnsiColor.cyan,
      info: AnsiColor.brightGreen,
      warning: AnsiColor.brightYellow,
      error: AnsiColor.brightRed,
      critical: AnsiColor.magenta,
    ),
  );

  customLogger.debug('Отладочное сообщение с цветом');
  customLogger.info('Информационное сообщение с цветом');
  customLogger.warning('Предупреждение с цветом');
  customLogger.error('Ошибка с цветом', error: 'Что-то пошло не так');

  print('\n=== Пример завершен ===\n');
}

/// Имитация медленной операции
Future<void> performSlowOperation() async {
  // Искусственная задержка для демонстрации
  await Future.delayed(Duration(milliseconds: 500));
}

/// Операция, которая всегда вызывает ошибку
Future<void> riskyOperation() async {
  throw StateError('Операция намеренно завершилась с ошибкой');
}
