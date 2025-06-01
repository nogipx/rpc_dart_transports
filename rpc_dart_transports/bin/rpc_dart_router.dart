// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:rpc_dart_transports/src/http2/rpc_http2_responder_transport.dart';
import 'package:http2/http2.dart' as http2;

const String version = '2.0.0';

void main(List<String> arguments) async {
  // Запускаем в защищенной зоне для перехвата всех ошибок
  runZonedGuarded<void>(
    () async {
      await _mainWithErrorHandling(arguments);
    },
    (error, stackTrace) {
      // Глобальный обработчик unhandled exceptions
      print('🚨 === НЕОБРАБОТАННАЯ ОШИБКА ===');
      print('❌ Тип: ${error.runtimeType}');
      print('📝 Ошибка: $error');

      // Специальная обработка HTTP/2 ошибок
      if (error.toString().contains('HTTP/2 error') ||
          error.toString().contains('Connection is being forcefully terminated')) {
        print(
            '🔗 HTTP/2 соединение было принудительно закрыто (это нормально при отключении клиентов)');
        print('♻️  Роутер продолжает работу...');
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

  const RouterConfig({
    this.host = '0.0.0.0',
    this.port = 11112, // HTTP/2 порт по умолчанию
    this.enableStats = true,
    this.logLevel = 'info',
    this.verbose = false,
    this.clientTimeoutSeconds = 300,
  });
}

bool _isVerbose = false;

/// Основной класс CLI роутера (только HTTP/2)
class RouterCLI {
  final RouterConfig config;
  final RpcLogger logger;

  /// Транспорт-агностичный роутер сервер
  late final RpcRouterServer _routerServer;

  /// HTTP/2 сервер
  RpcHttp2Server? _http2Server;

  /// Подписки для HTTP/2 соединений
  final List<StreamSubscription> _http2Subscriptions = [];

  /// Таймер статистики
  Timer? _statsTimer;

  /// Время старта
  late final DateTime _startTime;

  RouterCLI(this.config) : logger = RpcLogger('RouterCLI') {
    // Настраиваем глобальный уровень логирования
    RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.info);
  }

  /// Запускает HTTP/2 роутер
  Future<void> start() async {
    _startTime = DateTime.now();

    logger.info('🚀 Запуск RPC Dart Router v$version (HTTP/2 gRPC)');
    logger.info('Конфигурация:');
    logger.info('  • Хост: ${config.host}');
    logger.info('  • Порт: ${config.port}');
    logger.info('  • Транспорт: HTTP/2 gRPC');
    logger.info('  • Логирование: ${config.logLevel}');
    logger.info('  • Статистика: ${config.enableStats ? 'включена' : 'отключена'}');

    try {
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

      // Показываем сводку
      _printStartupSummary();
    } catch (e, stackTrace) {
      logger.error('Критическая ошибка запуска роутера',
          error: e, stackTrace: config.verbose ? stackTrace : null);
      exit(1);
    }
  }

  /// Запускает HTTP/2 сервер с настоящим gRPC-style протоколом
  Future<void> _startHttp2Server() async {
    logger.info('🚀 Запуск HTTP/2 gRPC сервера на ${config.host}:${config.port}');

    // Используем новый удобный API!
    _http2Server = await RpcHttp2ResponderTransport.bind(
      host: config.host,
      port: config.port,
      logger: config.verbose ? logger.child('Http2Server') : null,
    );

    logger.info('🚀 HTTP/2 gRPC сервер запущен на http://${config.host}:${config.port}');

    // Слушаем новые транспорты для каждого соединения
    final subscription = _http2Server!.transports.listen(
      (transport) => _handleHttp2Transport(transport),
      onError: (error, stackTrace) {
        logger.error('Ошибка HTTP/2 сервера',
            error: error, stackTrace: config.verbose ? stackTrace : null);
      },
      onDone: () {
        logger.info('HTTP/2 сервер остановлен');
      },
    );

    _http2Subscriptions.add(subscription);
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

    // Останавливаем таймер статистики
    _statsTimer?.cancel();
    _statsTimer = null;

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
        await _http2Server!.close().timeout(Duration(seconds: 5));
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

  _isVerbose = verbose;

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
  print('\nТранспорт:');
  print('  HTTP/2 gRPC     Современный бинарный протокол с мультиплексингом');
  print(
      '                  Поддерживает все типы RPC вызовов: unary, client/server/bidirectional streams');
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
