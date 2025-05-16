// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/diagnostics.dart';

/// Интерфейс диагностического сервиса для отправки логов и метрик
abstract class IRpcDiagnosticService {
  /// Возвращает настройки диагностики
  DiagnosticOptions get options;

  /// Отправляет лог в сервис диагностики
  Future<void> log({
    required RpcLogLevel level,
    required String message,
    required String source,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
  });

  /// Отправляет лог уровня debug
  Future<void> debug({
    required String message,
    required String source,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
  });

  /// Отправляет лог уровня info
  Future<void> info({
    required String message,
    required String source,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
  });

  /// Отправляет лог уровня warning
  Future<void> warning({
    required String message,
    required String source,
    String? context,
    String? requestId,
    Map<String, dynamic>? data,
  });

  /// Отправляет лог уровня error
  Future<void> error({
    required String message,
    required String source,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
  });

  /// Отправляет лог уровня critical
  Future<void> critical({
    required String message,
    required String source,
    String? context,
    String? requestId,
    Map<String, dynamic>? error,
    String? stackTrace,
    Map<String, dynamic>? data,
  });

  /// Проверяет соединение с сервером диагностики
  Future<bool> ping();

  /// Отправляет накопленные метрики на сервер
  Future<void> flush();
}

/// Опции диагностики
class DiagnosticOptions {
  /// Флаг, указывающий, включена ли диагностика
  final bool enabled;

  /// Частота сэмплирования метрик (от 0.0 до 1.0)
  final double samplingRate;

  /// Максимальный размер буфера метрик
  final int maxBufferSize;

  /// Интервал отправки метрик в миллисекундах
  final int flushIntervalMs;

  /// Минимальный уровень логов для отправки
  final RpcLogLevel minLogLevel;

  /// Флаг вывода логов в консоль
  final bool consoleLoggingEnabled;

  /// Флаг, указывающий, включено ли трассирование
  final bool traceEnabled;

  /// Флаг, указывающий, включены ли метрики латентности
  final bool latencyEnabled;

  /// Флаг, указывающий, включены ли метрики стримов
  final bool streamMetricsEnabled;

  /// Флаг, указывающий, включены ли метрики ошибок
  final bool errorMetricsEnabled;

  /// Флаг, указывающий, включены ли метрики ресурсов
  final bool resourceMetricsEnabled;

  /// Флаг, указывающий, включено ли логирование
  final bool loggingEnabled;

  /// Создает новый объект опций диагностики
  const DiagnosticOptions({
    this.enabled = true,
    this.samplingRate = 1.0,
    this.maxBufferSize = 100,
    this.flushIntervalMs = 5000,
    this.minLogLevel = RpcLogLevel.info,
    this.consoleLoggingEnabled = true,
    this.traceEnabled = true,
    this.latencyEnabled = true,
    this.streamMetricsEnabled = true,
    this.errorMetricsEnabled = true,
    this.resourceMetricsEnabled = true,
    this.loggingEnabled = true,
  });
}
