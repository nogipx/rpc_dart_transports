// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

const String _source = 'DiagnosticsExample';

/// Пример настройки и использования диагностического сервиса
///
/// Демонстрирует:
/// - Настройку опций диагностики
/// - Создание и регистрацию диагностического клиента
/// - Сбор и отправку различных типов метрик
/// - Использование функций логирования
Future<void> main({bool debug = true}) async {
  printHeader('Пример настройки сервиса диагностики');

  // Создаем транспорты для RPC
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  RpcLog.info(message: 'Транспорты соединены', source: _source);

  // Создаем эндпоинты
  final clientEndpoint = RpcEndpoint(
    transport: clientTransport,
    debugLabel: 'client',
  );
  final serverEndpoint = RpcEndpoint(
    transport: serverTransport,
    debugLabel: 'server',
  );

  // Устанавливаем middlewares для отладки
  if (debug) {
    clientEndpoint.addMiddleware(DebugMiddleware(id: 'client'));
    serverEndpoint.addMiddleware(DebugMiddleware(id: 'server'));
  }

  try {
    // Регистрируем диагностический сервер
    RpcLog.info(
      message: 'Настройка диагностического сервера...',
      source: _source,
    );
    final serverContract = setupDiagnosticServer(serverEndpoint);

    // Настраиваем и регистрируем диагностический клиент
    RpcLog.info(
      message: 'Настройка диагностического клиента...',
      source: _source,
    );
    final diagnosticClient = await setupDiagnosticClient(clientEndpoint, debug);

    // Устанавливаем диагностический клиент как глобальный сервис для RpcLog
    RpcLog.setDiagnosticService(diagnosticClient);
    RpcLog.info(
      message: 'Диагностический клиент установлен для RpcLog',
      source: _source,
    );

    // Демонстрация различных типов логирования и метрик
    await demonstrateDiagnostics(diagnosticClient);

    // Отключаем диагностический клиент от RpcLog
    RpcLog.setDefaultSource(_source);

    // Закрываем эндпоинты
    await clientEndpoint.close();
    await serverEndpoint.close();
  } catch (e, stack) {
    RpcLog.error(
      message: 'Произошла ошибка при демонстрации диагностики',
      source: _source,
      error: {'error': e.toString()},
      stackTrace: stack.toString(),
    );
  }

  printHeader('Пример диагностики завершен');
}

/// Настройка сервера диагностики
DiagnosticServerContract setupDiagnosticServer(RpcEndpoint endpoint) {
  // Создаем и регистрируем контракт диагностического сервера
  final serverContract = DiagnosticServerContract(
    // Обработчик для всех отправленных метрик
    onSendMetrics: (metrics) {
      print('Получено ${metrics.length} метрик от клиента');
    },
    // Обработчики для различных типов метрик
    onTraceEvent: (metric) {
      print('Получена метрика трассировки: ${metric.content.method}');
    },
    onLatencyMetric: (metric) {
      print(
        'Получена метрика задержки: ${metric.content.operation} (${metric.content.durationMs}ms)',
      );
    },
    onStreamMetric: (metric) {
      print(
        'Получена метрика стрима: ${metric.content.streamId} (${metric.content.eventType})',
      );
    },
    onErrorMetric: (metric) {
      print('🔴 Получена метрика ошибки: ${metric.content.message}');
    },
    onResourceMetric: (metric) {
      print('Получена метрика ресурсов');
    },
    // Обработчик для логов - отключаем повторный вывод в консоль,
    // так как они уже выводятся через RpcLog на стороне клиента
    onLog: (logMetric) {
      // Не выводим логи повторно, чтобы избежать дублирования
      // Просто сохраняем их или обрабатываем без вывода в консоль
    },
    onStreamLogs: (logStream) {
      // Подписываемся на поток логов, но не выводим их повторно
      logStream.listen((logMetric) {
        // Логи уже выводятся через RpcLog на стороне клиента
      });
    },
    // Обработчик для регистрации клиентов
    onRegisterClient: (clientIdentity) {
      print('Зарегистрирован клиент: ${clientIdentity.clientId}');
    },
    // Обработчик для проверки доступности
    onPing: () async {
      print('Получен ping запрос');
      return true;
    },
  );

  // Регистрируем контракт на эндпоинте
  endpoint.registerServiceContract(serverContract);

  return serverContract;
}

/// Настраиваем диагностический клиент с заданными опциями
Future<IRpcDiagnosticService> setupDiagnosticClient(
  RpcEndpoint endpoint,
  bool debug,
) async {
  // Создаем идентификатор клиента
  final clientIdentity = RpcClientIdentity(
    clientId: 'example-client-${DateTime.now().millisecondsSinceEpoch}',
    traceId: 'trace-${DateTime.now().millisecondsSinceEpoch}',
    // Дополнительная информация о клиенте
    appVersion: '1.0.0',
    platform: Platform.operatingSystem,
    properties: {
      'applicationName': 'ExampleApp',
      'sessionId': 'session-${DateTime.now().millisecondsSinceEpoch}',
    },
  );

  // Настройка опций диагностики
  final options = DiagnosticOptions(
    // Включаем сбор метрик
    enabled: true,
    // Собираем 100% метрик (можно установить меньше для снижения нагрузки)
    samplingRate: 1.0,
    // Размер буфера для накопления метрик перед отправкой
    maxBufferSize: 50,
    // Автоматическая отправка метрик каждые 3 секунды
    flushIntervalMs: 3000,
    // Минимальный уровень логов для отправки
    minLogLevel: debug ? RpcLogLevel.debug : RpcLogLevel.info,
    // Выводить логи в консоль
    consoleLoggingEnabled: true,
    // Настройка типов собираемых метрик
    traceEnabled: true,
    latencyEnabled: true,
    streamMetricsEnabled: true,
    errorMetricsEnabled: true,
    resourceMetricsEnabled: true,
    loggingEnabled: true,
  );

  // Создаем клиент диагностики, который регистрируется на сервере
  final diagnosticClient = RpcDiagnosticService(
    endpoint: endpoint,
    clientIdentity: clientIdentity,
    options: options,
    // Необязательно: Можно предоставить собственный генератор ID
    // idGenerator: () => 'custom-id-${DateTime.now().microsecondsSinceEpoch}',
  );

  // Проверяем соединение с сервером диагностики
  final connected = await diagnosticClient.ping();
  RpcLog.info(
    message:
        'Соединение с сервером диагностики: ${connected ? "установлено" : "не установлено"}',
    source: _source,
  );

  return diagnosticClient;
}

/// Демонстрация различных возможностей диагностики
Future<void> demonstrateDiagnostics(IRpcDiagnosticService diagnostics) async {
  printHeader('Демонстрация работы диагностического сервиса');

  // 1. Простое логирование
  RpcLog.info(
    message: '1. Демонстрация разных уровней логирования',
    source: _source,
  );

  RpcLog.debug(message: 'Это отладочное сообщение', source: _source);
  RpcLog.info(message: 'Это информационное сообщение', source: _source);
  RpcLog.warning(message: 'Это предупреждение', source: _source);
  RpcLog.error(
    message: 'Это сообщение об ошибке',
    source: _source,
    error: {'code': 500, 'reason': 'Демонстрационная ошибка'},
  );

  // 2. Измерение производительности операций
  RpcLog.info(
    message: '2. Измерение производительности операций',
    source: _source,
  );

  // Измеряем время выполнения функции
  final result = await diagnostics.measureLatency(
    operation: () async {
      // Имитация долгой операции
      RpcLog.debug(message: 'Выполнение долгой операции...', source: _source);
      await Future.delayed(Duration(milliseconds: 500));
      return 'Результат операции';
    },
    operationName: 'long_calculation',
    operationType: RpcLatencyOperationType.methodCall,
    method: 'demonstrateDiagnostics',
    service: 'DiagnosticsExample',
  );

  RpcLog.info(message: 'Результат операции: $result', source: _source);

  // 3. Отправка метрик стриминга
  RpcLog.info(message: '3. Отправка метрик стриминга', source: _source);

  final streamId = 'demo-stream-${DateTime.now().millisecondsSinceEpoch}';

  // Метрика начала стрима
  await diagnostics.reportStreamMetric(
    diagnostics.createStreamMetric(
      streamId: streamId,
      direction: RpcStreamDirection.clientToServer,
      eventType: RpcStreamEventType.created,
      method: 'streamDemo',
    ),
  );

  // Имитация обработки стрима
  RpcLog.debug(message: 'Моделируем работу со стримом...', source: _source);
  await Future.delayed(Duration(milliseconds: 300));

  // Метрика получения данных
  await diagnostics.reportStreamMetric(
    diagnostics.createStreamMetric(
      streamId: streamId,
      direction: RpcStreamDirection.clientToServer,
      eventType: RpcStreamEventType.messageReceived,
      method: 'streamDemo',
      dataSize: 1024,
      messageCount: 5,
    ),
  );

  // Метрика закрытия стрима
  await diagnostics.reportStreamMetric(
    diagnostics.createStreamMetric(
      streamId: streamId,
      direction: RpcStreamDirection.clientToServer,
      eventType: RpcStreamEventType.closed,
      method: 'streamDemo',
      duration: 300,
    ),
  );

  // 4. Отправка метрик ошибок
  RpcLog.info(message: '4. Отправка метрик ошибок', source: _source);

  try {
    // Имитируем ошибку
    throw Exception('Демонстрационная ошибка в обработке');
  } catch (e, stack) {
    // Создаем и отправляем метрику ошибки
    await diagnostics.reportErrorMetric(
      diagnostics.createErrorMetric(
        errorType: RpcErrorMetricType.unexpectedError,
        message: e.toString(),
        code: 500,
        method: 'demonstrateDiagnostics',
        stackTrace: stack.toString(),
        details: {'location': 'errorDemo', 'severity': 'high'},
      ),
    );
  }

  // 5. Отправка метрики ресурсов
  RpcLog.info(message: '5. Отправка метрик ресурсов', source: _source);

  await diagnostics.reportResourceMetric(
    diagnostics.createResourceMetric(
      memoryUsage: 1024 * 1024 * 100, // 100 МБ (пример)
      cpuUsage: 0.15, // 15%
      activeConnections: 5,
      activeStreams: 2,
      requestsPerSecond: 10.5,
      networkInBytes: 1024 * 500,
      networkOutBytes: 1024 * 300,
      additionalMetrics: {'customMetric': 42, 'appState': 'running'},
    ),
  );

  // 6. Принудительная отправка всех накопленных метрик
  RpcLog.info(
    message: '6. Отправка всех накопленных метрик на сервер',
    source: _source,
  );
  await diagnostics.flush();

  // Пауза для обработки всех метрик на сервере
  await Future.delayed(Duration(seconds: 1));
}

/// Вспомогательная функция для отображения заголовков
void printHeader(String title) {
  RpcLog.info(message: '-------------------------', source: _source);
  RpcLog.info(message: ' $title', source: _source);
  RpcLog.info(message: '-------------------------', source: _source);
}
