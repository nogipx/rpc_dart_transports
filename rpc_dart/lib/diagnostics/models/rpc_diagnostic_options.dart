// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import '../_index.dart';

/// Опции диагностики
class RpcDiagnosticOptions {
  /// Флаг, указывающий, включена ли диагностика
  final bool enabled;

  /// Частота сэмплирования метрик (от 0.0 до 1.0)
  /// Значение 1.0 означает, что все метрики собираются,
  /// 0.5 - половина метрик, и т.д.
  final double samplingRate;

  /// Максимальный размер буфера метрик
  final int maxBufferSize;

  /// Интервал отправки метрик в миллисекундах
  final int flushIntervalMs;

  /// Включить шифрование метрик при передаче
  final bool encryptionEnabled;

  /// Максимальное число попыток отправки при ошибке
  final int maxRetryCount;

  /// Минимальный уровень логов для отправки
  final RpcLoggerLevel minLogLevel;

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
  const RpcDiagnosticOptions({
    this.enabled = true,
    this.samplingRate = 1.0,
    this.maxBufferSize = 100,
    this.flushIntervalMs = 5000, // 5 секунд
    this.encryptionEnabled = false,
    this.maxRetryCount = 3,
    this.minLogLevel = RpcLoggerLevel.info,
    this.consoleLoggingEnabled = true,
    this.traceEnabled = true,
    this.latencyEnabled = true,
    this.streamMetricsEnabled = true,
    this.errorMetricsEnabled = true,
    this.resourceMetricsEnabled = true,
    this.loggingEnabled = true,
  });
}
