// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:math';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

/// Клиентская реализация диагностического сервиса
class DiagnosticClient {
  /// Контракт диагностического сервиса
  final DiagnosticClientContract _contract;

  /// Информация о клиенте
  final RpcClientIdentity clientIdentity;

  /// Опции диагностического сервиса
  final DiagnosticOptions options;

  /// Буфер накопленных метрик
  final List<RpcMetric> _metricsBuffer = [];

  /// Таймер для периодической отправки метрик
  Timer? _flushTimer;

  /// Случайный генератор для сэмплирования
  final Random _random = Random();

  /// Функция для генерации уникальных идентификаторов
  final String Function() _idGenerator;

  /// Флаг, указывающий, включен ли сбор метрик
  bool _enabled;

  /// Признак того, что клиент был зарегистрирован на сервере
  bool _isRegistered = false;

  DiagnosticClient({
    required RpcEndpoint endpoint,
    required this.clientIdentity,
    required this.options,
    String Function()? idGenerator,
  })  : _contract = DiagnosticClientContract(endpoint),
        _idGenerator = idGenerator ?? _defaultIdGenerator,
        _enabled = options.enabled {
    // Запускаем таймер для периодической отправки метрик, если включено
    if (_enabled && options.flushIntervalMs > 0) {
      _flushTimer = Timer.periodic(
        Duration(milliseconds: options.flushIntervalMs),
        (_) => flush(),
      );
    }

    // Регистрируем клиента на сервере
    _registerClient();
  }

  /// Функция генерации ID по умолчанию, использующая UUID v4
  static String _defaultIdGenerator() {
    final random = Random();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Устанавливаем биты версии (v4)
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }

    return buffer.toString();
  }

  /// Регистрация клиента на диагностическом сервере
  Future<void> _registerClient() async {
    if (_enabled && !_isRegistered) {
      try {
        await _contract.registerClient(clientIdentity);
        _isRegistered = true;
      } catch (e) {
        _isRegistered = false;
        // Просто логируем ошибку и продолжаем работу
        print('Failed to register diagnostic client: $e');
      }
    }
  }

  /// Проверка, включен ли сбор метрик
  bool get isEnabled => _enabled;

  /// Включить сбор и отправку метрик
  void enable() {
    _enabled = true;
    if (options.flushIntervalMs > 0 && _flushTimer == null) {
      _flushTimer = Timer.periodic(
        Duration(milliseconds: options.flushIntervalMs),
        (_) => flush(),
      );
    }
  }

  /// Отключить сбор и отправку метрик
  void disable() {
    _enabled = false;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Проверка, нужно ли сэмплировать метрику
  bool _shouldSample() {
    return _random.nextDouble() < options.samplingRate;
  }

  /// Текущая временная метка в миллисекундах
  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Создать метрику трассировки
  RpcMetric<RpcTraceMetric> createTraceEvent({
    required String method,
    required String service,
    required RpcTraceMetricType eventType,
    String? requestId,
    String? parentId,
    int? durationMs,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  }) {
    final id = _idGenerator();
    final timestamp = _now();

    final content = RpcTraceMetric(
      id: id,
      timestamp: timestamp,
      eventType: eventType,
      method: method,
      service: service,
      requestId: requestId,
      parentId: parentId,
      durationMs: durationMs,
      error: error,
      metadata: metadata,
      traceId: clientIdentity.traceId,
    );

    return RpcMetric.trace(
      id: id,
      timestamp: timestamp,
      clientId: clientIdentity.clientId,
      content: content,
    );
  }

  /// Создать метрику задержки
  RpcMetric<RpcLatencyMetric> createLatencyMetric({
    required String operation,
    required RpcLatencyOperationType operationType,
    String? method,
    String? service,
    required int startTime,
    required int endTime,
    String? requestId,
    required bool success,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  }) {
    final id = _idGenerator();
    final timestamp = _now();

    final content = RpcLatencyMetric(
      id: id,
      timestamp: timestamp,
      operationType: operationType,
      operation: operation,
      method: method,
      service: service,
      startTime: startTime,
      endTime: endTime,
      requestId: requestId,
      clientId: clientIdentity.clientId,
      success: success,
      error: error,
      metadata: metadata,
      traceId: clientIdentity.traceId,
    );

    return RpcMetric.latency(
      id: id,
      timestamp: timestamp,
      clientId: clientIdentity.clientId,
      content: content,
    );
  }

  /// Создать метрику стриминга
  RpcMetric<RpcStreamMetric> createStreamMetric({
    required String streamId,
    required RpcStreamDirection direction,
    required RpcStreamEventType eventType,
    String? method,
    int? dataSize,
    int? messageCount,
    double? throughput,
    int? duration,
    Map<String, dynamic>? error,
    Map<String, dynamic>? metadata,
  }) {
    final id = _idGenerator();
    final timestamp = _now();

    final content = RpcStreamMetric(
      id: id,
      timestamp: timestamp,
      streamId: streamId,
      eventType: eventType,
      direction: direction,
      method: method,
      dataSize: dataSize,
      messageCount: messageCount,
      throughput: throughput,
      duration: duration,
      error: error,
      metadata: metadata,
      traceId: clientIdentity.traceId,
    );

    return RpcMetric.stream(
      id: id,
      timestamp: timestamp,
      clientId: clientIdentity.clientId,
      content: content,
    );
  }

  /// Создать метрику ошибки
  RpcMetric<RpcErrorMetric> createErrorMetric({
    required RpcErrorMetricType errorType,
    required String message,
    int? code,
    String? requestId,
    String? stackTrace,
    String? method,
    Map<String, dynamic>? details,
  }) {
    final id = _idGenerator();
    final timestamp = _now();

    // Добавим traceId в детали, если их нет
    Map<String, dynamic> detailsWithTrace = {...?details};
    if (!detailsWithTrace.containsKey('trace_id')) {
      detailsWithTrace['trace_id'] = clientIdentity.traceId;
    }

    final content = RpcErrorMetric(
      errorType: errorType,
      message: message,
      code: code,
      requestId: requestId,
      stackTrace: stackTrace,
      method: method,
      details: detailsWithTrace,
    );

    return RpcMetric.error(
      id: id,
      timestamp: timestamp,
      clientId: clientIdentity.clientId,
      content: content,
    );
  }

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
  }) {
    final id = _idGenerator();
    final timestamp = _now();

    // Добавим traceId в дополнительные метрики
    Map<String, dynamic> metricsWithTrace = {...?additionalMetrics};
    if (!metricsWithTrace.containsKey('trace_id')) {
      metricsWithTrace['trace_id'] = clientIdentity.traceId;
    }

    final content = RpcResourceMetric(
      memoryUsage: memoryUsage,
      cpuUsage: cpuUsage,
      activeConnections: activeConnections,
      activeStreams: activeStreams,
      requestsPerSecond: requestsPerSecond,
      networkInBytes: networkInBytes,
      networkOutBytes: networkOutBytes,
      queueSize: queueSize,
      additionalMetrics: metricsWithTrace,
    );

    return RpcMetric.resource(
      id: id,
      timestamp: timestamp,
      clientId: clientIdentity.clientId,
      content: content,
    );
  }

  /// Отправить метрику трассировки
  Future<void> reportTraceEvent(RpcMetric<RpcTraceMetric> event) async {
    if (!_enabled || !options.traceEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(event);
  }

  /// Отправить метрику задержки
  Future<void> reportLatencyMetric(RpcMetric<RpcLatencyMetric> metric) async {
    if (!_enabled || !options.latencyEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(metric);
  }

  /// Отправить метрику стриминга
  Future<void> reportStreamMetric(RpcMetric<RpcStreamMetric> metric) async {
    if (!_enabled || !options.streamMetricsEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(metric);
  }

  /// Отправить метрику ошибки
  Future<void> reportErrorMetric(RpcMetric<RpcErrorMetric> metric) async {
    if (!_enabled || !options.errorMetricsEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(metric);
  }

  /// Отправить метрику ресурсов
  Future<void> reportResourceMetric(RpcMetric<RpcResourceMetric> metric) async {
    if (!_enabled || !options.resourceMetricsEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(metric);
  }

  /// Отправить произвольную метрику
  Future<void> reportMetric(RpcMetric metric) async {
    if (!_enabled) {
      return;
    }

    // Добавляем метрику в буфер
    _metricsBuffer.add(metric);

    // Отправляем метрики, если буфер достиг предельного размера
    if (_metricsBuffer.length >= options.maxBufferSize) {
      await flush();
    }
  }

  /// Отправить пакет метрик
  Future<void> reportMetrics(List<RpcMetric> metrics) async {
    if (!_enabled) {
      return;
    }

    // Добавляем метрики в буфер
    _metricsBuffer.addAll(metrics);

    // Отправляем метрики, если буфер достиг предельного размера
    if (_metricsBuffer.length >= options.maxBufferSize) {
      await flush();
    }
  }

  /// Немедленно отправить все накопленные метрики
  Future<void> flush() async {
    if (!_enabled || _metricsBuffer.isEmpty) {
      return;
    }

    final metricsCopy = List<RpcMetric>.from(_metricsBuffer);
    _metricsBuffer.clear();

    try {
      // Если клиент не зарегистрирован, пробуем зарегистрировать его снова
      if (!_isRegistered) {
        await _registerClient();
      }

      // Отправляем метрики на сервер
      await _contract.sendMetrics(metricsCopy);
    } catch (e) {
      // В случае ошибки возвращаем метрики в буфер
      _metricsBuffer.addAll(metricsCopy);
      print('Failed to flush metrics: $e');
    }
  }

  /// Проверить, доступен ли диагностический сервер
  Future<bool> ping() async {
    if (!_enabled) {
      return false;
    }

    try {
      final result = await _contract.ping(RpcNull());
      return result.value;
    } catch (e) {
      return false;
    }
  }

  /// Измерить время выполнения функции и отправить метрику
  Future<T> measureLatency<T>({
    required Future<T> Function() operation,
    required String operationName,
    RpcLatencyOperationType operationType = RpcLatencyOperationType.methodCall,
    String? method,
    String? service,
    String? requestId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_enabled || !options.latencyEnabled) {
      return await operation();
    }

    final startTime = _now();
    T result;
    bool success = true;
    Map<String, dynamic>? error;

    try {
      result = await operation();
    } catch (e, stackTrace) {
      success = false;
      error = {
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
      };
      rethrow;
    } finally {
      final endTime = _now();
      final metric = createLatencyMetric(
        operationType: operationType,
        operation: operationName,
        method: method,
        service: service,
        startTime: startTime,
        endTime: endTime,
        requestId: requestId,
        success: success,
        error: error,
        metadata: metadata,
      );

      await reportLatencyMetric(metric);
    }

    return result;
  }

  /// Освободить ресурсы
  Future<void> dispose() async {
    // Отправляем все накопленные метрики
    await flush();

    // Отменяем таймер
    _flushTimer?.cancel();
    _flushTimer = null;

    // Отключаем сбор метрик
    _enabled = false;
  }
}
