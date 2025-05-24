// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_client.dart';

/// Интерфейс диагностического сервиса
///
/// Предоставляет API для сбора и отправки метрик
abstract class IRpcDiagnosticClient {
  /// Информация о клиенте
  RpcClientIdentity get clientIdentity;

  /// Опции диагностического сервиса
  RpcDiagnosticOptions get options;

  /// Проверка, включен ли сбор метрик
  bool get isEnabled;

  /// Отправить метрику трассировки
  Future<void> reportTraceEvent(RpcMetric<RpcTraceMetric> event);

  /// Отправить метрику задержки
  Future<void> reportLatencyMetric(RpcMetric<RpcLatencyMetric> metric);

  /// Отправить метрику стриминга
  Future<void> reportStreamMetric(RpcMetric<RpcStreamMetric> metric);

  /// Отправить метрику ошибки
  Future<void> reportErrorMetric(RpcMetric<RpcErrorMetric> metric);

  /// Отправить метрику ресурсов
  Future<void> reportResourceMetric(RpcMetric<RpcResourceMetric> metric);

  /// Отправить произвольную метрику
  Future<void> reportMetric(RpcMetric metric);

  /// Отправить пакет метрик
  Future<void> reportMetrics(List<RpcMetric> metrics);

  /// Немедленно отправить все накопленные метрики
  Future<void> flush();

  /// Проверить, доступен ли диагностический сервер
  Future<bool> ping();

  /// Включить сбор и отправку метрик
  void enable();

  /// Отключить сбор и отправку метрик
  void disable();

  /// Быстрый метод для логирования
  Future<void> log({
    required RpcLoggerLevel level,
    required String message,
    required String source,
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  });

  /// Создать метрику лога
  RpcMetric<RpcLoggerMetric> createLog({
    required RpcLoggerLevel level,
    required String message,
    required String source,
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  });

  /// Отправить лог сообщение
  Future<void> reportLog(RpcMetric<RpcLoggerMetric> metric);

  /// Создать метрику трассировки
  RpcMetric<RpcTraceMetric> createTraceEvent({
    required RpcTraceMetricType eventType,
    required String method,
    required String service,
    String? requestId,
    String? parentId,
    int? durationMs,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  });

  /// Создать метрику задержки
  RpcMetric<RpcLatencyMetric> createLatencyMetric({
    required RpcLatencyOperationType operationType,
    required String operation,
    String? method,
    String? service,
    required int startTime,
    required int endTime,
    String? requestId,
    required bool success,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  });

  /// Создать метрику стриминга
  RpcMetric<RpcStreamMetric> createStreamMetric({
    required RpcStreamEventType eventType,
    required String streamId,
    required RpcStreamDirection direction,
    String? method,
    int? dataSize,
    int? messageCount,
    double? throughput,
    int? duration,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  });

  /// Создать метрику ошибки
  RpcMetric<RpcErrorMetric> createErrorMetric({
    required RpcErrorMetricType errorType,
    required String message,
    int? code,
    String? requestId,
    String? stackTrace,
    String? method,
    Map<String, dynamic>? details,
  });

  /// Создать метрику ресурсов
  RpcMetric<RpcResourceMetric> createResourceMetric({
    int? memoryUsage,
    double? cpuUsage,
    int? activeConnections,
    int? activeStreams,
    double? requestsPerSecond,
    int? networkInBytes,
    int? networkOutBytes,
    int? queueSize,
    Map<String, dynamic>? additionalMetrics,
  });

  /// Измерить время выполнения функции и отправить метрику
  Future<T> measureLatency<T>({
    required Future<T> Function() operation,
    required String operationName,
    RpcLatencyOperationType operationType = RpcLatencyOperationType.methodCall,
    String? method,
    String? service,
    String? requestId,
    Map<String, dynamic>? metadata,
  });

  /// Освободить ресурсы
  Future<void> dispose();
}
