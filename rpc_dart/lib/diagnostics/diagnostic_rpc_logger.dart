// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/diagnostics.dart';

/// Реализация логгера, которая отправляет логи только в сервис диагностики
/// без вывода в консоль.
base class DiagnosticRpcLogger implements RpcLogger {
  @override
  final String name;

  @override
  IRpcDiagnosticClient? get diagnostic => RpcLoggerSettings.diagnostic;

  final ConsoleRpcLogger? _consoleLogger;

  /// Фильтр логов
  final IRpcLoggerFilter? _filter;

  /// Создает новый логгер для работы с сервисом диагностики
  ///
  /// * [name] - имя логгера (обычно название компонента)
  /// * [diagnosticService] - сервис диагностики для отправки логов (обязательный)
  /// * [minLogLevel] - минимальный уровень логов для отправки
  /// * [filter] - пользовательский фильтр логов
  const DiagnosticRpcLogger(
    this.name, {
    IRpcLoggerFilter? filter,
    ConsoleRpcLogger? consoleLogger,
  })  : _filter = filter,
        _consoleLogger = consoleLogger;

  @override
  Future<void> log({
    required RpcLoggerLevel level,
    required String message,
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color, // Этот параметр игнорируется в этой реализации
  }) async {
    // Проверяем, нужно ли логировать это сообщение
    if (_filter?.shouldLog(level, name) ?? false) {
      return;
    }

    if (_consoleLogger != null) {
      await _consoleLogger!.log(
        level: level,
        message: message,
        context: context,
        requestId: requestId,
        error: error,
        stackTrace: stackTrace,
        data: data,
        color: color,
      );
    }
    if (diagnostic != null) {
      await diagnostic!.log(
        level: level,
        message: message,
        source: name,
        context: context,
        requestId: requestId,
        error: error,
        stackTrace: stackTrace,
        data: data,
      );
    }
  }

  @override
  Future<void> debug(
    String message, {
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.debug,
      message: message,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  @override
  Future<void> info(
    String message, {
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.info,
      message: message,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  @override
  Future<void> warning(
    String message, {
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.warning,
      message: message,
      context: context,
      requestId: requestId,
      data: data,
      color: color,
    );
  }

  @override
  Future<void> error(
    String message, {
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.error,
      message: message,
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
      color: color,
    );
  }

  @override
  Future<void> critical(
    String message, {
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color,
  }) async {
    await log(
      level: RpcLoggerLevel.critical,
      message: message,
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
      color: color,
    );
  }
}
