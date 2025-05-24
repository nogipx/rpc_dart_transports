// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_client.dart';

/// Удобная обертка над [RpcDiagnosticClient] реализующая интерфейс [IRpcDiagnosticClient]
///
/// Предоставляет более удобный конструктор и делегирует все вызовы внутреннему клиенту.
///
/// Пример использования:
/// ```dart
/// final diagnosticService = RpcDiagnosticService(
///   endpoint: endpoint,
///   clientIdentity: RpcClientIdentity(
///     clientId: 'client-id',
///     traceId: 'trace-id',
///   ),
///   options: DiagnosticOptions(),
/// );
///
/// // Использование сервиса
/// await diagnosticService.info(
///   message: 'Это информационное сообщение',
///   source: 'MyComponent',
/// );
/// ```
class RpcDiagnosticClient implements IRpcDiagnosticClient {
  final _RpcDiagnosticClientInternal _client;

  /// Создает новый экземпляр диагностического сервиса
  ///
  /// * [endpoint] - эндпоинт для отправки метрик
  /// * [clientIdentity] - идентификатор клиента
  /// * [options] - настройки диагностического сервиса
  RpcDiagnosticClient({
    required RpcEndpoint endpoint,
    required RpcClientIdentity clientIdentity,
    required RpcDiagnosticOptions options,
  }) : _client = _RpcDiagnosticClientInternal(
          endpoint: endpoint,
          clientIdentity: clientIdentity,
          options: options,
        );

  @override
  RpcClientIdentity get clientIdentity => _client.clientIdentity;

  @override
  RpcDiagnosticOptions get options => _client.options;

  @override
  Future<void> reportTraceEvent(RpcMetric<RpcTraceMetric> event) =>
      _client.reportTraceEvent(event);

  @override
  Future<void> reportLatencyMetric(RpcMetric<RpcLatencyMetric> metric) =>
      _client.reportLatencyMetric(metric);

  @override
  Future<void> reportStreamMetric(RpcMetric<RpcStreamMetric> metric) =>
      _client.reportStreamMetric(metric);

  @override
  Future<void> reportErrorMetric(RpcMetric<RpcErrorMetric> metric) =>
      _client.reportErrorMetric(metric);

  @override
  Future<void> reportResourceMetric(RpcMetric<RpcResourceMetric> metric) =>
      _client.reportResourceMetric(metric);

  @override
  Future<void> reportMetric(RpcMetric metric) => _client.reportMetric(metric);

  @override
  Future<void> reportMetrics(List<RpcMetric> metrics) =>
      _client.reportMetrics(metrics);

  @override
  Future<void> flush() => _client.flush();

  @override
  Future<bool> ping() => _client.ping();

  @override
  void enable() => _client.enable();

  @override
  void disable() => _client.disable();

  @override
  bool get isEnabled => _client.isEnabled;

  @override
  RpcMetric<RpcTraceMetric> createTraceEvent({
    required RpcTraceMetricType eventType,
    required String method,
    required String service,
    String? requestId,
    String? parentId,
    int? durationMs,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  }) =>
      _client.createTraceEvent(
        eventType: eventType,
        method: method,
        service: service,
        requestId: requestId,
        parentId: parentId,
        durationMs: durationMs,
        error: error,
        metadata: metadata,
      );

  @override
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
  }) =>
      _client.createLatencyMetric(
        operationType: operationType,
        operation: operation,
        method: method,
        service: service,
        startTime: startTime,
        endTime: endTime,
        requestId: requestId,
        success: success,
        error: error,
        metadata: metadata,
      );

  @override
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
  }) =>
      _client.createStreamMetric(
        eventType: eventType,
        streamId: streamId,
        direction: direction,
        method: method,
        dataSize: dataSize,
        messageCount: messageCount,
        throughput: throughput,
        duration: duration,
        error: error,
        metadata: metadata,
      );

  @override
  RpcMetric<RpcErrorMetric> createErrorMetric({
    required RpcErrorMetricType errorType,
    required String message,
    int? code,
    String? requestId,
    String? stackTrace,
    String? method,
    Map<String, dynamic>? details,
  }) =>
      _client.createErrorMetric(
        errorType: errorType,
        message: message,
        code: code,
        requestId: requestId,
        stackTrace: stackTrace,
        method: method,
        details: details,
      );

  @override
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
  }) =>
      _client.createResourceMetric(
        memoryUsage: memoryUsage,
        cpuUsage: cpuUsage,
        activeConnections: activeConnections,
        activeStreams: activeStreams,
        requestsPerSecond: requestsPerSecond,
        networkInBytes: networkInBytes,
        networkOutBytes: networkOutBytes,
        queueSize: queueSize,
        additionalMetrics: additionalMetrics,
      );

  @override
  Future<T> measureLatency<T>({
    required Future<T> Function() operation,
    required String operationName,
    RpcLatencyOperationType operationType = RpcLatencyOperationType.methodCall,
    String? method,
    String? service,
    String? requestId,
    Map<String, dynamic>? metadata,
  }) =>
      _client.measureLatency(
        operation: operation,
        operationName: operationName,
        operationType: operationType,
        method: method,
        service: service,
        requestId: requestId,
        metadata: metadata,
      );

  @override
  Future<void> dispose() async {
    await flush();
    await _client.dispose();
  }

  @override
  Future<void> log({
    required RpcLoggerLevel level,
    required String message,
    required String source,
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) =>
      _client.log(
        level: level,
        message: message,
        source: source,
        context: context,
        requestId: requestId,
        error: error,
        stackTrace: stackTrace,
        data: data,
      );

  @override
  RpcMetric<RpcLoggerMetric> createLog({
    required RpcLoggerLevel level,
    required String message,
    required String source,
    String? context,
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    return _client.createLog(
      level: level,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  @override
  Future<void> reportLog(RpcMetric<RpcLoggerMetric> metric) =>
      _client.reportLog(metric);
}
