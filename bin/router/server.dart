// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import 'config.dart';

/// Роутер сервер на основе RpcServerBootstrap
///
/// Использует новую архитектуру с:
/// - IRpcServer интерфейсом для абстракции транспортов
/// - RpcServerBootstrap для production-ready обвязки
/// - Автоматическое создание Router контрактов
class RouterServer {
  final RouterConfig config;
  final IRpcServer server;
  final RpcLogger? logger;

  RpcServerBootstrap? _bootstrap;

  RouterServer({
    required this.config,
    required this.server,
    this.logger,
  });

  /// Запускает роутер сервер
  Future<void> start() async {
    final serverLogger = logger ?? RpcLogger('RouterServer');

    serverLogger.info('🚀 Запуск P2P Router Server');
    serverLogger.info('   Транспорт: ${server.runtimeType}');
    serverLogger.info('   Адрес: ${server.host}:${server.port}');
    serverLogger.info('   Daemon: ${config.daemon}');

    try {
      // Создаем контракты для роутера
      final contracts = _createRouterContracts(serverLogger);

      // Создаем bootstrap с полной production обвязкой
      _bootstrap = RpcServerBootstrap(
        appName: 'RPC Dart P2P Router',
        version: '2.0.0',
        description: 'P2P роутер для RPC сообщений',
        contracts: contracts,
        server: server,
        logger: serverLogger,
      );

      // Конвертируем RouterConfig в аргументы для bootstrap
      final args = _convertConfigToArgs();

      // Запускаем через bootstrap (включает все production фичи)
      await _bootstrap!.run(args);
    } catch (e, stackTrace) {
      serverLogger.error('💥 Ошибка запуска роутер сервера: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Останавливает роутер сервер
  Future<void> stop() async {
    // Bootstrap сам обрабатывает graceful shutdown
    // Здесь можно добавить дополнительную логику если нужно
  }

  /// Создает Router контракты
  List<RpcResponderContract> _createRouterContracts(RpcLogger logger) {
    final contracts = <RpcResponderContract>[];

    // Создаем настоящий P2P роутер контракт
    contracts.add(_createP2PRouterContract(logger));

    logger.info('✅ Создано контрактов: ${contracts.length}');
    return contracts;
  }

  /// Создает P2P роутер контракт
  RpcResponderContract _createP2PRouterContract(RpcLogger logger) {
    return RouterResponderContract(
      logger: logger.child('P2PRouter'),
    );
  }

  /// Конвертирует RouterConfig в аргументы для RpcServerBootstrap
  List<String> _convertConfigToArgs() {
    final args = <String>[];

    // Основные параметры
    args.addAll(['--host', server.host]);
    args.addAll(['--port', server.port.toString()]);

    // Логирование
    if (config.verbose) args.add('--verbose');
    if (config.quiet) args.add('--quiet');
    if (config.logFile != null) {
      args.addAll(['--log-file', config.logFile!]);
    }

    // Daemon режим
    if (config.daemon) args.add('--daemon');
    if (config.isDaemonChild) args.add('--_daemon-child');
    if (config.stopDaemon) args.add('--stop');
    if (config.statusDaemon) args.add('--status');
    if (config.reloadDaemon) args.add('--reload');
    if (config.pidFile != null) {
      args.addAll(['--pid-file', config.pidFile!]);
    }

    return args;
  }
}
