// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import 'router/cli.dart';
import 'router/config.dart';
import 'router/error_handler.dart';
import 'router/daemon.dart';

const String version = '2.0.0';

void main(List<String> arguments) async {
  // Запускаем в защищенной зоне для перехвата всех ошибок
  runZonedGuarded<void>(
    () async {
      await _mainWithErrorHandling(arguments);
    },
    (error, stackTrace) {
      // Создаем временный обработчик ошибок
      final errorHandler = ErrorHandler(
        verbose: true,
        isDaemon: false,
      );
      errorHandler.handleError(error, stackTrace);
    },
  );
}

/// Основная логика с обработкой ошибок
Future<void> _mainWithErrorHandling(List<String> arguments) async {
  try {
    // Создаем парсер аргументов
    final parser = _createArgParser();

    // Парсим аргументы
    late final ArgResults args;
    try {
      args = parser.parse(arguments);
    } catch (e) {
      print('❌ Ошибка парсинга аргументов: $e\n');
      _printUsage(parser);
      exit(1);
    }

    // Обрабатываем специальные команды
    if (args['help'] as bool) {
      _printUsage(parser);
      return;
    }

    if (args['version'] as bool) {
      print('🚀 RPC Dart Router v$version');
      return;
    }

    // Создаем конфигурацию из аргументов
    final config = await RouterConfig.fromArgs(args);

    // Daemon команды
    if (args['daemon-start'] as bool) {
      final daemonManager = DaemonManager(config: config);
      await daemonManager.daemonize();
      return;
    }

    if (args['daemon-stop'] as bool) {
      final daemonManager = DaemonManager(config: config);
      await daemonManager.stop();
      return;
    }

    if (args['daemon-status'] as bool) {
      final daemonManager = DaemonManager(config: config);
      await daemonManager.status();
      return;
    }

    if (args['daemon-reload'] as bool) {
      final daemonManager = DaemonManager(config: config);
      await daemonManager.reload();
      return;
    }

    // Создаем и запускаем CLI
    final cli = await RouterCLI.create(arguments);

    // Запускаем роутер
    await cli.run();
  } catch (e, stackTrace) {
    final errorHandler = ErrorHandler(
      verbose: true,
      isDaemon: false,
    );
    await errorHandler.handleError(e, stackTrace);
    exit(1);
  }
}

/// Создает парсер аргументов командной строки
ArgParser _createArgParser() {
  final parser = ArgParser();

  // Основные опции
  parser.addOption('host', abbr: 'h', defaultsTo: '0.0.0.0', help: 'Хост для привязки');
  parser.addOption('port', abbr: 'p', defaultsTo: '8080', help: 'Порт для привязки');

  // Логирование
  parser.addOption('log-level', allowed: ['debug', 'info', 'warning', 'error'], defaultsTo: 'info');
  parser.addFlag('verbose', abbr: 'v', help: 'Подробный вывод');
  parser.addFlag('quiet', abbr: 'q', help: 'Тихий режим');
  parser.addOption('log-file', help: 'Файл для логирования');

  // Мониторинг
  parser.addFlag('stats', help: 'Включить статистику', defaultsTo: true);
  parser.addFlag('metrics', help: 'Включить метрики Prometheus');
  parser.addOption('metrics-port', help: 'Порт для метрик', defaultsTo: '9090');
  parser.addFlag('health-check', help: 'Включить мониторинг клиентов', defaultsTo: true);
  parser.addOption('client-timeout', help: 'Таймаут клиента в секундах', defaultsTo: '300');

  // Daemon
  parser.addFlag('daemon', abbr: 'd', help: 'Запустить в daemon режиме');
  parser.addFlag('daemon-start', help: 'Запустить daemon');
  parser.addFlag('daemon-stop', help: 'Остановить daemon');
  parser.addFlag('daemon-status', help: 'Статус daemon');
  parser.addFlag('daemon-reload', help: 'Перезагрузить daemon');
  parser.addFlag('stop', help: 'Остановить daemon (алиас для daemon-stop)');
  parser.addFlag('status', help: 'Статус daemon (алиас для daemon-status)');
  parser.addFlag('reload', help: 'Перезагрузить daemon (алиас для daemon-reload)');
  parser.addFlag('_daemon-child', help: 'Внутренний флаг для дочернего процесса', hide: true);
  parser.addOption('pid-file', help: 'Файл PID для daemon');

  // Производительность
  parser.addOption('max-connections', help: 'Максимум соединений', defaultsTo: '1000');
  parser.addOption('worker-threads', help: 'Количество рабочих потоков (0=auto)', defaultsTo: '0');

  // Безопасность
  parser.addFlag('tls', help: 'Включить TLS');
  parser.addOption('cert-file', help: 'Файл сертификата TLS');
  parser.addOption('key-file', help: 'Файл ключа TLS');

  // Служебные
  parser.addFlag('help', help: 'Показать справку');
  parser.addFlag('version', help: 'Показать версию');

  return parser;
}

/// Выводит справку по использованию
void _printUsage(ArgParser parser) {
  print('🚀 RPC Dart Router v$version');
  print('');
  print('Высокопроизводительный HTTP/2 gRPC роутер для межсервисной коммуникации');
  print('');
  print('Использование:');
  print('  dart run bin/rpc_dart_router.dart [опции]');
  print('');
  print('Опции:');
  print(parser.usage);
  print('');
  print('Примеры:');
  print('  # Запуск с настройками по умолчанию');
  print('  dart run bin/rpc_dart_router.dart');
  print('');
  print('  # Запуск на конкретном хосте и порту');
  print('  dart run bin/rpc_dart_router.dart -h 127.0.0.1 -p 8080');
  print('');
  print('  # Запуск в daemon режиме');
  print('  dart run bin/rpc_dart_router.dart --daemon-start');
  print('');
  print('  # Запуск с дополнительными опциями');
  print('  dart run bin/rpc_dart_router.dart --verbose --metrics');
  print('');
}
