import 'dart:io';

import 'package:args/args.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:web_socket_channel/io.dart';

const String version = '1.0.0';

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
    await _startRouter(config);
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

class RouterConfig {
  final String host;
  final int port;
  final RpcLoggerLevel logLevel;
  final bool quiet;
  final bool verbose;

  const RouterConfig({
    required this.host,
    required this.port,
    required this.logLevel,
    required this.quiet,
    required this.verbose,
  });
}

bool _isVerbose = false;

ArgParser _buildArgParser() {
  return ArgParser()
    ..addOption(
      'host',
      abbr: 'h',
      defaultsTo: '0.0.0.0',
      help: 'Хост для привязки сервера',
    )
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '11111',
      help: 'Порт для прослушивания',
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
      'help',
      help: 'Показать справку',
    )
    ..addFlag(
      'version',
      help: 'Показать версию',
    );
}

RouterConfig _parseConfig(ArgResults argResults) {
  final host = argResults['host'] as String;
  final portStr = argResults['port'] as String;
  final logLevelStr = argResults['log-level'] as String;
  final quiet = argResults['quiet'] as bool;
  final verbose = argResults['verbose'] as bool;

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

  return RouterConfig(
    host: host,
    port: port,
    logLevel: logLevel,
    quiet: quiet,
    verbose: verbose,
  );
}

void _printUsage(ArgParser parser) {
  print('🚀 RPC Dart Router - WebSocket роутер для RPC вызовов\n');
  print('Использование: rpc_dart_router [options]\n');
  print('Опции:');
  print(parser.usage);
  print('\nПримеры:');
  print('  rpc_dart_router                           # Запуск с настройками по умолчанию');
  print('  rpc_dart_router -h localhost -p 8080     # Запуск на localhost:8080');
  print('  rpc_dart_router --quiet                   # Тихий режим');
  print('  rpc_dart_router -v --log-level debug     # Подробный режим с debug логами');
}

Future<void> _startRouter(RouterConfig config) async {
  // Настраиваем глобальный уровень логирования
  RpcLoggerSettings.setDefaultMinLogLevel(config.logLevel);

  // Создаем основной логгер роутера
  final logger = RpcLogger('RouterCLI', label: 'CLI');

  await logger.info('Запускаем RPC Dart Router...');
  await logger.debug('Конфигурация: ${config.host}:${config.port}, log: ${config.logLevel.name}');

  try {
    // Запускаем WebSocket сервер
    final server = await HttpServer.bind(config.host, config.port);
    await logger.info('Роутер запущен на ws://${config.host}:${config.port}');

    // Создаем единый RouterContract для всех соединений
    final routerContract = RouterResponderContract();
    await logger.debug('RouterContract создан');

    int connectionCount = 0;

    await for (final request in server) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        connectionCount++;
        final connectionId = connectionCount;

        await logger.debug('Получен WebSocket запрос от ${request.connectionInfo?.remoteAddress}');

        final webSocket = await WebSocketTransformer.upgrade(request);

        // Создаем WebSocket канал и транспорт для сервера
        final channel = IOWebSocketChannel(webSocket);
        final transport = RpcWebSocketResponderTransport(
          channel,
          logger: config.logLevel == RpcLoggerLevel.debug
              ? RpcLogger('ServerTransport#$connectionId')
              : null,
        );

        // Создаем RPC эндпоинт для каждого соединения
        final endpoint =
            RpcResponderEndpoint(transport: transport, debugLabel: 'RouterEndpoint#$connectionId');

        // Регистрируем общий роутер контракт
        endpoint.registerServiceContract(routerContract);

        await logger
            .info('Новое подключение #$connectionId: ${request.connectionInfo?.remoteAddress}');
        if (config.verbose) {
          await logger.debug('Статистика роутера: ${routerContract.routerImpl.stats}');
        }

        // Мониторинг закрытия соединения через WebSocket события
        webSocket.done.then((_) async {
          await logger.info('Клиент #$connectionId отключился');
          endpoint.close();
        }).catchError((error) async {
          await logger.warning('Ошибка при отключении клиента #$connectionId: $error');
          endpoint.close();
        });

        // Запускаем endpoint
        endpoint.start();
        await logger.debug('Endpoint #$connectionId запущен');
      } else {
        await logger
            .warning('Получен не-WebSocket запрос от ${request.connectionInfo?.remoteAddress}');
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('WebSocket connections only')
          ..close();
      }
    }
  } catch (e, stackTrace) {
    await logger.error('Ошибка запуска роутера',
        error: e, stackTrace: config.verbose ? stackTrace : null);
    exit(1);
  }
}
