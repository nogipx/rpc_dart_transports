// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:web_socket_channel/io.dart';

const String version = '2.0.0';

void main(List<String> arguments) async {
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
    await routerCli.stop();
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
  final int websocketPort;
  final int http2Port;
  final List<String> transports;
  final bool enableStats;
  final String logLevel;
  final bool verbose;
  final int clientTimeoutSeconds;

  const RouterConfig({
    this.host = '0.0.0.0',
    this.websocketPort = 11111,
    this.http2Port = 11112,
    this.transports = const ['http2'], // HTTP/2 по умолчанию
    this.enableStats = true, // Включаем статистику по умолчанию
    this.logLevel = 'info',
    this.verbose = false,
    this.clientTimeoutSeconds = 300,
  });
}

/// Типы поддерживаемых транспортов
enum TransportType {
  websocket,
  http2,
}

bool _isVerbose = false;

/// Основной класс CLI роутера
class RouterCLI {
  final RouterConfig config;
  final RpcLogger logger;

  /// Транспорт-агностичный роутер сервер
  late final RpcRouterServer _routerServer;

  /// Активные серверы по типам транспорта
  final Map<TransportType, HttpServer> _servers = {};

  /// Таймер статистики
  Timer? _statsTimer;

  /// Время старта
  late final DateTime _startTime;

  RouterCLI(this.config) : logger = RpcLogger('RouterCLI') {
    // Настраиваем глобальный уровень логирования
    RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.info);
  }

  /// Запускает роутер со всеми настроенными транспортами
  Future<void> start() async {
    _startTime = DateTime.now();

    logger.info('🚀 Запуск RPC Dart Router v$version');
    logger.info('Конфигурация:');
    logger.info('  • Хост: ${config.host}');
    logger.info('  • Транспорты: ${config.transports.join(', ')}');
    logger.info('  • Логирование: ${config.logLevel}');
    logger.info('  • Статистика: ${config.enableStats ? 'включена' : 'отключена'}');

    try {
      // Создаем транспорт-агностичный роутер
      _routerServer = RpcRouterServer(
        logger: logger.child('RouterServer'),
      );

      // Запускаем все указанные транспорты
      for (final transport in config.transports) {
        await _startTransport(transport);
      }

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

  /// Запускает конкретный транспорт
  Future<void> _startTransport(String transport) async {
    switch (transport) {
      case 'websocket':
        await _startWebSocketServer();
        break;
      case 'http2':
        await _startHttp2Server();
        break;
      default:
        throw FormatException('Неизвестный транспорт: $transport');
    }
  }

  /// Запускает WebSocket сервер
  Future<void> _startWebSocketServer() async {
    final server = await HttpServer.bind(config.host, config.websocketPort);
    _servers[TransportType.websocket] = server;

    logger.info('🌐 WebSocket сервер запущен на ws://${config.host}:${config.websocketPort}');

    server.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        await _handleWebSocketConnection(request);
      } else {
        await _handleNonWebSocketRequest(request);
      }
    });
  }

  /// Запускает HTTP/2 сервер
  Future<void> _startHttp2Server() async {
    final server = await HttpServer.bind(config.host, config.http2Port);
    _servers[TransportType.http2] = server;

    logger.info('🚀 HTTP/2 сервер запущен на http://${config.host}:${config.http2Port}');

    server.listen((request) async {
      await _handleHttp2Connection(request);
    });
  }

  /// Обрабатывает WebSocket соединение
  Future<void> _handleWebSocketConnection(HttpRequest request) async {
    try {
      final webSocket = await WebSocketTransformer.upgrade(request);
      final clientAddress = request.connectionInfo?.remoteAddress.toString() ?? 'unknown';

      logger.debug('🔗 WebSocket подключение: $clientAddress');

      // Создаем WebSocket транспорт
      final channel = IOWebSocketChannel(webSocket);
      final transport = RpcWebSocketResponderTransport(
        channel,
        logger: config.verbose ? logger.child('WSTransport') : null,
      );

      // Создаем соединение через RouterServer
      final connectionId = _routerServer.createConnection(
        transport: transport,
        connectionLabel: 'ws_${clientAddress}_${DateTime.now().millisecondsSinceEpoch}',
        clientAddress: clientAddress,
      );

      logger.info('✅ WebSocket клиент подключен: $connectionId');

      // Мониторим завершение соединения
      webSocket.done.then((_) async {
        logger.info('🔌 WebSocket клиент отключился: $connectionId');
        await _routerServer.closeConnection(connectionId, reason: 'WebSocket closed');
      }).catchError((error) async {
        logger.warning('❌ Ошибка WebSocket соединения $connectionId: $error');
        await _routerServer.closeConnection(connectionId, reason: 'WebSocket error: $error');
      });
    } catch (e, stackTrace) {
      logger.error('Ошибка WebSocket соединения',
          error: e, stackTrace: config.verbose ? stackTrace : null);
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Обрабатывает не-WebSocket запрос к WebSocket серверу
  Future<void> _handleNonWebSocketRequest(HttpRequest request) async {
    logger.debug('Получен не-WebSocket запрос: ${request.method} ${request.uri}');

    // Возвращаем информацию о роутере
    final stats = _routerServer.getStats();
    final uptime = DateTime.now().difference(_startTime);

    final info = {
      'service': 'RPC Dart Router',
      'version': version,
      'transport': 'WebSocket',
      'uptime_seconds': uptime.inSeconds,
      'active_connections': stats.activeConnections,
      'total_connections': stats.totalConnections,
      'endpoints': {
        'websocket': 'ws://${config.host}:${config.websocketPort}',
        if (config.transports.contains('http2'))
          'http2': 'http://${config.host}:${config.http2Port}',
      }
    };

    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(info))
      ..close();
  }

  /// Обрабатывает HTTP/2 соединение
  Future<void> _handleHttp2Connection(HttpRequest request) async {
    try {
      final clientAddress = request.connectionInfo?.remoteAddress.toString() ?? 'unknown';

      logger.debug('🔗 HTTP/2 запрос: ${request.method} ${request.uri} от $clientAddress');

      // Пока что HTTP/2 транспорт требует более сложной настройки
      // Возвращаем информацию о доступности
      final stats = _routerServer.getStats();
      final uptime = DateTime.now().difference(_startTime);

      final info = {
        'service': 'RPC Dart Router',
        'version': version,
        'transport': 'HTTP/2',
        'status': 'available',
        'note': 'HTTP/2 router requires proper gRPC-style connection setup',
        'uptime_seconds': uptime.inSeconds,
        'active_connections': stats.activeConnections,
        'suggestion': 'Use RouterClient with RpcHttp2CallerTransport for proper connection',
        'websocket_endpoint': 'ws://${config.host}:${config.websocketPort}',
      };

      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(info))
        ..close();
    } catch (e, stackTrace) {
      logger.error('Ошибка HTTP/2 соединения',
          error: e, stackTrace: config.verbose ? stackTrace : null);

      request.response
        ..statusCode = 500
        ..write('Internal server error')
        ..close();
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
    print('\n🎉 === РОУТЕР ЗАПУЩЕН ===');
    print('📡 Доступные endpoints:');

    for (final transport in config.transports) {
      switch (transport) {
        case 'websocket':
          print('   • WebSocket: ws://${config.host}:${config.websocketPort}');
          break;
        case 'http2':
          print('   • HTTP/2: http://${config.host}:${config.http2Port}');
          break;
      }
    }

    print('\n💡 Примеры подключения:');
    if (config.transports.contains('websocket')) {
      print('```dart');
      print('// WebSocket клиент');
      print('final transport = RpcWebSocketCallerTransport.connect(');
      print("  Uri.parse('ws://${config.host}:${config.websocketPort}'),");
      print(');');
      print('final endpoint = RpcCallerEndpoint(transport: transport);');
      print('final client = RouterClient(callerEndpoint: endpoint);');
      print('```');
    }

    if (config.transports.contains('http2')) {
      print('```dart');
      print('// HTTP/2 клиент');
      print('final transport = await RpcHttp2CallerTransport.connect(');
      print("  host: '${config.host}',");
      print('  port: ${config.http2Port},');
      print(');');
      print('final endpoint = RpcCallerEndpoint(transport: transport);');
      print('final client = RouterClient(callerEndpoint: endpoint);');
      print('```');
    }

    print('\n🔧 Управление:');
    print('   • Ctrl+C или SIGTERM для graceful shutdown');
    print('   • GET /health для проверки состояния');
    if (config.enableStats) {
      print('   • Статистика выводится каждые 30с');
    }
    print('========================\n');
  }

  /// Останавливает роутер
  Future<void> stop() async {
    logger.info('🛑 Остановка роутера...');

    // Останавливаем таймер статистики
    _statsTimer?.cancel();

    // Закрываем все серверы
    for (final entry in _servers.entries) {
      logger.info('Закрытие ${entry.key.name} сервера...');
      await entry.value.close();
    }

    // Закрываем роутер сервер
    await _routerServer.dispose();

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
      help: 'Хост для привязки сервера',
    )
    ..addOption(
      'websocket-port',
      abbr: 'p',
      defaultsTo: '11111',
      help: 'Порт для WebSocket сервера',
    )
    ..addOption(
      'http2-port',
      help: 'Порт для HTTP/2 сервера (по умолчанию port + 1)',
    )
    ..addMultiOption(
      'transport',
      abbr: 't',
      defaultsTo: ['http2'],
      allowed: ['websocket', 'http2'],
      help: 'Типы транспортов для запуска',
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
  final websocketPortStr = argResults['websocket-port'] as String;
  final http2PortStr = argResults['http2-port'] as String?;
  final transportStrs = argResults['transport'] as List<String>;
  final logLevelStr = argResults['log-level'] as String;
  final quiet = argResults['quiet'] as bool;
  final verbose = argResults['verbose'] as bool;
  final enableStats = argResults['stats'] as bool;
  final clientTimeoutStr = argResults['client-timeout'] as String;

  _isVerbose = verbose;

  // Валидация порта
  final websocketPort = int.tryParse(websocketPortStr);
  if (websocketPort == null || websocketPort < 1 || websocketPort > 65535) {
    throw FormatException('Порт должен быть числом от 1 до 65535, получен: $websocketPortStr');
  }

  // Валидация HTTP/2 порта
  int? http2Port;
  if (http2PortStr != null) {
    http2Port = int.tryParse(http2PortStr);
    if (http2Port == null || http2Port < 1 || http2Port > 65535) {
      throw FormatException('HTTP/2 порт должен быть числом от 1 до 65535, получен: $http2PortStr');
    }
  }

  // Конфликт флагов
  if (quiet && verbose) {
    throw FormatException('Нельзя использовать --quiet и --verbose одновременно');
  }

  // Парсинг транспортов
  final transports = <String>[];
  for (final transportStr in transportStrs) {
    switch (transportStr) {
      case 'websocket':
        transports.add('websocket');
        break;
      case 'http2':
        transports.add('http2');
        break;
      default:
        throw FormatException('Неизвестный транспорт: $transportStr');
    }
  }

  if (transports.isEmpty) {
    throw FormatException('Должен быть указан хотя бы один транспорт');
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
    websocketPort: websocketPort,
    http2Port: http2Port ?? (websocketPort + 1),
    transports: transports,
    enableStats: enableStats,
    logLevel: logLevel.name,
    verbose: verbose,
    clientTimeoutSeconds: clientTimeout,
  );
}

/// Показывает справку
void _printUsage(ArgParser parser) {
  print('🚀 RPC Dart Router v$version - Транспорт-агностичный роутер для RPC вызовов\n');
  print('Использование: rpc_dart_router [options]\n');
  print('Опции:');
  print(parser.usage);
  print('\nПримеры:');
  print('  rpc_dart_router                                    # HTTP/2 на порту 11112');
  print('  rpc_dart_router -t websocket -t http2              # Оба транспорта');
  print('  rpc_dart_router -h localhost --websocket-port 8080 # Настройка хоста и порта');
  print('  rpc_dart_router --http2-port 8443                  # Явный порт для HTTP/2');
  print('  rpc_dart_router --quiet                            # Тихий режим');
  print('  rpc_dart_router -v --log-level debug               # Детальная отладка');
  print('  rpc_dart_router --no-stats                         # Без статистики');
  print('  rpc_dart_router --client-timeout 300               # Таймаут 5 минут');
  print('\nТранспорты:');
  print('  websocket  WebSocket транспорт');
  print('  http2      HTTP/2 gRPC-style транспорт (по умолчанию)');
}

/// Ожидает сигнал завершения (Ctrl+C, SIGTERM)
Future<void> _waitForShutdownSignal() async {
  final completer = Completer<void>();

  // Обрабатываем SIGINT (Ctrl+C)
  ProcessSignal.sigint.watch().listen((signal) {
    print('\n🛑 Получен сигнал SIGINT, завершение работы...');
    if (!completer.isCompleted) {
      completer.complete();
    }
  });

  // Обрабатываем SIGTERM
  ProcessSignal.sigterm.watch().listen((signal) {
    print('\n🛑 Получен сигнал SIGTERM, завершение работы...');
    if (!completer.isCompleted) {
      completer.complete();
    }
  });

  await completer.future;
}
