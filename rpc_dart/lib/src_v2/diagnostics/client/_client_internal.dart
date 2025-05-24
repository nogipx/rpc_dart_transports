// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_client.dart';

/// Клиентская реализация диагностического сервиса
class _RpcDiagnosticClientInternal implements IRpcDiagnosticClient {
  /// Контракт диагностического сервиса
  final RpcDiagnosticClientContract _contract;

  /// Информация о клиенте
  @override
  final RpcClientIdentity clientIdentity;

  /// Опции диагностического сервиса
  @override
  final RpcDiagnosticOptions options;

  /// Буфер накопленных метрик
  final List<RpcMetric> _metricsBuffer = [];

  /// Таймер для периодической отправки метрик
  Timer? _flushTimer;

  /// Случайный генератор для сэмплирования
  final Random _random = Random();

  /// Функция для генерации уникальных идентификаторов
  final RpcUniqueIdGenerator _idGenerator;

  /// Флаг, указывающий, включен ли сбор метрик
  bool _enabled;

  /// Признак того, что клиент был зарегистрирован на сервере
  bool _isRegistered = false;

  _RpcDiagnosticClientInternal({
    required RpcEndpoint endpoint,
    required this.clientIdentity,
    required this.options,
  })  : _contract = RpcDiagnosticClientContract(endpoint),
        _idGenerator = endpoint.generateUniqueId,
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

  /// Регистрация клиента на диагностическом сервере
  Future<void> _registerClient() async {
    if (_enabled && !_isRegistered) {
      try {
        await _contract.clientManagement.registerClient(clientIdentity);
        _isRegistered = true;
      } catch (e) {
        _isRegistered = false;
        // Используем прямой вызов print для избежания рекурсии
        // здесь мы не можем использовать RpcLog, т.к. он может вызвать эту функцию снова
        print('Failed to register diagnostic client: $e');
      }
    }
  }

  /// Проверка, включен ли сбор метрик
  @override
  bool get isEnabled => _enabled;

  /// Включить сбор и отправку метрик
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
  Future<void> reportTraceEvent(RpcMetric<RpcTraceMetric> event) async {
    if (!_enabled || !options.traceEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(event);
  }

  /// Отправить метрику задержки
  @override
  Future<void> reportLatencyMetric(RpcMetric<RpcLatencyMetric> metric) async {
    if (!_enabled || !options.latencyEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(metric);
  }

  /// Отправить метрику стриминга
  @override
  Future<void> reportStreamMetric(RpcMetric<RpcStreamMetric> metric) async {
    if (!_enabled || !options.streamMetricsEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(metric);
  }

  /// Отправить метрику ошибки
  @override
  Future<void> reportErrorMetric(RpcMetric<RpcErrorMetric> metric) async {
    if (!_enabled || !options.errorMetricsEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(metric);
  }

  /// Отправить метрику ресурсов
  @override
  Future<void> reportResourceMetric(RpcMetric<RpcResourceMetric> metric) async {
    if (!_enabled || !options.resourceMetricsEnabled || !_shouldSample()) {
      return;
    }

    await reportMetric(metric);
  }

  /// Отправить произвольную метрику
  @override
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
  @override
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
  @override
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
      await _contract.metrics.sendMetrics(metricsCopy);
    } catch (e) {
      // В случае ошибки возвращаем метрики в буфер
      _metricsBuffer.addAll(metricsCopy);
      // Используем прямой вызов print для избежания рекурсии
      // здесь мы не можем использовать RpcLog, т.к. он может вызвать эту функцию снова
      print('Failed to flush metrics: $e');
    }
  }

  /// Проверить, доступен ли диагностический сервер
  @override
  Future<bool> ping() async {
    if (!_enabled) {
      return false;
    }

    try {
      final result = await _contract.clientManagement.ping(RpcNull());
      return result.value;
    } catch (e) {
      return false;
    }
  }

  /// Измерить время выполнения функции и отправить метрику
  @override
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
  @override
  Future<void> dispose() async {
    // Отправляем все накопленные метрики
    await flush();

    // Отменяем таймер
    _flushTimer?.cancel();
    _flushTimer = null;

    // Отключаем сбор метрик
    _enabled = false;
  }

  /// Отправить метрику лога
  @override
  Future<void> reportLog(RpcMetric<RpcLoggerMetric> metric) async {
    if (!_enabled || !options.loggingEnabled) return;

    // Проверка уровня логирования
    if (metric.content.level.index < options.minLogLevel.index) {
      return;
    }

    // Вывод в консоль, если включено
    if (options.consoleLoggingEnabled) {
      _logToConsole(metric.content);
    }

    // Проверяем семплирование
    if (!_shouldSample()) return;

    // Добавляем в буфер
    _metricsBuffer.add(metric);

    // Проверяем размер буфера
    if (_metricsBuffer.length >= options.maxBufferSize) {
      await flush();
    }
  }

  /// Вывод лога в консоль с форматированием
  void _logToConsole(RpcLoggerMetric log) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(log.timestamp);
    final formattedTime =
        '${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
    final source = log.source;
    final message = log.message;

    String prefix;
    switch (log.level) {
      case RpcLoggerLevel.debug:
        prefix = '🔍 DEBUG';
      case RpcLoggerLevel.info:
        prefix = '📝 INFO ';
      case RpcLoggerLevel.warning:
        prefix = '⚠️ WARN ';
      case RpcLoggerLevel.error:
        prefix = '❌ ERROR';
      case RpcLoggerLevel.critical:
        prefix = '🔥 CRIT ';
      default:
        prefix = '     ';
    }

    // Используем прямой вызов print, так как эта функция вызывается из RpcLog
    // для избежания рекурсии
    print('[$formattedTime] $prefix [$source] $message');

    if (log.error != null) {
      print('  Error details: ${log.error}');
    }

    if (log.stackTrace != null) {
      print('  Stack trace: \n${log.stackTrace}');
    }
  }

  /// Создает метрику лога
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
    final id = _idGenerator();
    final now = DateTime.now().millisecondsSinceEpoch;
    final stackTraceString = stackTrace?.toString();

    Map<String, dynamic>? errorMap;
    if (error is IRpcSerializableMessage) {
      errorMap = error.toJson();
    } else if (error is Map<String, dynamic>) {
      errorMap = error;
    } else if (error != null) {
      errorMap = {'error': error.toString()};
    }

    final logMetric = RpcLoggerMetric(
      id: id,
      traceId: clientIdentity.traceId,
      timestamp: now,
      level: level,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      error: errorMap,
      stackTrace: stackTraceString,
      data: data,
    );

    return RpcMetric.log(
      id: id,
      timestamp: now,
      clientId: clientIdentity.clientId,
      content: logMetric,
    );
  }

  /// Инициализация потока логов для отправки через client streaming
  ///
  /// Возвращает объект потока, в который можно отправлять логи.
  /// Этот метод эффективнее, чем отправка отдельных логов через reportLogMetric,
  /// особенно при высокой нагрузке или частом логировании.
  ///
  /// Пример использования:
  /// ```dart
  /// final logStream = diagnosticClient.createLogStream();
  ///
  /// // Отправка логов в поток
  /// logStream.send(logMetric1);
  /// logStream.send(logMetric2);
  ///
  /// // Завершение отправки и закрытие потока
  /// await logStream.finishSending();
  /// await logStream.close();
  /// ```
  ClientStreamingBidiStream<RpcMetric<RpcLoggerMetric>, RpcNull>
      createLogStream() {
    if (!_enabled || !options.loggingEnabled) {
      throw RpcCustomException(
        customMessage: 'Логирование отключено в настройках диагностики',
        debugLabel: 'RpcDiagnosticClient.createLogStream',
      );
    }

    // Получаем клиентский стриминг метод
    final streamingMethod = _contract.logging.logsStream();

    // Вызываем метод call для получения ClientStreamingBidiStream
    return streamingMethod;
  }

  /// Отправка серии логов через client streaming
  ///
  /// Принимает список логов для отправки одним потоком.
  /// Это более эффективно, чем отправка каждого лога отдельно,
  /// особенно при частом логировании.
  Future<void> sendLogsInBatch(List<RpcMetric<RpcLoggerMetric>> logs) async {
    if (!_enabled || !options.loggingEnabled || logs.isEmpty) {
      return;
    }

    // Фильтруем логи по уровню перед отправкой
    final filteredLogs = logs
        .where((log) => log.content.level.index >= options.minLogLevel.index)
        .toList();

    if (filteredLogs.isEmpty) return;

    // Выводим логи в консоль, если включено
    if (options.consoleLoggingEnabled) {
      for (final log in filteredLogs) {
        _logToConsole(log.content);
      }
    }

    // Проверяем семплирование
    if (!_shouldSample()) return;

    try {
      // Получаем стрим для отправки логов
      final logStream = createLogStream();

      // Отправляем логи
      for (final log in filteredLogs) {
        logStream.send(log);
      }

      // Завершаем передачу и закрываем поток
      await logStream.finishSending();
      await logStream.close();
    } catch (e) {
      // Используем прямой вызов print для избежания рекурсии
      // здесь мы не можем использовать RpcLog, т.к. он может вызвать эту функцию снова
      print('Ошибка при отправке логов через стриминг: $e');

      // В случае ошибки добавляем логи в обычный буфер
      _metricsBuffer.addAll(filteredLogs);

      // Проверяем размер буфера
      if (_metricsBuffer.length >= options.maxBufferSize) {
        await flush();
      }
    }
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
  }) async {
    final metric = createLog(
      level: level,
      message: message,
      source: source,
      context: context,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );

    await reportLog(metric);
  }
}
