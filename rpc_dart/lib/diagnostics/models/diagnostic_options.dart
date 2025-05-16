// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

/// Опции для настройки работы диагностического сервиса
class DiagnosticOptions {
  /// Включить сбор метрик
  final bool enabled;

  /// Частота сэмплирования метрик (от 0.0 до 1.0)
  /// Значение 1.0 означает, что все метрики собираются,
  /// 0.5 - половина метрик, и т.д.
  final double samplingRate;

  /// Максимальный размер буфера метрик
  final int maxBufferSize;

  /// Интервал автоматической отправки метрик (миллисекунды)
  final int flushIntervalMs;

  /// Включить шифрование метрик при передаче
  final bool encryptionEnabled;

  /// Максимальное число попыток отправки при ошибке
  final int maxRetryCount;

  /// Включить сбор метрик трассировки
  final bool traceEnabled;

  /// Включить сбор метрик задержки
  final bool latencyEnabled;

  /// Включить сбор метрик стриминга
  final bool streamMetricsEnabled;

  /// Включить сбор метрик ошибок
  final bool errorMetricsEnabled;

  /// Включить сбор метрик ресурсов
  final bool resourceMetricsEnabled;

  const DiagnosticOptions({
    this.enabled = true,
    this.samplingRate = 1.0,
    this.maxBufferSize = 100,
    this.flushIntervalMs = 5000, // 5 секунд
    this.encryptionEnabled = false,
    this.maxRetryCount = 3,
    this.traceEnabled = true,
    this.latencyEnabled = true,
    this.streamMetricsEnabled = true,
    this.errorMetricsEnabled = true,
    this.resourceMetricsEnabled = true,
  });
}
