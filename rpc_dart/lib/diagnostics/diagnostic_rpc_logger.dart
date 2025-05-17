// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/diagnostics.dart';

/// Реализация логгера, которая отправляет логи только в сервис диагностики
/// без вывода в консоль.
base class DiagnosticRpcLogger implements RpcLogger {
  @override
  final String name;

  /// Диагностический сервис для отправки логов
  final IRpcDiagnosticClient _diagnosticService;

  /// Минимальный уровень логов для отправки
  final RpcLoggerLevel _minLogLevel;

  /// Фильтр логов
  final IRpcLoggerFilter _filter;

  /// Создает новый логгер для работы с сервисом диагностики
  ///
  /// * [name] - имя логгера (обычно название компонента)
  /// * [diagnosticService] - сервис диагностики для отправки логов (обязательный)
  /// * [minLogLevel] - минимальный уровень логов для отправки
  /// * [filter] - пользовательский фильтр логов
  DiagnosticRpcLogger(
    this.name, {
    required IRpcDiagnosticClient diagnosticService,
    RpcLoggerLevel minLogLevel = RpcLoggerLevel.info,
    IRpcLoggerFilter? filter,
  })  : _diagnosticService = diagnosticService,
        _minLogLevel = minLogLevel,
        _filter = filter ?? DefaultRpcLoggerFilter(minLogLevel);

  @override
  RpcLogger withConfig({
    IRpcDiagnosticClient? diagnosticService,
    RpcLoggerLevel? minLogLevel,
    bool? consoleLoggingEnabled,
    bool? coloredLoggingEnabled,
    RpcLoggerColors? logColors,
    IRpcLoggerFilter? filter,
    IRpcLoggerFormatter? formatter,
  }) {
    // Параметры, связанные с консолью, игнорируются в этой реализации
    return DiagnosticRpcLogger(
      name,
      diagnosticService: diagnosticService ?? _diagnosticService,
      minLogLevel: minLogLevel ?? _minLogLevel,
      filter: filter ?? _filter,
    );
  }

  @override
  Future<void> log({
    required RpcLoggerLevel level,
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
    AnsiColor? color, // Этот параметр игнорируется в этой реализации
  }) async {
    // Проверяем, нужно ли логировать это сообщение
    if (!_filter.shouldLog(level, name)) {
      return;
    }

    // Отправляем в диагностический сервис
    await _diagnosticService.log(
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

  @override
  Future<void> debug({
    required String message,
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
  Future<void> info({
    required String message,
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
  Future<void> warning({
    required String message,
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
  Future<void> error({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
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
  Future<void> critical({
    required String message,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
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
