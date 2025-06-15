// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:args/args.dart';
import 'package:rpc_dart/rpc_dart.dart';

/// Конфигурация роутера
///
/// Поддерживает загрузку из:
/// - Аргументов командной строки
/// - Значений по умолчанию
class RouterConfig {
  // === СЕТЬ ===
  final String host;
  final int port;

  // === ЛОГИРОВАНИЕ ===
  final RpcLoggerLevel logLevel;
  final bool verbose;
  final bool quiet;
  final String? logFile;

  // === DAEMON ===
  final bool daemon;
  final bool isDaemonChild;
  final bool stopDaemon;
  final bool statusDaemon;
  final bool reloadDaemon;
  final String? pidFile;

  const RouterConfig({
    // Сеть
    this.host = '0.0.0.0',
    this.port = 8080,

    // Логирование
    this.logLevel = RpcLoggerLevel.info,
    this.verbose = false,
    this.quiet = false,
    this.logFile,

    // Daemon
    this.daemon = false,
    this.isDaemonChild = false,
    this.stopDaemon = false,
    this.statusDaemon = false,
    this.reloadDaemon = false,
    this.pidFile,
  });

  /// Создает конфигурацию из аргументов командной строки
  static Future<RouterConfig> fromArgs(ArgResults args) async {
    return RouterConfig(
      host: args['host'] as String? ?? '0.0.0.0',
      port: int.tryParse(args['port'] as String? ?? '8080') ?? 8080,
      logLevel: _parseLogLevel(args['log-level'] as String?) ?? RpcLoggerLevel.info,
      verbose: args['verbose'] as bool? ?? false,
      quiet: args['quiet'] as bool? ?? false,
      logFile: args['log-file'] as String?,
      daemon: args['daemon'] as bool? ?? false,
      isDaemonChild: args['_daemon-child'] as bool? ?? false,
      stopDaemon: args['stop'] as bool? ?? false,
      statusDaemon: args['status'] as bool? ?? false,
      reloadDaemon: args['reload'] as bool? ?? false,
      pidFile: args['pid-file'] as String?,
    );
  }

  /// Валидирует конфигурацию
  void validate() {
    if (port < 1 || port > 65535) {
      throw ArgumentError('Порт должен быть от 1 до 65535, получен: $port');
    }

    if (quiet && verbose) {
      throw ArgumentError('Нельзя использовать quiet и verbose одновременно');
    }
  }

  /// Возвращает пути к файлам по умолчанию
  String get defaultPidFile => pidFile ?? '/tmp/rpc_dart_router.pid';
  String get defaultLogFile => logFile ?? '/tmp/rpc_dart_router.log';

  // === УТИЛИТЫ ДЛЯ ПАРСИНГА ===

  static RpcLoggerLevel? _parseLogLevel(String? level) {
    if (level == null) return null;

    switch (level.toLowerCase()) {
      case 'debug':
        return RpcLoggerLevel.debug;
      case 'info':
        return RpcLoggerLevel.info;
      case 'warning':
        return RpcLoggerLevel.warning;
      case 'error':
        return RpcLoggerLevel.error;
      case 'critical':
        return RpcLoggerLevel.critical;
      case 'none':
        return RpcLoggerLevel.none;
      default:
        return null;
    }
  }

  @override
  String toString() {
    return 'RouterConfig('
        'host: $host, '
        'port: $port, '
        'logLevel: ${logLevel.name}, '
        'daemon: $daemon'
        ')';
  }
}
