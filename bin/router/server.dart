// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import 'config.dart';

/// Основной HTTP/2 сервер роутера
///
/// Отвечает за:
/// - Запуск и остановку HTTP/2 gRPC сервера
/// - Управление соединениями клиентов
/// - Интеграцию с RouterServer для обработки сообщений
/// - Мониторинг и статистику
class RouterServer {
  final RouterConfig config;
  final RpcLogger? logger;

  /// Транспорт-агностичный роутер сервер
  late final RpcRouterServer _routerServer;

  /// HTTP/2 сервер (высокоуровневый)
  RpcHttp2Server? _http2Server;

  /// Таймер статистики
  Timer? _statsTimer;

  /// Таймер health check для daemon
  Timer? _healthCheckTimer;

  /// Время старта
  late final DateTime _startTime;

  /// Флаг запуска
  bool _isRunning = false;

  RouterServer({
    required this.config,
    this.logger,
  });

  /// Проверяет, запущен ли сервер
  bool get isRunning => _isRunning;

  /// Получает статистику сервера
  RouterServerStats get stats {
    if (!_isRunning) {
      return RouterServerStats.empty();
    }

    final routerStats = _routerServer.getStats();
    final uptime = DateTime.now().difference(_startTime);

    return RouterServerStats(
      isRunning: _isRunning,
      uptime: uptime,
      activeConnections: routerStats.activeConnections,
      totalConnections: routerStats.totalConnections,
      activeClients: routerStats.routerStats.activeClients,
      totalMessages: routerStats.routerStats.totalMessages,
      errorCount: routerStats.routerStats.errorCount,
      memoryUsage: _getMemoryUsage(),
    );
  }

  /// Запускает HTTP/2 роутер сервер
  Future<void> start() async {
    if (_isRunning) {
      throw StateError('Сервер уже запущен');
    }

    _startTime = DateTime.now();

    try {
      logger?.info('🚀 Запуск RPC Dart Router Server');
      logger?.info('Конфигурация:');
      logger?.info('  • Хост: ${config.host}');
      logger?.info('  • Порт: ${config.port}');
      logger?.info('  • Транспорт: HTTP/2 gRPC');
      logger?.info('  • Логирование: ${config.logLevel}');
      logger?.info('  • Статистика: ${config.enableStats ? 'включена' : 'отключена'}');

      if (config.daemon) {
        logger?.info('  • Режим: Daemon');
        if (config.pidFile != null) {
          logger?.info('  • PID файл: ${config.pidFile}');
        }
        if (config.logFile != null) {
          logger?.info('  • Лог файл: ${config.logFile}');
        }
      }

      // Создаем транспорт-агностичный роутер
      _routerServer = RpcRouterServer(
        logger: logger?.child('RouterServer'),
      );

      // Запускаем HTTP/2 сервер
      await _startHttp2Server();

      // Запускаем мониторинг если включен
      if (config.enableStats) {
        _startStatsTimer();
      }

      // Настраиваем daemon логирование после инициализации роутера
      if (config.daemon) {
        _setupDaemonLogging();
        _setupHealthCheck();
      }

      _isRunning = true;

      // Показываем сводку
      _printStartupSummary();

      logger?.info('✅ Router Server запущен успешно');
    } catch (e, stackTrace) {
      final errorMsg = 'Критическая ошибка запуска сервера: $e';

      // В daemon режиме обязательно пишем в лог файл
      if (config.daemon) {
        try {
          final logFile = config.logFile ?? '/tmp/rpc_dart_router.log';
          final timestamp = DateTime.now().toIso8601String();
          File(logFile).writeAsStringSync(
            '$timestamp: FATAL STARTUP ERROR: $e\n$stackTrace\n',
            mode: FileMode.writeOnlyAppend,
          );
        } catch (logError) {
          logger?.error('Failed to write startup error to log: $logError');
        }
      }

      logger?.error(errorMsg, error: e, stackTrace: config.verbose ? stackTrace : null);

      // Очищаем ресурсы при ошибке
      await _cleanup();

      rethrow;
    }
  }

  /// Запускает HTTP/2 сервер с настоящим gRPC-style протоколом
  Future<void> _startHttp2Server() async {
    logger?.info('🚀 Запуск HTTP/2 gRPC сервера на ${config.host}:${config.port}');

    // Используем высокоуровневый API!
    _http2Server = RpcHttp2Server(
      host: config.host,
      port: config.port,
      logger: config.verbose ? logger?.child('Http2Server') : null,
      onEndpointCreated: (endpoint) {
        // Создаем соединение через RouterServer для каждого endpoint
        final connectionId = _routerServer.createConnection(
          transport: endpoint.transport,
          connectionLabel: 'http2_${DateTime.now().millisecondsSinceEpoch}',
          clientAddress: 'http2-client',
        );

        logger?.info('✅ HTTP/2 клиент подключен: $connectionId');
      },
      onConnectionError: (error, stackTrace) {
        logger?.error('Ошибка HTTP/2 соединения',
            error: error, stackTrace: config.verbose ? stackTrace : null);
      },
    );

    await _http2Server!.start();
    logger?.info('🚀 HTTP/2 gRPC сервер запущен на http://${config.host}:${config.port}');
  }

  /// Настраивает логирование для daemon режима
  void _setupDaemonLogging() {
    final logFile = config.logFile ?? '/tmp/rpc_dart_router.log';

    try {
      // Создаем лог файл если его нет
      File(logFile).createSync(recursive: true);

      // Записываем начальное сообщение о запуске дочернего процесса
      final startMessage =
          '${DateTime.now().toIso8601String()}: ===== RPC Router Server Started =====\n';
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
      logger?.warning('Failed to setup daemon logging: $e');
    }
  }

  /// Настраивает периодическое логирование состояния
  void _setupPeriodicLogging(String logFile) {
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

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
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      try {
        final timestamp = DateTime.now().toIso8601String();
        final uptime = DateTime.now().difference(_startTime);
        final routerStats = _routerServer.getStats();

        final healthMsg = '$timestamp: [HEALTH] Uptime: ${_formatDuration(uptime)}, '
            'Connections: ${routerStats.activeConnections}, '
            'Total: ${routerStats.totalConnections}, '
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
          logger?.error('Health check and logging both failed: $e, $logError');
        }
      }
    });
  }

  /// Запускает таймер статистики
  void _startStatsTimer() {
    logger?.info('📊 Статистика роутера будет выводиться каждые 30с');

    _statsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isRunning) {
        _printStats();
      }
    });
  }

  /// Выводит статистику роутера
  void _printStats() {
    final routerStats = _routerServer.getStats();
    final uptime = DateTime.now().difference(_startTime);

    print('\n📊 === СТАТИСТИКА РОУТЕРА ===');
    print('⏱️  Время работы: ${_formatDuration(uptime)}');
    print('🔗 Активных соединений: ${routerStats.activeConnections}');
    print('📈 Всего соединений: ${routerStats.totalConnections}');
    print('👥 Активных клиентов: ${routerStats.routerStats.activeClients}');
    print('📨 Обработано сообщений: ${routerStats.routerStats.totalMessages}');
    print('❌ Ошибок: ${routerStats.routerStats.errorCount}');

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
    print('// HTTP/2 gRPC клиент (высокоуровневый API)');
    print('final client = RpcHttp2Client(');
    print("  host: '${config.host}',");
    print('  port: ${config.port},');
    print(');');
    print('await client.connect();');
    print('final routerClient = RpcRouterClient(callerEndpoint: client.endpoint);');
    print('await routerClient.register(clientName: "my_client");');
    print('await routerClient.initializeP2P();');
    print('```');

    print('\n🔧 Управление:');
    print('   • Ctrl+C или SIGTERM для graceful shutdown');
    if (config.enableStats) {
      print('   • Статистика выводится каждые 30с');
    }
    print('=====================================\n');
  }

  /// Останавливает роутер сервер
  Future<void> stop() async {
    if (!_isRunning) {
      logger?.warning('Сервер уже остановлен');
      return;
    }

    logger?.info('🛑 Остановка Router Server...');

    await _cleanup();

    final uptime = DateTime.now().difference(_startTime);
    logger?.info('✅ Router Server остановлен (время работы: ${_formatDuration(uptime)})');
  }

  /// Очищает ресурсы сервера
  Future<void> _cleanup() async {
    _isRunning = false;

    // Останавливаем таймеры
    _statsTimer?.cancel();
    _statsTimer = null;

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    // Закрываем HTTP/2 сервер
    if (_http2Server != null) {
      logger?.info('Закрытие HTTP/2 сервера...');
      try {
        await _http2Server!.stop().timeout(Duration(seconds: 5));
        logger?.debug('HTTP/2 сервер закрыт');
      } catch (e) {
        logger?.warning('Ошибка закрытия HTTP/2 сервера: $e (принудительно продолжаем)');
      }
      _http2Server = null;
    }

    // Закрываем роутер сервер с таймаутом
    try {
      await _routerServer.dispose().timeout(Duration(seconds: 5));
      logger?.debug('RouterServer закрыт');
    } catch (e) {
      logger?.warning('Ошибка закрытия RouterServer: $e (принудительно продолжаем)');
    }
  }

  /// Получает примерное использование памяти
  String _getMemoryUsage() {
    try {
      // Простая проверка через ps команду
      final result = Process.runSync('ps', ['-o', 'rss=', '-p', '${pid}']);
      if (result.exitCode == 0) {
        final rss = int.tryParse(result.stdout.toString().trim()) ?? 0;
        return '${(rss / 1024).toStringAsFixed(1)}MB';
      }
    } catch (e) {
      // Игнорируем ошибки получения памяти
    }
    return 'unknown';
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

/// Статистика Router Server
class RouterServerStats {
  final bool isRunning;
  final Duration uptime;
  final int activeConnections;
  final int totalConnections;
  final int activeClients;
  final int totalMessages;
  final int errorCount;
  final String memoryUsage;

  const RouterServerStats({
    required this.isRunning,
    required this.uptime,
    required this.activeConnections,
    required this.totalConnections,
    required this.activeClients,
    required this.totalMessages,
    required this.errorCount,
    required this.memoryUsage,
  });

  factory RouterServerStats.empty() {
    return const RouterServerStats(
      isRunning: false,
      uptime: Duration.zero,
      activeConnections: 0,
      totalConnections: 0,
      activeClients: 0,
      totalMessages: 0,
      errorCount: 0,
      memoryUsage: '0MB',
    );
  }

  @override
  String toString() {
    return 'RouterServerStats('
        'running: $isRunning, '
        'uptime: $uptime, '
        'connections: $activeConnections/$totalConnections, '
        'clients: $activeClients, '
        'messages: $totalMessages, '
        'errors: $errorCount, '
        'memory: $memoryUsage'
        ')';
  }
}
