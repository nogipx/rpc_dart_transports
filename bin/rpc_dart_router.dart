// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

const String version = '2.0.0';

void main(List<String> arguments) async {
  // Запускаем в защищенной зоне для перехвата всех ошибок
  runZonedGuarded<void>(
    () async {
      await _mainWithErrorHandling(arguments);
    },
    (error, stackTrace) {
      // Глобальный обработчик unhandled exceptions
      final timestamp = DateTime.now().toIso8601String();
      final errorMsg = '🚨 === НЕОБРАБОТАННАЯ ОШИБКА ===\n'
          '❌ Время: $timestamp\n'
          '❌ Тип: ${error.runtimeType}\n'
          '📝 Ошибка: $error\n';

      // В daemon режиме пишем в лог файл
      if (_isDaemonChild) {
        try {
          final logFile = _daemonLogFile ?? '/tmp/rpc_dart_router.log';
          File(logFile).writeAsStringSync(
            '$timestamp: FATAL ERROR: $error\n$stackTrace\n',
            mode: FileMode.writeOnlyAppend,
          );
        } catch (e) {
          // Если не можем писать в лог, пишем в stderr
          stderr.writeln('Failed to write to log: $e');
        }
      }

      print(errorMsg);

      // Специальная обработка HTTP/2 ошибок
      if (error.toString().contains('HTTP/2 error') ||
          error.toString().contains('Connection is being forcefully terminated')) {
        final httpMsg =
            '🔗 HTTP/2 соединение было принудительно закрыто (это нормально при отключении клиентов)\n♻️  Роутер продолжает работу...';
        print(httpMsg);
        if (_isDaemonChild && _daemonLogFile != null) {
          try {
            File(_daemonLogFile!).writeAsStringSync(
              '$timestamp: $httpMsg\n',
              mode: FileMode.writeOnlyAppend,
            );
          } catch (e) {
            // Игнорируем ошибки логирования
          }
        }
        return; // Не завершаем процесс для HTTP/2 ошибок
      }

      if (_isVerbose) {
        print('📍 Stack trace: $stackTrace');
      }

      print('🛑 Завершение работы из-за критической ошибки...');
      exit(1);
    },
  );
}

/// Основная логика с обработкой ошибок
Future<void> _mainWithErrorHandling(List<String> arguments) async {
  final parser = _buildArgParser();

  try {
    final argResults = parser.parse(arguments);

    if (argResults['help'] as bool) {
      _printUsage(parser);
      return;
    }

    if (argResults['version'] as bool) {
      print('🚀 RPC Dart Router v$version');
      return;
    }

    final config = _parseConfig(argResults);

    // Обработка daemon команд
    if (argResults['stop'] as bool) {
      await _stopDaemon(config);
      return;
    }

    if (argResults['status'] as bool) {
      await _statusDaemon(config);
      return;
    }

    // Если режим daemon и еще не демонизированы - запускаем демонизацию
    if (config.daemon && !_isDaemonChild) {
      await _daemonize(config, arguments);
      return; // Родительский процесс завершается
    }

    final routerCli = RouterCLI(config);

    // Запускаем роутер
    await routerCli.start();

    // Graceful shutdown
    await _waitForShutdownSignal();

    // Graceful shutdown с таймаутом
    print('🔄 Graceful shutdown в процессе...');
    try {
      await routerCli.stop().timeout(
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
  } on FormatException catch (e) {
    print('❌ Ошибка в аргументах: ${e.message}');
    print('');
    _printUsage(parser);
    exit(1);
  } catch (e, stackTrace) {
    print('❌ Неожиданная ошибка: $e');
    if (_isVerbose) {
      print('📍 Stack trace: $stackTrace');
    }
    exit(1);
  }
}

/// Конфигурация роутера
class RouterConfig {
  final String host;
  final int port;
  final bool enableStats;
  final String logLevel;
  final bool verbose;
  final int clientTimeoutSeconds;
  final bool daemon;
  final String? pidFile;
  final String? logFile;

  const RouterConfig({
    this.host = '0.0.0.0',
    this.port = 11112, // HTTP/2 порт по умолчанию
    this.enableStats = true,
    this.logLevel = 'info',
    this.verbose = false,
    this.clientTimeoutSeconds = 300,
    this.daemon = false,
    this.pidFile,
    this.logFile,
  });
}

bool _isVerbose = false;
bool _isDaemonChild = false;
String? _daemonLogFile;

/// Основной класс CLI роутера (только HTTP/2)
class RouterCLI {
  final RouterConfig config;
  final RpcLogger logger;

  /// Транспорт-агностичный роутер сервер
  late final RpcRouterServer _routerServer;

  /// HTTP/2 сервер (высокоуровневый)
  RpcHttp2Server? _http2Server;

  /// Подписки для HTTP/2 соединений
  final List<StreamSubscription> _http2Subscriptions = [];

  /// Таймер статистики
  Timer? _statsTimer;

  /// Таймер health check для daemon
  Timer? _healthCheckTimer;

  /// Время старта
  late final DateTime _startTime;

  RouterCLI(this.config) : logger = RpcLogger('RouterCLI') {
    // Настраиваем глобальный уровень логирования
    RpcLogger.setDefaultMinLogLevel(RpcLoggerLevel.info);

    // Daemon логирование настроится после запуска роутера
  }

  /// Настраивает логирование для daemon режима
  void _setupDaemonLogging() {
    final logFile = config.logFile ?? '/tmp/rpc_dart_router.log';

    try {
      // Создаем лог файл если его нет
      File(logFile).createSync(recursive: true);

      // Записываем начальное сообщение о запуске дочернего процесса
      final startMessage =
          '${DateTime.now().toIso8601String()}: ===== RPC Router Daemon Child Started =====\n';
      File(logFile).writeAsStringSync(startMessage, mode: FileMode.writeOnlyAppend);

      // Записываем информацию о конфигурации
      final configMessage =
          '${DateTime.now().toIso8601String()}: Config - Host: ${config.host}, Port: ${config.port}, Stats: ${config.enableStats}\n';
      File(logFile).writeAsStringSync(configMessage, mode: FileMode.writeOnlyAppend);

      // Настраиваем таймер для периодической записи в лог
      _setupPeriodicLogging(logFile);

      // Пишем что логирование настроено
      final logSetupMessage =
          '${DateTime.now().toIso8601String()}: Daemon logging configured successfully\n';
      File(logFile).writeAsStringSync(logSetupMessage, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // В случае ошибки пишем в stderr и продолжаем
      stderr.writeln('Warning: Failed to setup daemon logging: $e');
    }
  }

  /// Настраивает периодическое логирование состояния
  void _setupPeriodicLogging(String logFile) {
    Timer.periodic(Duration(seconds: 30), (timer) {
      try {
        final timestamp = DateTime.now().toIso8601String();
        final connectionCount = _routerServer.getStats().activeConnections;
        final logEntry =
            '$timestamp: [DAEMON] Router working, active connections: $connectionCount\n';
        File(logFile).writeAsStringSync(logEntry, mode: FileMode.writeOnlyAppend);
      } catch (e) {
        // Игнорируем ошибки периодического логирования
      }
    });
  }

  /// Настраивает health check для daemon режима
  void _setupHealthCheck() {
    final logFile = config.logFile ?? '/tmp/rpc_dart_router.log';

    _healthCheckTimer = Timer.periodic(Duration(seconds: 60), (timer) {
      try {
        final timestamp = DateTime.now().toIso8601String();
        final uptime = DateTime.now().difference(_startTime);
        final stats = _routerServer.getStats();

        final healthMsg = '$timestamp: [HEALTH] Uptime: ${_formatDuration(uptime)}, '
            'Connections: ${stats.activeConnections}, '
            'Total: ${stats.totalConnections}, '
            'Memory: ${_getMemoryUsage()}\n';

        File(logFile).writeAsStringSync(healthMsg, mode: FileMode.writeOnlyAppend);

        // Проверяем что HTTP/2 сервер все еще работает
        if (_http2Server == null) {
          final errorMsg = '$timestamp: [ERROR] HTTP/2 server is null!\n';
          File(logFile).writeAsStringSync(errorMsg, mode: FileMode.writeOnlyAppend);
        }
      } catch (e) {
        // Записываем ошибку health check в лог
        try {
          final timestamp = DateTime.now().toIso8601String();
          File(logFile).writeAsStringSync(
            '$timestamp: [ERROR] Health check failed: $e\n',
            mode: FileMode.writeOnlyAppend,
          );
        } catch (logError) {
          stderr.writeln('Health check and logging both failed: $e, $logError');
        }
      }
    });
  }

  /// Получает примерное использование памяти
  String _getMemoryUsage() {
    try {
      // Простая проверка через ps команду
      final result = Process.runSync('ps', ['-o', 'rss=', '-p', '\$\$']);
      if (result.exitCode == 0) {
        final rss = int.tryParse(result.stdout.toString().trim()) ?? 0;
        return '${(rss / 1024).toStringAsFixed(1)}MB';
      }
    } catch (e) {
      // Игнорируем ошибки получения памяти
    }
    return 'unknown';
  }

  /// Запускает HTTP/2 роутер
  Future<void> start() async {
    _startTime = DateTime.now();

    try {
      logger.info('🚀 Запуск RPC Dart Router v$version (HTTP/2 gRPC)');
      logger.info('Конфигурация:');
      logger.info('  • Хост: ${config.host}');
      logger.info('  • Порт: ${config.port}');
      logger.info('  • Транспорт: HTTP/2 gRPC');
      logger.info('  • Логирование: ${config.logLevel}');
      logger.info('  • Статистика: ${config.enableStats ? 'включена' : 'отключена'}');

      if (config.daemon && _isDaemonChild) {
        logger.info('  • Режим: Daemon');
        if (config.pidFile != null) {
          logger.info('  • PID файл: ${config.pidFile}');
        }
        if (config.logFile != null) {
          logger.info('  • Лог файл: ${config.logFile}');
        }
      }

      // Создаем транспорт-агностичный роутер
      _routerServer = RpcRouterServer(
        logger: logger.child('RouterServer'),
      );

      // Запускаем HTTP/2 сервер
      await _startHttp2Server();

      // Запускаем статистику если включена
      if (config.enableStats) {
        _startStatsTimer();
      }

      // Настраиваем daemon логирование после инициализации роутера
      if (config.daemon && _isDaemonChild) {
        _setupDaemonLogging();
        _setupHealthCheck();
      }

      // Показываем сводку
      _printStartupSummary();
    } catch (e, stackTrace) {
      final errorMsg = 'Критическая ошибка запуска роутера: $e';

      // В daemon режиме обязательно пишем в лог файл
      if (config.daemon && _isDaemonChild) {
        try {
          final logFile = config.logFile ?? '/tmp/rpc_dart_router.log';
          final timestamp = DateTime.now().toIso8601String();
          File(logFile).writeAsStringSync(
            '$timestamp: FATAL STARTUP ERROR: $e\n$stackTrace\n',
            mode: FileMode.writeOnlyAppend,
          );
        } catch (logError) {
          stderr.writeln('Failed to write startup error to log: $logError');
        }
      }

      logger.error(errorMsg, error: e, stackTrace: config.verbose ? stackTrace : null);

      // В daemon режиме не используем exit(1) сразу - пытаемся graceful shutdown
      if (config.daemon && _isDaemonChild) {
        stderr.writeln('Daemon startup failed, attempting graceful shutdown...');
        try {
          await stop();
        } catch (stopError) {
          stderr.writeln('Graceful shutdown failed: $stopError');
        }
      }

      exit(1);
    }
  }

  /// Запускает HTTP/2 сервер с настоящим gRPC-style протоколом
  Future<void> _startHttp2Server() async {
    logger.info('🚀 Запуск HTTP/2 gRPC сервера на ${config.host}:${config.port}');

    // Используем высокоуровневый API!
    _http2Server = RpcHttp2Server(
      host: config.host,
      port: config.port,
      logger: config.verbose ? logger.child('Http2Server') : null,
      onEndpointCreated: (endpoint) {
        // Создаем соединение через RouterServer для каждого endpoint
        final connectionId = _routerServer.createConnection(
          transport: endpoint.transport,
          connectionLabel: 'http2_${DateTime.now().millisecondsSinceEpoch}',
          clientAddress: 'http2-client',
        );

        logger.info('✅ HTTP/2 клиент подключен: $connectionId');
      },
      onConnectionError: (error, stackTrace) {
        logger.error('Ошибка HTTP/2 соединения',
            error: error, stackTrace: config.verbose ? stackTrace : null);
      },
    );

    await _http2Server!.start();
    logger.info('🚀 HTTP/2 gRPC сервер запущен на http://${config.host}:${config.port}');
  }

  /// Обрабатывает новый HTTP/2 транспорт
  void _handleHttp2Transport(RpcHttp2ResponderTransport transport) {
    final connectionId = 'http2_${DateTime.now().millisecondsSinceEpoch}';

    logger.debug('🔗 Новый HTTP/2 транспорт: $connectionId');

    try {
      // Создаем соединение через RouterServer
      final actualConnectionId = _routerServer.createConnection(
        transport: transport,
        connectionLabel: connectionId,
        clientAddress: 'http2-client',
      );

      logger.info('✅ HTTP/2 клиент подключен: $actualConnectionId');

      // Мониторим завершение соединения через транспорт с улучшенной обработкой ошибок
      transport.incomingMessages.listen(
        (message) {
          try {
            // Сообщения автоматически обрабатываются RouterServer'ом
            logger.debug(
                'HTTP/2 сообщение получено от $actualConnectionId: stream ${message.streamId}');
          } catch (e) {
            logger.debug('Ошибка при обработке HTTP/2 сообщения от $actualConnectionId: $e');
          }
        },
        onError: (error) async {
          try {
            // Логируем ошибку но не падаем
            if (error.toString().contains('Connection is being forcefully terminated') ||
                error.toString().contains('HTTP/2 error')) {
              logger.debug(
                  '🔗 HTTP/2 соединение $actualConnectionId закрыто клиентом (нормально): $error');
            } else {
              logger.warning('❌ Ошибка HTTP/2 соединения $actualConnectionId: $error');
            }

            // Graceful закрытие соединения
            await _routerServer.closeConnection(actualConnectionId, reason: 'HTTP/2 error: $error');
          } catch (e) {
            logger.debug('Ошибка при закрытии соединения $actualConnectionId: $e');
          }
        },
        onDone: () async {
          try {
            logger.info('🔌 HTTP/2 клиент отключился: $actualConnectionId');
            await _routerServer.closeConnection(actualConnectionId, reason: 'HTTP/2 closed');
          } catch (e) {
            logger.debug('Ошибка при закрытии соединения $actualConnectionId в onDone: $e');
          }
        },
        cancelOnError: false, // Не отменяем подписку при ошибках
      );
    } catch (e, stackTrace) {
      logger.error('Ошибка обработки HTTP/2 транспорта',
          error: e, stackTrace: config.verbose ? stackTrace : null);
    }
  }

  /// Запускает таймер статистики
  void _startStatsTimer() {
    logger.info('📊 Статистика роутера будет выводиться каждые 30с');

    _statsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _printStats();
    });
  }

  /// Выводит статистику роутера
  void _printStats() {
    final stats = _routerServer.getStats();
    final uptime = DateTime.now().difference(_startTime);

    print('\n📊 === СТАТИСТИКА РОУТЕРА ===');
    print('⏱️  Время работы: ${_formatDuration(uptime)}');
    print('🔗 Активных соединений: ${stats.activeConnections}');
    print('📈 Всего соединений: ${stats.totalConnections}');
    print('👥 Активных клиентов: ${stats.routerStats.activeClients}');
    print('📨 Обработано сообщений: ${stats.routerStats.totalMessages}');
    print('❌ Ошибок: ${stats.routerStats.errorCount}');

    final connections = _routerServer.getActiveConnections();
    if (connections.isNotEmpty) {
      print('🚀 Транспорты:');
      final transportCounts = <String, int>{};
      for (final conn in connections) {
        final transport = conn.transport.replaceAll('Rpc', '').replaceAll('ResponderTransport', '');
        transportCounts[transport] = (transportCounts[transport] ?? 0) + 1;
      }
      for (final entry in transportCounts.entries) {
        print('   • ${entry.key}: ${entry.value} соединений');
      }
    }
    print('================================\n');
  }

  /// Показывает сводку после запуска
  void _printStartupSummary() {
    print('\n🎉 === HTTP/2 gRPC РОУТЕР ЗАПУЩЕН ===');
    print('📡 Доступный endpoint:');
    print('   • HTTP/2 gRPC: http://${config.host}:${config.port}');

    print('\n💡 Пример подключения:');
    print('```dart');
    print('// HTTP/2 gRPC клиент');
    print('final transport = await RpcHttp2CallerTransport.connect(');
    print("  host: '${config.host}',");
    print('  port: ${config.port},');
    print(');');
    print('final endpoint = RpcCallerEndpoint(transport: transport);');
    print('final client = RpcRouterClient(callerEndpoint: endpoint);');
    print('await client.register(clientName: "my_client");');
    print('await client.initializeP2P();');
    print('```');

    print('\n🔧 Управление:');
    print('   • Ctrl+C или SIGTERM для graceful shutdown');
    if (config.enableStats) {
      print('   • Статистика выводится каждые 30с');
    }
    print('=====================================\n');
  }

  /// Останавливает роутер
  Future<void> stop() async {
    logger.info('🛑 Остановка роутера...');

    // Останавливаем таймеры
    _statsTimer?.cancel();
    _statsTimer = null;

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    // Отменяем HTTP/2 подписки
    for (final subscription in _http2Subscriptions) {
      try {
        await subscription.cancel();
      } catch (e) {
        logger.warning('Ошибка отмены HTTP/2 подписки: $e');
      }
    }
    _http2Subscriptions.clear();

    // Закрываем HTTP/2 сервер
    if (_http2Server != null) {
      logger.info('Закрытие HTTP/2 сервера...');
      try {
        await _http2Server!.stop().timeout(Duration(seconds: 5));
        logger.debug('HTTP/2 сервер закрыт');
      } catch (e) {
        logger.warning('Ошибка закрытия HTTP/2 сервера: $e (принудительно продолжаем)');
      }
      _http2Server = null;
    }

    // Закрываем роутер сервер с таймаутом
    try {
      await _routerServer.dispose().timeout(Duration(seconds: 5));
      logger.debug('RouterServer закрыт');
    } catch (e) {
      logger.warning('Ошибка закрытия RouterServer: $e (принудительно продолжаем)');
    }

    final uptime = DateTime.now().difference(_startTime);
    logger.info('✅ Роутер остановлен (время работы: ${_formatDuration(uptime)})');
  }

  /// Форматирует длительность в читаемый вид
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}д ${duration.inHours % 24}ч ${duration.inMinutes % 60}м';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}ч ${duration.inMinutes % 60}м';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}м ${duration.inSeconds % 60}с';
    } else {
      return '${duration.inSeconds}с';
    }
  }
}

/// Демонизация процесса (только для Unix-подобных систем)
Future<void> _daemonize(RouterConfig config, List<String> arguments) async {
  if (!Platform.isLinux && !Platform.isMacOS) {
    print('❌ Режим daemon поддерживается только на Linux и macOS');
    exit(1);
  }

  print('🔄 Запуск в режиме daemon...');

  // Получаем путь к текущему исполняемому файлу
  final scriptPath = Platform.script.toFilePath();

  // Создаем новые аргументы для дочернего процесса (убираем --daemon и добавляем внутренний флаг)
  final childArgs = arguments.where((arg) => arg != '--daemon' && arg != '-d').toList();
  childArgs.add('--_daemon-child');

  // Настройка файлов логов
  final logFile = config.logFile ?? '/tmp/rpc_dart_router.log';
  final pidFile = config.pidFile ?? '/tmp/rpc_dart_router.pid';

  try {
    // Создаем лог файл заранее
    await File(logFile).create(recursive: true);

    // Записываем начальную запись о запуске
    final startupMessage =
        '${DateTime.now().toIso8601String()}: ===== Daemon startup initiated =====\n';
    await File(logFile).writeAsString(startupMessage, mode: FileMode.writeOnlyAppend);

    // Запускаем дочерний процесс в detached режиме с улучшенными настройками
    final process = await Process.start(
      Platform.resolvedExecutable,
      [scriptPath, ...childArgs],
      mode: ProcessStartMode.detached,
      runInShell: false,
      workingDirectory: Directory.current.path,
      // Не передаем кастомные переменные окружения - может быть проблематично
    );

    // Ждем немного чтобы убедиться что процесс запустился
    await Future.delayed(Duration(milliseconds: 500));

    // Проверяем что процесс действительно запущен
    if (!_isProcessRunning(process.pid)) {
      print('❌ Дочерний процесс не запустился или завершился');
      exit(1);
    }

    // Сохраняем PID
    await File(pidFile).writeAsString('${process.pid}');

    // Создаем начальную запись в лог файле от родительского процесса
    try {
      final logEntry =
          '${DateTime.now().toIso8601String()}: ===== Daemon родительский процесс завершен, дочерний PID: ${process.pid} =====\n';
      await File(logFile).writeAsString(logEntry, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // Игнорируем ошибки логирования на этом этапе
    }

    print('✅ Daemon запущен с PID: ${process.pid}');
    print('📄 PID файл: $pidFile');
    print('📝 Логи: $logFile');
    print('💡 Используйте --status для проверки состояния');

    // Родительский процесс завершается
    exit(0);
  } catch (e) {
    print('❌ Ошибка демонизации: $e');
    exit(1);
  }
}

/// Останавливает daemon
Future<void> _stopDaemon(RouterConfig config) async {
  final pidFile = config.pidFile ?? '/tmp/rpc_dart_router.pid';

  if (!await File(pidFile).exists()) {
    print('❌ PID файл не найден: $pidFile');
    print('💡 Daemon возможно не запущен');
    exit(1);
  }

  try {
    final pidStr = await File(pidFile).readAsString();
    final pid = int.parse(pidStr.trim());

    print('🛑 Остановка daemon с PID: $pid');

    try {
      // Отправляем SIGTERM
      final result = Process.killPid(pid, ProcessSignal.sigterm);
      print('📤 SIGTERM отправлен, результат: $result');

      // Ждем завершения процесса (независимо от результата killPid)
      var attempts = 0;
      while (attempts < 50) {
        // Увеличили количество попыток
        await Future.delayed(Duration(milliseconds: 200));
        if (!_isProcessRunning(pid)) {
          break;
        }
        attempts++;
        if (attempts % 10 == 0) {
          print('⏳ Ожидание завершения процесса... ($attempts/50)');
        }
      }

      if (_isProcessRunning(pid)) {
        print('⚠️ Graceful shutdown не удался, принудительная остановка...');
        Process.killPid(pid, ProcessSignal.sigkill);
        await Future.delayed(Duration(seconds: 1));

        if (_isProcessRunning(pid)) {
          print('❌ Не удалось принудительно остановить процесс');
          exit(1);
        }
      }

      // Удаляем PID файл
      await File(pidFile).delete();
      print('✅ Daemon остановлен');
    } catch (e) {
      print('❌ Ошибка при отправке сигнала: $e');
      // Все равно пытаемся удалить PID файл если процесс не работает
      if (!_isProcessRunning(pid)) {
        await File(pidFile).delete();
        print('🧹 PID файл удален (процесс не найден)');
      }
      exit(1);
    }
  } catch (e) {
    print('❌ Ошибка остановки daemon: $e');
    exit(1);
  }
}

/// Показывает статус daemon
Future<void> _statusDaemon(RouterConfig config) async {
  final pidFile = config.pidFile ?? '/tmp/rpc_dart_router.pid';

  if (!await File(pidFile).exists()) {
    print('❌ Daemon не запущен (PID файл не найден)');
    exit(1);
  }

  try {
    final pidStr = await File(pidFile).readAsString();
    final pid = int.parse(pidStr.trim());

    if (_isProcessRunning(pid)) {
      print('✅ Daemon запущен с PID: $pid');
      print('📄 PID файл: $pidFile');
      if (config.logFile != null) {
        print('📝 Логи: ${config.logFile}');
      }

      // Показываем дополнительную информацию если доступна
      final logFile = config.logFile ?? '/tmp/rpc_dart_router.log';
      if (await File(logFile).exists()) {
        final stat = await File(logFile).stat();
        print('📊 Размер лог-файла: ${_formatBytes(stat.size)}');
        print('🕐 Последнее изменение: ${stat.modified}');
      }
    } else {
      print('❌ Процесс с PID $pid не найден');
      print('🔧 Удаляем устаревший PID файл...');
      await File(pidFile).delete();
      exit(1);
    }
  } catch (e) {
    print('❌ Ошибка проверки статуса: $e');
    exit(1);
  }
}

/// Проверяет работает ли процесс с указанным PID
bool _isProcessRunning(int pid) {
  try {
    // Используем ps команду для проверки существования процесса
    final result = Process.runSync('ps', ['-p', pid.toString()]);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

/// Форматирует размер в байтах
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Парсер аргументов командной строки
ArgParser _buildArgParser() {
  return ArgParser()
    ..addOption(
      'host',
      abbr: 'h',
      defaultsTo: '0.0.0.0',
      help: 'Хост для привязки HTTP/2 сервера',
    )
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '11112',
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
      defaultsTo: false,
      help: 'Показывать статистику роутера',
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
    ..addFlag(
      'daemon',
      abbr: 'd',
      help: 'Запустить в режиме daemon (фоновый процесс)',
    )
    ..addOption(
      'pid-file',
      help: 'Путь к PID файлу для daemon режима (по умолчанию: /tmp/rpc_dart_router.pid)',
    )
    ..addOption(
      'log-file',
      help: 'Путь к лог-файлу для daemon режима (по умолчанию: /tmp/rpc_dart_router.log)',
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

/// Парсит конфигурацию из аргументов
RouterConfig _parseConfig(ArgResults argResults) {
  final host = argResults['host'] as String;
  final portStr = argResults['port'] as String;
  final logLevelStr = argResults['log-level'] as String;
  final quiet = argResults['quiet'] as bool;
  final verbose = argResults['verbose'] as bool;
  final enableStats = argResults['stats'] as bool;
  final clientTimeoutStr = argResults['client-timeout'] as String;
  final daemon = argResults['daemon'] as bool;
  final pidFile = argResults['pid-file'] as String?;
  final logFile = argResults['log-file'] as String?;
  final isDaemonChild = argResults['_daemon-child'] as bool;

  _isVerbose = verbose;
  _isDaemonChild = isDaemonChild;
  if (isDaemonChild) {
    _daemonLogFile = logFile ?? '/tmp/rpc_dart_router.log';
  }

  // Валидация порта
  final port = int.tryParse(portStr);
  if (port == null || port < 1 || port > 65535) {
    throw FormatException('Порт должен быть числом от 1 до 65535, получен: $portStr');
  }

  // Конфликт флагов
  if (quiet && verbose) {
    throw FormatException('Нельзя использовать --quiet и --verbose одновременно');
  }

  // Парсинг уровня логирования
  RpcLoggerLevel logLevel;
  switch (logLevelStr) {
    case 'debug':
      logLevel = RpcLoggerLevel.debug;
      break;
    case 'info':
      logLevel = RpcLoggerLevel.info;
      break;
    case 'warning':
      logLevel = RpcLoggerLevel.warning;
      break;
    case 'error':
      logLevel = RpcLoggerLevel.error;
      break;
    case 'critical':
      logLevel = RpcLoggerLevel.critical;
      break;
    case 'none':
      logLevel = RpcLoggerLevel.none;
      break;
    default:
      throw FormatException('Неизвестный уровень логирования: $logLevelStr');
  }

  // Quiet переопределяет log-level
  if (quiet) {
    logLevel = RpcLoggerLevel.none;
  }

  // Парсинг таймаута
  final clientTimeout = int.tryParse(clientTimeoutStr);
  if (clientTimeout == null || clientTimeout < 1) {
    throw FormatException('Таймаут клиента должен быть положительным числом');
  }

  return RouterConfig(
    host: host,
    port: port,
    enableStats: enableStats,
    logLevel: logLevel.name,
    verbose: verbose,
    clientTimeoutSeconds: clientTimeout,
    daemon: daemon,
    pidFile: pidFile,
    logFile: logFile,
  );
}

/// Показывает справку
void _printUsage(ArgParser parser) {
  print('🚀 RPC Dart Router v$version - HTTP/2 gRPC роутер для RPC вызовов\n');
  print('Использование: rpc_dart_router [options]\n');
  print('Опции:');
  print(parser.usage);
  print('\nПримеры:');
  print('  rpc_dart_router                    # HTTP/2 на порту 11112');
  print('  rpc_dart_router -p 8080            # HTTP/2 на порту 8080');
  print('  rpc_dart_router -h 192.168.1.100   # HTTP/2 на определенном IP');
  print('  rpc_dart_router --quiet             # Тихий режим');
  print('  rpc_dart_router -v --log-level debug # Детальная отладка');
  print('  rpc_dart_router --stats             # С периодической статистикой');
  print('  rpc_dart_router --client-timeout 600 # Таймаут 10 минут');
  print('\nДемон режим:');
  print('  rpc_dart_router -d                  # Запуск в фоновом режиме');
  print('  rpc_dart_router -d --pid-file /var/run/router.pid # Кастомный PID файл');
  print('  rpc_dart_router -d --log-file /var/log/router.log # Кастомный лог файл');
  print('  rpc_dart_router --status            # Проверить статус daemon');
  print('  rpc_dart_router --stop              # Остановить daemon');
  print('\nТранспорт:');
  print('  HTTP/2 gRPC     Современный бинарный протокол с мультиплексингом');
  print(
      '                  Поддерживает все типы RPC вызовов: unary, client/server/bidirectional streams');
  print('\nДемон управление:');
  print('  • PID файл по умолчанию: /tmp/rpc_dart_router.pid');
  print('  • Лог файл по умолчанию: /tmp/rpc_dart_router.log');
  print('  • Graceful shutdown через SIGTERM');
  print('  • Принудительная остановка через SIGKILL');
}

/// Ожидает сигнал завершения (Ctrl+C, SIGTERM)
Future<void> _waitForShutdownSignal() async {
  final completer = Completer<void>();
  bool shutdownInitiated = false;

  // Обрабатываем SIGINT (Ctrl+C)
  ProcessSignal.sigint.watch().listen((signal) {
    if (!shutdownInitiated) {
      shutdownInitiated = true;
      print('\n🛑 Получен сигнал SIGINT, завершение работы...');
      if (!completer.isCompleted) {
        completer.complete();
      }
    } else {
      print('\n⚡ Повторный SIGINT - принудительное завершение!');
      exit(130); // Код выхода для SIGINT
    }
  });

  // Обрабатываем SIGTERM
  ProcessSignal.sigterm.watch().listen((signal) {
    if (!shutdownInitiated) {
      shutdownInitiated = true;
      print('\n🛑 Получен сигнал SIGTERM, завершение работы...');
      if (!completer.isCompleted) {
        completer.complete();
      }
    } else {
      print('\n⚡ Повторный SIGTERM - принудительное завершение!');
      exit(143); // Код выхода для SIGTERM
    }
  });

  await completer.future;
}
