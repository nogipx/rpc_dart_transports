// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import 'config.dart';
import 'daemon.dart';
import 'server.dart';
import 'signals.dart';
import 'error_handler.dart';

const String version = '2.0.0';

/// Основной CLI класс роутера
///
/// Отвечает за:
/// - Парсинг аргументов командной строки
/// - Инициализацию компонентов
/// - Координацию жизненного цикла приложения
class RouterCLI {
  /// Конфигурация роутера
  late final RouterConfig config;

  /// Сервер роутера
  RouterServer? _server;

  /// Daemon менеджер
  late final DaemonManager _daemon;

  /// Обработчик ошибок
  late final ErrorHandler _errorHandler;

  /// Обработчик сигналов
  late final SignalHandler _signalHandler;

  RouterCLI._();

  /// Создает и инициализирует CLI
  static Future<RouterCLI> create(List<String> arguments) async {
    final cli = RouterCLI._();
    await cli._initialize(arguments);
    return cli;
  }

  /// Инициализация CLI
  Future<void> _initialize(List<String> arguments) async {
    // Парсим аргументы и создаем конфигурацию
    config = await _createConfig(arguments);

    // Инициализируем компоненты
    _errorHandler = ErrorHandler(
      verbose: config.verbose,
      isDaemon: config.daemon,
      logFile: config.logFile,
    );

    _daemon = DaemonManager(config: config);

    _signalHandler = SignalHandler();
  }

  /// Запускает CLI приложение
  Future<void> run() async {
    try {
      // Обработка daemon команд
      if (config.stopDaemon) {
        await _daemon.stop();
        return;
      }

      if (config.statusDaemon) {
        await _daemon.status();
        return;
      }

      if (config.reloadDaemon) {
        await _daemon.reload();
        return;
      }

      // Демонизация если нужно
      if (config.daemon && !config.isDaemonChild) {
        await _daemon.daemonize();
        return; // Родительский процесс завершается
      }

      // Настраиваем обработчики сигналов
      _setupSignalHandlers();

      // Создаем и запускаем сервер
      _server = RouterServer(config: config, logger: null);

      // В daemon режиме логируем запуск
      if (config.isDaemonChild) {
        await _logDaemonStartup();
      }

      await _server!.start();

      // В daemon режиме логируем успешный запуск
      if (config.isDaemonChild) {
        await _logDaemonReady();
      }

      // Ждем сигнал завершения
      await _signalHandler.waitForShutdown();

      // Graceful shutdown
      await _gracefulShutdown();
    } catch (e, stackTrace) {
      // В daemon режиме логируем ошибку
      if (config.isDaemonChild) {
        await _logDaemonError(e, stackTrace);
      }

      await _errorHandler.handleError(e, stackTrace);
      exit(1);
    }
  }

  /// Настраивает обработчики сигналов
  void _setupSignalHandlers() {
    _signalHandler.initialize();

    // Настраиваем колбэки для daemon режима
    if (config.isDaemonChild) {
      _signalHandler.onReload = () async {
        await _logDaemonEvent('Configuration reload requested');
        // TODO: Реализовать перезагрузку конфигурации
        print('🔄 Перезагрузка конфигурации...');
      };

      _signalHandler.onStats = () async {
        await _logDaemonEvent('Statistics requested');
        if (_server != null) {
          // TODO: Добавить метод getStats в RouterServer
          await _logDaemonStats('Statistics not implemented yet');
        }
      };

      _signalHandler.onToggleDebug = () async {
        await _logDaemonEvent('Debug mode toggle requested');
        // TODO: Реализовать переключение debug режима
        print('🐛 Переключение debug режима...');
      };
    }
  }

  /// Логирует запуск daemon
  Future<void> _logDaemonStartup() async {
    if (config.logFile == null) return;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final message = '''
$timestamp: [INFO] RPC Dart Router daemon starting
$timestamp: [INFO] Configuration: host=${config.host}, port=${config.port}
$timestamp: [INFO] Log level: ${config.logLevel}
$timestamp: [INFO] Stats enabled: ${config.enableStats}
$timestamp: [INFO] Metrics enabled: ${config.enableMetrics}
''';
      await File(config.logFile!).writeAsString(message, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // Игнорируем ошибки логирования
    }
  }

  /// Логирует готовность daemon
  Future<void> _logDaemonReady() async {
    if (config.logFile == null) return;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final message = '''
$timestamp: [INFO] RPC Dart Router daemon ready
$timestamp: [INFO] HTTP/2 gRPC server listening on ${config.host}:${config.port}
$timestamp: [INFO] PID: ${pid}
$timestamp: [INFO] Ready to accept connections
''';
      await File(config.logFile!).writeAsString(message, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // Игнорируем ошибки логирования
    }
  }

  /// Логирует событие daemon
  Future<void> _logDaemonEvent(String event) async {
    if (config.logFile == null) return;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final message = '$timestamp: [INFO] $event\n';
      await File(config.logFile!).writeAsString(message, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // Игнорируем ошибки логирования
    }
  }

  /// Логирует ошибку daemon
  Future<void> _logDaemonError(Object error, StackTrace stackTrace) async {
    if (config.logFile == null) return;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final message = '''
$timestamp: [ERROR] Daemon error: $error
$timestamp: [ERROR] Stack trace: $stackTrace
''';
      await File(config.logFile!).writeAsString(message, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // Игнорируем ошибки логирования
    }
  }

  /// Логирует статистику daemon
  Future<void> _logDaemonStats(dynamic stats) async {
    if (config.logFile == null) return;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final message = '''
$timestamp: [INFO] Router statistics:
$timestamp: [INFO] $stats
''';
      await File(config.logFile!).writeAsString(message, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // Игнорируем ошибки логирования
    }
  }

  /// Graceful shutdown с таймаутом
  Future<void> _gracefulShutdown() async {
    print('🔄 Graceful shutdown в процессе...');

    try {
      await _server?.stop().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ Graceful shutdown превысил 10 секунд, принудительное завершение');
          exit(1);
        },
      );
      print('✅ Graceful shutdown завершен успешно');
    } catch (e) {
      print('❌ Ошибка при graceful shutdown: $e');
      exit(1);
    }
  }

  /// Создает конфигурацию из аргументов
  Future<RouterConfig> _createConfig(List<String> arguments) async {
    final parser = _buildArgParser();

    try {
      final argResults = parser.parse(arguments);

      if (argResults['help'] as bool) {
        _printUsage(parser);
        exit(0);
      }

      if (argResults['version'] as bool) {
        print('🚀 RPC Dart Router v$version');
        exit(0);
      }

      return RouterConfig.fromArgs(argResults);
    } on FormatException catch (e) {
      print('❌ Ошибка в аргументах: ${e.message}');
      print('');
      _printUsage(parser);
      exit(1);
    }
  }

  /// Парсер аргументов командной строки
  ArgParser _buildArgParser() {
    return ArgParser()
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Путь к конфигурационному файлу',
      )
      ..addOption(
        'host',
        abbr: 'h',
        defaultsTo: '0.0.0.0',
        help: 'Хост для привязки HTTP/2 сервера',
      )
      ..addOption(
        'port',
        abbr: 'p',
        defaultsTo: '8080',
        help: 'Порт для HTTP/2 gRPC сервера',
      )
      ..addOption(
        'log-level',
        abbr: 'l',
        defaultsTo: 'info',
        allowed: ['debug', 'info', 'warning', 'error', 'critical', 'none'],
        help: 'Уровень логирования',
      )
      ..addFlag(
        'quiet',
        abbr: 'q',
        help: 'Тихий режим (минимум вывода)',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Подробный режим (детальный вывод)',
      )
      ..addFlag(
        'stats',
        abbr: 's',
        defaultsTo: true,
        help: 'Показывать статистику роутера',
      )
      ..addFlag(
        'metrics',
        abbr: 'm',
        help: 'Включить экспорт метрик Prometheus',
      )
      ..addOption(
        'metrics-port',
        defaultsTo: '9090',
        help: 'Порт для экспорта метрик Prometheus',
      )
      ..addFlag(
        'health-check',
        defaultsTo: true,
        help: 'Включить мониторинг клиентов',
      )
      ..addOption(
        'client-timeout',
        defaultsTo: '300',
        help: 'Таймаут неактивности клиента в секундах',
      )
      ..addOption(
        'max-connections',
        defaultsTo: '1000',
        help: 'Максимальное количество соединений',
      )
      ..addFlag(
        'daemon',
        abbr: 'd',
        help: 'Запустить в режиме daemon (фоновый процесс)',
      )
      ..addOption(
        'pid-file',
        help: 'Путь к PID файлу для daemon режима',
      )
      ..addOption(
        'log-file',
        help: 'Путь к лог-файлу для daemon режима',
      )
      ..addFlag(
        'stop',
        help: 'Остановить daemon',
      )
      ..addFlag(
        'status',
        help: 'Показать статус daemon',
      )
      ..addFlag(
        'reload',
        help: 'Перезагрузить daemon (SIGHUP)',
      )
      ..addFlag(
        '_daemon-child',
        hide: true,
        help: 'Внутренний флаг для дочернего процесса daemon',
      )
      ..addFlag(
        'help',
        help: 'Показать справку',
      )
      ..addFlag(
        'version',
        help: 'Показать версию',
      );
  }

  /// Показывает справку
  void _printUsage(ArgParser parser) {
    print('🚀 RPC Dart Router v$version - HTTP/2 gRPC роутер для RPC вызовов\n');
    print('Использование: rpc_dart_router [options]\n');
    print('Опции:');
    print(parser.usage);
    print('\nПримеры:');
    print('  rpc_dart_router                           # HTTP/2 на порту 8080');
    print('  rpc_dart_router -p 8080                   # HTTP/2 на порту 8080');
    print('  rpc_dart_router -c config.yaml            # Из конфигурационного файла');
    print('  rpc_dart_router -h 192.168.1.100          # HTTP/2 на определенном IP');
    print('  rpc_dart_router --quiet                   # Тихий режим');
    print('  rpc_dart_router -v --log-level debug      # Детальная отладка');
    print('  rpc_dart_router --metrics                 # С экспортом метрик Prometheus');
    print('  rpc_dart_router --max-connections 5000    # Лимит соединений');
    print('\nДемон режим:');
    print('  rpc_dart_router -d                        # Запуск в фоновом режиме');
    print('  rpc_dart_router -d --config daemon.yaml   # Daemon с конфигурацией');
    print('  rpc_dart_router --status                  # Проверить статус daemon');
    print('  rpc_dart_router --stop                    # Остановить daemon');
    print('  rpc_dart_router --reload                  # Перезагрузить daemon');
    print('\nТранспорты:');
    print('  HTTP/2 gRPC     Современный бинарный протокол с мультиплексингом');
    print('                  Поддерживает все типы RPC вызовов и потоки');
    print('\nМониторинг:');
    print('  • Встроенная статистика роутера');
    print('  • Экспорт метрик Prometheus (--metrics)');
    print('  • Health check клиентов');
    print('  • Graceful shutdown через SIGTERM');
  }
}
