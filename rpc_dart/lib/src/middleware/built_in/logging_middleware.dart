// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:developer' as dev;
import 'package:rpc_dart/rpc_dart.dart'
    show RpcMethodContext, SimpleRpcMiddleware, RpcDataDirection;

/// Уровень логирования
enum LogLevel {
  /// Детальная отладочная информация
  debug,

  /// Информационные сообщения
  info,

  /// Предупреждения (не критичные ошибки)
  warning,

  /// Ошибки
  error,

  /// Критичные ошибки
  critical,
}

/// Формат записи лога
typedef LogRecord = ({
  String message,
  LogLevel level,
  DateTime timestamp,
  Object? error,
  StackTrace? stackTrace,
});

/// Функция для логирования
typedef LoggerFunction = void Function(LogRecord record);

/// Middleware для логирования RPC-вызовов
class LoggingMiddleware implements SimpleRpcMiddleware {
  /// Идентификатор middleware (используется в логах)
  final String id;

  /// Минимальный уровень логирования
  final LogLevel _minLevel;

  /// Функция для логирования
  final LoggerFunction _logger;

  /// Стандартная функция логирования, использующая dart:developer
  static void _defaultLogger(LogRecord record) {
    final levelStr = record.level.toString().split('.').last.toUpperCase();

    dev.log(
      '[$levelStr] ${record.message}',
      time: record.timestamp,
      name: 'RpcDart',
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  /// Создает middleware для логирования
  ///
  /// [id] - идентификатор middleware
  /// [logger] - функция для логирования, если null используется dart:developer
  /// [minLevel] - минимальный уровень логирования
  LoggingMiddleware({
    this.id = '',
    LoggerFunction? logger,
    LogLevel minLevel = LogLevel.info,
  })  : _logger = logger ?? _defaultLogger,
        _minLevel = minLevel;

  /// Логирует сообщение с указанным уровнем
  void _log(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Проверяем, нужно ли логировать данный уровень
    if (level.index < _minLevel.index) {
      return;
    }

    final record = (
      message: _formatMessage(message),
      level: level,
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
    );

    _logger(record);
  }

  /// Форматирует сообщение, добавляя префикс с ID
  String _formatMessage(String message) {
    final prefix = id.isEmpty ? 'LoggingMiddleware' : 'LoggingMiddleware[$id]';
    return '$prefix: $message';
  }

  /// Логирует сообщение c детальной информацией
  void _debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, level: LogLevel.debug, error: error, stackTrace: stackTrace);
  }

  /// Логирует информационное сообщение
  void _info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, level: LogLevel.info, error: error, stackTrace: stackTrace);
  }

  /// Логирует предупреждение
  // ignore: unused_element
  void _warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message,
        level: LogLevel.warning, error: error, stackTrace: stackTrace);
  }

  /// Логирует ошибку
  void _error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(message, level: LogLevel.error, error: error, stackTrace: stackTrace);
  }

  @override
  Future<dynamic> onRequest(
    String serviceName,
    String methodName,
    dynamic payload,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    _info('[REQ ${direction.symbol}] $serviceName.$methodName: $payload');
    return Future.value(payload);
  }

  @override
  Future<dynamic> onResponse(
    String serviceName,
    String methodName,
    dynamic response,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    _info('[RES ${direction.symbol}] $serviceName.$methodName: $response');
    return Future.value(response);
  }

  @override
  Future<dynamic> onError(
    String serviceName,
    String methodName,
    dynamic error,
    StackTrace? stackTrace,
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    _error(
      '[ERR] $serviceName.$methodName',
      error: error,
      stackTrace: stackTrace,
    );
    return Future.value(error);
  }

  @override
  Future<dynamic> onStreamData(
    String serviceName,
    String methodName,
    dynamic data,
    String streamId,
    RpcDataDirection direction,
  ) {
    _debug(
      '[STR ${direction.symbol}] $serviceName.$methodName[$streamId]: $data',
    );
    return Future.value(data);
  }

  @override
  Future<void> onStreamEnd(
    String serviceName,
    String methodName,
    String streamId,
  ) {
    _debug('[STR END] $serviceName.$methodName[$streamId]');
    return Future.value();
  }
}
