// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import 'config.dart';
import 'server.dart';

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
  }

  /// Запускает CLI приложение
  Future<void> run() async {
    try {
      // Создаем HTTP/2 сервер с контрактами
      final contracts = _createRouterContracts();
      final http2Server = RpcHttp2Server.createWithContracts(
        port: config.port,
        host: config.host,
        contracts: contracts,
        logger: RpcLogger('RouterCLI'),
      );

      // Создаем и запускаем сервер
      _server = RouterServer(
        config: config,
        server: http2Server,
        logger: RpcLogger('RouterCLI'),
      );

      await _server!.start();

      // Ждем завершения (RpcServerBootstrap сам обрабатывает сигналы)
      // Сервер будет работать до получения сигнала завершения
    } catch (e, stackTrace) {
      print('❌ Ошибка запуска роутера: $e');
      if (config.verbose) {
        print('Stack trace: $stackTrace');
      }
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
        'host',
        abbr: 'h',
        defaultsTo: '0.0.0.0',
        help: 'Хост для привязки сервера',
      )
      ..addOption(
        'port',
        abbr: 'p',
        defaultsTo: '8080',
        help: 'Порт для сервера',
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

  /// Создает Router контракты
  List<RpcResponderContract> _createRouterContracts() {
    final contracts = <RpcResponderContract>[];

    // Создаем настоящий P2P роутер контракт
    contracts.add(_createP2PRouterContract());

    return contracts;
  }

  /// Создает P2P роутер контракт
  RpcResponderContract _createP2PRouterContract() {
    return RouterResponderContract(
      logger: RpcLogger('RouterCLI').child('P2PRouter'),
    );
  }

  /// Показывает справку
  void _printUsage(ArgParser parser) {
    print('🚀 RPC Dart Router v$version - P2P роутер для RPC сообщений\n');
    print('Использование: rpc_dart_router [options]\n');
    print('Опции:');
    print(parser.usage);
    print('\nПримеры:');
    print('  rpc_dart_router                           # Запуск на порту 8080');
    print('  rpc_dart_router -p 8081                   # Запуск на порту 8081');
    print('  rpc_dart_router -h 192.168.1.100          # Запуск на определенном IP');
    print('  rpc_dart_router --verbose                 # Подробное логирование');
    print('  rpc_dart_router --quiet                   # Тихий режим');
    print('\nДемон режим:');
    print('  rpc_dart_router -d                        # Запуск в фоновом режиме');
    print('  rpc_dart_router --status                  # Проверить статус daemon');
    print('  rpc_dart_router --stop                    # Остановить daemon');
    print('  rpc_dart_router --reload                  # Перезагрузить daemon');
    print('\nP2P функции:');
    print('  • Регистрация клиентов в роутере');
    print('  • Unicast, multicast, broadcast сообщения');
    print('  • Request-response между клиентами');
    print('  • Подписка на события роутера');
    print('  • Автоматический мониторинг клиентов');
    print('  • Graceful shutdown через SIGTERM');
  }
}
