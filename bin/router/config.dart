// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:io';

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
  final int maxConnections;

  // === ТРАНСПОРТЫ ===
  final bool enableHttp2;
  final Map<String, dynamic> http2Options;

  // === ЛОГИРОВАНИЕ ===
  final RpcLoggerLevel logLevel;
  final bool verbose;
  final bool quiet;
  final String? logFile;
  final bool logToFile;
  final bool logToConsole;

  // === МОНИТОРИНГ ===
  final bool enableStats;
  final bool enableMetrics;
  final int metricsPort;
  final bool enableHealthCheck;
  final Duration clientTimeout;
  final Duration healthCheckInterval;

  // === DAEMON ===
  final bool daemon;
  final bool isDaemonChild;
  final bool stopDaemon;
  final bool statusDaemon;
  final bool reloadDaemon;
  final String? pidFile;

  // === ПРОИЗВОДИТЕЛЬНОСТЬ ===
  final int workerThreads;
  final int bufferSize;
  final bool enableCompression;

  // === БЕЗОПАСНОСТЬ ===
  final bool enableTls;
  final String? certFile;
  final String? keyFile;
  final List<String> allowedHosts;

  // === ДОПОЛНИТЕЛЬНЫЕ ОПЦИИ ===
  final Map<String, dynamic> extensions;

  const RouterConfig({
    // Сеть
    this.host = '0.0.0.0',
    this.port = 8080,
    this.maxConnections = 1000,

    // Транспорты
    this.enableHttp2 = true,
    this.http2Options = const {},

    // Логирование
    this.logLevel = RpcLoggerLevel.info,
    this.verbose = false,
    this.quiet = false,
    this.logFile,
    this.logToFile = false,
    this.logToConsole = true,

    // Мониторинг
    this.enableStats = true,
    this.enableMetrics = false,
    this.metricsPort = 9090,
    this.enableHealthCheck = true,
    this.clientTimeout = const Duration(minutes: 5),
    this.healthCheckInterval = const Duration(seconds: 30),

    // Daemon
    this.daemon = false,
    this.isDaemonChild = false,
    this.stopDaemon = false,
    this.statusDaemon = false,
    this.reloadDaemon = false,
    this.pidFile,

    // Производительность
    this.workerThreads = 0, // 0 = auto
    this.bufferSize = 8192,
    this.enableCompression = true,

    // Безопасность
    this.enableTls = false,
    this.certFile,
    this.keyFile,
    this.allowedHosts = const [],

    // Дополнительные
    this.extensions = const {},
  });

  /// Создает конфигурацию из аргументов командной строки
  static Future<RouterConfig> fromArgs(ArgResults args) async {
    return RouterConfig(
      host: args['host'] as String? ?? '0.0.0.0',
      port: int.tryParse(args['port'] as String? ?? '8080') ?? 8080,
      maxConnections: int.tryParse(args['max-connections'] as String? ?? '1000') ?? 1000,
      enableHttp2: true, // Всегда включен для gRPC
      http2Options: const {},
      logLevel: _parseLogLevel(args['log-level'] as String?) ?? RpcLoggerLevel.info,
      verbose: args['verbose'] as bool? ?? false,
      quiet: args['quiet'] as bool? ?? false,
      logFile: args['log-file'] as String?,
      logToFile: args['log-file'] != null,
      logToConsole: true,
      enableStats: args['stats'] as bool? ?? true,
      enableMetrics: args['metrics'] as bool? ?? false,
      metricsPort: int.tryParse(args['metrics-port'] as String? ?? '9090') ?? 9090,
      enableHealthCheck: args['health-check'] as bool? ?? true,
      clientTimeout:
          Duration(seconds: int.tryParse(args['client-timeout'] as String? ?? '300') ?? 300),
      daemon: args['daemon'] as bool? ?? false,
      isDaemonChild: args['_daemon-child'] as bool? ?? false,
      stopDaemon: args['stop'] as bool? ?? args['daemon-stop'] as bool? ?? false,
      statusDaemon: args['status'] as bool? ?? args['daemon-status'] as bool? ?? false,
      reloadDaemon: args['reload'] as bool? ?? args['daemon-reload'] as bool? ?? false,
      pidFile: args['pid-file'] as String?,
      workerThreads: int.tryParse(args['worker-threads'] as String? ?? '0') ?? 0,
      enableTls: args['tls'] as bool? ?? false,
      certFile: args['cert-file'] as String?,
      keyFile: args['key-file'] as String?,
    );
  }

  /// Валидирует конфигурацию
  void validate() {
    if (port < 1 || port > 65535) {
      throw ArgumentError('Порт должен быть от 1 до 65535, получен: $port');
    }

    if (maxConnections < 1) {
      throw ArgumentError('maxConnections должно быть положительным числом');
    }

    if (metricsPort < 1 || metricsPort > 65535) {
      throw ArgumentError('Порт метрик должен быть от 1 до 65535');
    }

    if (enableTls) {
      if (certFile == null || keyFile == null) {
        throw ArgumentError('Для TLS необходимы certFile и keyFile');
      }
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

  static Duration? _parseDuration(dynamic value) {
    if (value == null) return null;

    if (value is int) {
      return Duration(seconds: value);
    }

    if (value is String) {
      final seconds = int.tryParse(value);
      return seconds != null ? Duration(seconds: seconds) : null;
    }

    return null;
  }

  @override
  String toString() {
    return 'RouterConfig('
        'host: $host, '
        'port: $port, '
        'maxConnections: $maxConnections, '
        'logLevel: ${logLevel.name}, '
        'daemon: $daemon, '
        'enableStats: $enableStats, '
        'enableMetrics: $enableMetrics'
        ')';
  }
}

/// Генерирует пример использования CLI
String generateExampleConfig() {
  return '''# RPC Dart Router - Примеры использования CLI
# Все настройки задаются только через параметры командной строки

# === БАЗОВЫЕ ПРИМЕРЫ ===

# Запуск с настройками по умолчанию (порт 8080)
dart run bin/rpc_dart_router.dart

# Запуск на конкретном хосте и порту
dart run bin/rpc_dart_router.dart --host 127.0.0.1 --port 9090

# Запуск с подробным логированием
dart run bin/rpc_dart_router.dart --verbose --log-level debug

# === DAEMON РЕЖИМ ===

# Запуск в daemon режиме
dart run bin/rpc_dart_router.dart --daemon-start

# Статус daemon
dart run bin/rpc_dart_router.dart --daemon-status

# Остановка daemon
dart run bin/rpc_dart_router.dart --daemon-stop

# === МОНИТОРИНГ ===

# Включить метрики Prometheus на порту 9090
dart run bin/rpc_dart_router.dart --metrics --metrics-port 9090

# Отключить статистику
dart run bin/rpc_dart_router.dart --no-stats

# === ПРОИЗВОДИТЕЛЬНОСТЬ ===

# Настройка максимального количества соединений
dart run bin/rpc_dart_router.dart --max-connections 5000

# Настройка рабочих потоков
dart run bin/rpc_dart_router.dart --worker-threads 4

# === БЕЗОПАСНОСТЬ ===

# Включить TLS
dart run bin/rpc_dart_router.dart --tls --cert-file /path/to/cert.pem --key-file /path/to/key.pem

# === ПОЛНЫЙ ПРИМЕР ===

dart run bin/rpc_dart_router.dart \\
  --host 0.0.0.0 \\
  --port 8080 \\
  --max-connections 2000 \\
  --verbose \\
  --log-level info \\
  --log-file /var/log/rpc_router.log \\
  --metrics \\
  --metrics-port 9090 \\
  --worker-threads 0
''';
}
