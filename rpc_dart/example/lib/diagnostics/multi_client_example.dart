// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:math';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

final logger = RpcLogger('MultiClientExample');

/// Пример работы с несколькими клиентами, подключенными к одному
/// диагностическому серверу
///
/// В этом примере мы имитируем несколько клиентов (акторов), каждый из которых
/// генерирует логи и метрики, а центральный сервер диагностики их собирает и обрабатывает
Future<void> main({bool debug = true}) async {
  printHeader('Пример работы с несколькими клиентами');

  // Создаем транспорт для сервера диагностики
  final diagnosticServerTransport = MemoryTransport('diagnostic-server');
  final diagnosticServerEndpoint = RpcEndpoint(
    transport: diagnosticServerTransport,
    debugLabel: 'diagnostic-server',
  );

  // Запускаем сервер диагностики
  logger.info('Запуск сервера диагностики...', color: AnsiColor.magenta);
  final diagnosticServer = await setupDiagnosticServer(
    diagnosticServerEndpoint,
  );

  // Модель клиентских систем - создаем несколько клиентов с разными ID и типами
  List<ClientActor> clients = [];
  const int numberOfClients = 3;

  logger.info(
    'Создание $numberOfClients клиентов...',
    color: AnsiColor.magenta,
  );
  for (int i = 1; i <= numberOfClients; i++) {
    // Создаем клиентский транспорт и подключаем его к серверу диагностики
    final clientTransport = MemoryTransport('client-$i');
    clientTransport.connect(diagnosticServerTransport);
    diagnosticServerTransport.connect(clientTransport);

    // Создаем эндпоинт клиента
    final clientEndpoint = RpcEndpoint(
      transport: clientTransport,
      debugLabel: 'client-$i',
    );

    // Определяем тип клиента
    final clientType = ClientType.values[i % ClientType.values.length];

    // Создаем и настраиваем клиента
    final client = await setupClient(
      clientEndpoint: clientEndpoint,
      clientIndex: i,
      clientType: clientType,
      debug: debug,
    );

    clients.add(client);
    logger.info(
      'Клиент $i (${clientType.name}) создан и подключен',
      color: AnsiColor.green,
    );
  }

  // Имитируем работу клиентов - генерация логов и метрик
  logger.info('Запуск имитации работы клиентов...', color: AnsiColor.magenta);

  // Запускаем работу клиентов параллельно
  final workFutures = clients.map((client) => client.simulateWork()).toList();

  // Ждем завершения работы всех клиентов
  await Future.wait(workFutures);

  // Отправляем все накопленные метрики на сервер
  for (final client in clients) {
    await client.diagnosticService.flush();
  }

  // Даем время для обработки всех метрик на сервере
  await Future.delayed(Duration(seconds: 1));

  // Выводим статистику по собранным метрикам
  diagnosticServer.printCollectedMetricsStats();

  // Закрываем все эндпоинты
  for (final client in clients) {
    await client.endpoint.close();
  }
  await diagnosticServerEndpoint.close();

  printHeader('Пример завершен');
}

/// Устанавливает и настраивает сервер диагностики
Future<DiagnosticServerImpl> setupDiagnosticServer(RpcEndpoint endpoint) async {
  // Создаем сервер диагностики
  final diagnosticServer = DiagnosticServerImpl(
    ConsoleRpcLogger('diagnostic-server'),
  );

  // Создаем и регистрируем контракт диагностики на эндпоинте
  final contract = RpcDiagnosticServerContract(
    onSendMetrics: diagnosticServer.handleMetrics,
    onTraceEvent: diagnosticServer.handleTraceEvent,
    onLatencyMetric: diagnosticServer.handleLatencyMetric,
    onStreamMetric: diagnosticServer.handleStreamMetric,
    onErrorMetric: diagnosticServer.handleErrorMetric,
    onResourceMetric: diagnosticServer.handleResourceMetric,
    onRegisterClient: diagnosticServer.handleClientRegistration,
    onLog: diagnosticServer.handleLog,
    onPing: () async => true,
  );

  // Регистрируем контракт
  endpoint.registerServiceContract(contract);

  return diagnosticServer;
}

/// Настраивает клиентский актор
Future<ClientActor> setupClient({
  required RpcEndpoint clientEndpoint,
  required int clientIndex,
  required ClientType clientType,
  required bool debug,
}) async {
  // Создаем идентификатор клиента
  final clientIdentity = RpcClientIdentity(
    clientId: 'client-$clientIndex',
    traceId: 'trace-${DateTime.now().millisecondsSinceEpoch}-$clientIndex',
    appVersion: '1.0.$clientIndex',
    properties: {
      'clientType': clientType.name,
      'applicationName': 'MultiClientApp',
      'sessionId':
          'session-${DateTime.now().millisecondsSinceEpoch}-$clientIndex',
    },
  );

  // Настройка опций диагностики для данного типа клиента
  RpcDiagnosticOptions options;
  switch (clientType) {
    case ClientType.mobile:
      // Мобильный клиент - экономим ресурсы, собираем только важные метрики
      options = RpcDiagnosticOptions(
        enabled: true,
        samplingRate: 0.5, // Собираем только 50% метрик
        maxBufferSize: 20,
        flushIntervalMs: 5000, // Отправка каждые 5 секунд
        minLogLevel: RpcLoggerLevel.info, // Только инфо и выше
        consoleLoggingEnabled: debug,
        traceEnabled: false, // Отключаем трассировку
        latencyEnabled: true,
        streamMetricsEnabled: false,
        errorMetricsEnabled: true,
        resourceMetricsEnabled: false,
        loggingEnabled: true,
      );
      break;
    case ClientType.desktop:
      // Десктопный клиент - собираем больше метрик
      options = RpcDiagnosticOptions(
        enabled: true,
        samplingRate: 0.8, // Собираем 80% метрик
        maxBufferSize: 50,
        flushIntervalMs: 3000,
        minLogLevel: debug ? RpcLoggerLevel.debug : RpcLoggerLevel.info,
        consoleLoggingEnabled: debug,
        traceEnabled: true,
        latencyEnabled: true,
        streamMetricsEnabled: true,
        errorMetricsEnabled: true,
        resourceMetricsEnabled: true,
        loggingEnabled: true,
      );
      break;
    case ClientType.server:
      // Серверный компонент - собираем все метрики
      options = RpcDiagnosticOptions(
        enabled: true,
        samplingRate: 1.0, // Собираем 100% метрик
        maxBufferSize: 100,
        flushIntervalMs: 2000,
        minLogLevel: debug ? RpcLoggerLevel.debug : RpcLoggerLevel.info,
        consoleLoggingEnabled: debug,
        traceEnabled: true,
        latencyEnabled: true,
        streamMetricsEnabled: true,
        errorMetricsEnabled: true,
        resourceMetricsEnabled: true,
        loggingEnabled: true,
      );
      break;
  }

  // Создаем клиент диагностики
  final diagnosticClient = RpcDiagnosticClient(
    endpoint: clientEndpoint,
    clientIdentity: clientIdentity,
    options: options,
  );

  // Настраиваем локальный логгер для этого клиента
  // В реальной системе это может быть переопределение RpcLog
  // для конкретного модуля
  final name = 'Client-$clientIndex';
  final logger = DiagnosticRpcLogger(
    name,
    consoleLogger: ConsoleRpcLogger(name),
  );

  // Проверяем соединение с сервером диагностики
  final connected = await diagnosticClient.ping();
  logger.info(
    'Клиент-$clientIndex (${clientType.name}): соединение с сервером диагностики ${connected ? "установлено" : "не установлено"}',
  );

  // Создаем и возвращаем объект актора
  return ClientActor(
    endpoint: clientEndpoint,
    diagnosticService: diagnosticClient,
    clientType: clientType,
    logger: logger,
    clientIndex: clientIndex,
  );
}

/// Типы клиентов, которые симулируем в примере
enum ClientType {
  mobile, // Мобильный клиент (ограниченные ресурсы)
  desktop, // Десктопный клиент (больше ресурсов)
  server, // Серверный компонент (максимальные ресурсы)
}

/// Актор, представляющий клиента
class ClientActor {
  final RpcEndpoint endpoint;
  final IRpcDiagnosticClient diagnosticService;
  final ClientType clientType;
  final RpcLogger logger;
  final int clientIndex;
  final Random random = Random();

  ClientActor({
    required this.endpoint,
    required this.diagnosticService,
    required this.clientType,
    required this.logger,
    required this.clientIndex,
  });

  /// Имитация работы клиента - генерация различных логов и метрик
  Future<void> simulateWork() async {
    logger.info('Начинаем работу');

    // Имитируем выполнение разного количества операций в зависимости от типа клиента
    final operations =
        {
          ClientType.mobile: 5,
          ClientType.desktop: 8,
          ClientType.server: 12,
        }[clientType] ??
        5;

    // Выполняем случайные операции
    for (int i = 0; i < operations; i++) {
      await performRandomOperation(i);

      // Случайная задержка между операциями
      final delay = 100 + random.nextInt(300);
      await Future.delayed(Duration(milliseconds: delay));
    }

    logger.info('Работа завершена');
  }

  /// Выполняет случайную операцию и логирует её
  Future<void> performRandomOperation(int operationIndex) async {
    // Выбираем случайный тип операции
    final operationType =
        OperationType.values[random.nextInt(OperationType.values.length)];

    switch (operationType) {
      case OperationType.regularTask:
        await performRegularTask(operationIndex);
        break;
      case OperationType.streamTask:
        await performStreamTask(operationIndex);
        break;
      case OperationType.errorTask:
        await performErrorTask(operationIndex);
        break;
      case OperationType.resourceIntensiveTask:
        await performResourceIntensiveTask(operationIndex);
        break;
    }
  }

  /// Обычная задача, генерирующая информационные логи
  Future<void> performRegularTask(int taskIndex) async {
    logger.debug('Запуск обычной задачи #$taskIndex');

    // Измеряем время выполнения задачи
    final result = await diagnosticService.measureLatency(
      operation: () async {
        // Имитируем некоторую работу
        await Future.delayed(Duration(milliseconds: 50 + random.nextInt(150)));
        return 'Результат задачи #$taskIndex';
      },
      operationName: 'regular_task_$taskIndex',
      operationType: RpcLatencyOperationType.methodCall,
      method: 'performRegularTask',
      service: 'ClientActor',
    );

    logger.info('Задача #$taskIndex завершена: $result');
  }

  /// Задача, работающая со стримами данных
  Future<void> performStreamTask(int taskIndex) async {
    logger.debug('Запуск стрим-задачи #$taskIndex');

    final streamId = 'stream-$clientIndex-$taskIndex';

    // Создаем метрику начала стрима
    await diagnosticService.reportStreamMetric(
      diagnosticService.createStreamMetric(
        streamId: streamId,
        direction: RpcStreamDirection.clientToServer,
        eventType: RpcStreamEventType.created,
        method: 'performStreamTask',
      ),
    );

    // Имитируем отправку сообщений в стрим
    final messageCount = 1 + random.nextInt(5);
    for (int i = 0; i < messageCount; i++) {
      // Имитируем задержку отправки сообщения
      await Future.delayed(Duration(milliseconds: 30 + random.nextInt(70)));

      logger.debug('Отправка сообщения #$i в стрим $streamId');

      // Имитируем отправку сообщения различного размера
      final dataSize = 128 + random.nextInt(2048);
      await diagnosticService.reportStreamMetric(
        diagnosticService.createStreamMetric(
          streamId: streamId,
          direction: RpcStreamDirection.clientToServer,
          eventType: RpcStreamEventType.messageSent,
          method: 'performStreamTask',
          dataSize: dataSize,
          messageCount: 1,
        ),
      );
    }

    // Закрываем стрим
    await diagnosticService.reportStreamMetric(
      diagnosticService.createStreamMetric(
        streamId: streamId,
        direction: RpcStreamDirection.clientToServer,
        eventType: RpcStreamEventType.closed,
        method: 'performStreamTask',
        messageCount: messageCount,
      ),
    );

    logger.info(
      'Стрим-задача #$taskIndex завершена, отправлено $messageCount сообщений',
    );
  }

  /// Задача, которая завершается ошибкой
  Future<void> performErrorTask(int taskIndex) async {
    logger.debug('Запуск задачи с ошибкой #$taskIndex');

    try {
      // Имитируем выполнение задачи, которая завершается ошибкой
      await Future.delayed(Duration(milliseconds: 30 + random.nextInt(100)));

      // Генерируем случайную ошибку
      final errorTypes = [
        'validation',
        'connection',
        'timeout',
        'permission',
        'data',
      ];
      final errorType = errorTypes[random.nextInt(errorTypes.length)];

      throw Exception('Ошибка $errorType при выполнении задачи #$taskIndex');
    } catch (e, stack) {
      logger.error('Задача #$taskIndex завершилась с ошибкой: $e');

      // Создаем метрику ошибки
      await diagnosticService.reportErrorMetric(
        diagnosticService.createErrorMetric(
          errorType: RpcErrorMetricType.unexpectedError,
          message: e.toString(),
          code: 500,
          method: 'performErrorTask',
          stackTrace: stack.toString(),
          details: {
            'taskIndex': taskIndex,
            'clientIndex': clientIndex,
            'clientType': clientType.name,
          },
        ),
      );
    }
  }

  /// Ресурсоемкая задача, использующая много памяти и CPU
  Future<void> performResourceIntensiveTask(int taskIndex) async {
    logger.debug('Запуск ресурсоемкой задачи #$taskIndex');

    // Имитируем выполнение задачи, потребляющей много ресурсов
    await Future.delayed(Duration(milliseconds: 100 + random.nextInt(200)));

    // Отправляем метрику использования ресурсов
    await diagnosticService.reportResourceMetric(
      diagnosticService.createResourceMetric(
        memoryUsage:
            1024 * 1024 * (10 + random.nextInt(90)), // 10-100 МБ памяти
        cpuUsage: 0.2 + random.nextDouble() * 0.6, // 20-80% CPU
        activeConnections: random.nextInt(10),
        activeStreams: random.nextInt(5),
        requestsPerSecond: random.nextDouble() * 20,
        networkInBytes: 1024 * random.nextInt(100),
        networkOutBytes: 1024 * random.nextInt(50),
        additionalMetrics: {
          'taskIndex': taskIndex,
          'taskDuration': '${100 + random.nextInt(200)}ms',
          'clientType': clientType.name,
        },
      ),
    );

    logger.info('Ресурсоемкая задача #$taskIndex завершена');
  }
}

/// Типы операций, которые может выполнять клиент
enum OperationType {
  regularTask, // Обычная задача
  streamTask, // Задача, работающая со стримами
  errorTask, // Задача, которая завершается ошибкой
  resourceIntensiveTask, // Ресурсоемкая задача
}

/// Реализация сервера диагностики
class DiagnosticServerImpl {
  final RpcLogger logger;

  DiagnosticServerImpl(this.logger);

  // Хранение клиентов
  final Map<String, RpcClientIdentity> _clients = {};

  // Счетчики метрик по типам
  final Map<String, int> _metricCounts = {
    'total': 0,
    'logs': 0,
    'trace': 0,
    'latency': 0,
    'stream': 0,
    'error': 0,
    'resource': 0,
  };

  // Метрики по клиентам
  final Map<String, Map<String, int>> _clientMetrics = {};

  // Обработка регистрации клиента
  void handleClientRegistration(RpcClientIdentity client) {
    _clients[client.clientId] = client;
    _clientMetrics[client.clientId] = {
      'total': 0,
      'logs': 0,
      'trace': 0,
      'latency': 0,
      'stream': 0,
      'error': 0,
      'resource': 0,
    };

    logger.info(
      'Диагностический сервер: зарегистрирован клиент ${client.clientId} '
      '(${client.properties?['clientType']})',
    );
  }

  // Обработка пакета метрик
  void handleMetrics(List<RpcMetric> metrics) {
    for (final metric in metrics) {
      _metricCounts['total'] = (_metricCounts['total'] ?? 0) + 1;
      _clientMetrics[metric.clientId]?['total'] =
          (_clientMetrics[metric.clientId]?['total'] ?? 0) + 1;

      // Обрабатываем по типу
      if (metric.metricType == RpcMetricType.log) {
        _metricCounts['logs'] = (_metricCounts['logs'] ?? 0) + 1;
        _clientMetrics[metric.clientId]?['logs'] =
            (_clientMetrics[metric.clientId]?['logs'] ?? 0) + 1;
      } else if (metric.metricType == RpcMetricType.trace) {
        _metricCounts['trace'] = (_metricCounts['trace'] ?? 0) + 1;
        _clientMetrics[metric.clientId]?['trace'] =
            (_clientMetrics[metric.clientId]?['trace'] ?? 0) + 1;
      } else if (metric.metricType == RpcMetricType.latency) {
        _metricCounts['latency'] = (_metricCounts['latency'] ?? 0) + 1;
        _clientMetrics[metric.clientId]?['latency'] =
            (_clientMetrics[metric.clientId]?['latency'] ?? 0) + 1;
      } else if (metric.metricType == RpcMetricType.stream) {
        _metricCounts['stream'] = (_metricCounts['stream'] ?? 0) + 1;
        _clientMetrics[metric.clientId]?['stream'] =
            (_clientMetrics[metric.clientId]?['stream'] ?? 0) + 1;
      } else if (metric.metricType == RpcMetricType.error) {
        _metricCounts['error'] = (_metricCounts['error'] ?? 0) + 1;
        _clientMetrics[metric.clientId]?['error'] =
            (_clientMetrics[metric.clientId]?['error'] ?? 0) + 1;
      } else if (metric.metricType == RpcMetricType.resource) {
        _metricCounts['resource'] = (_metricCounts['resource'] ?? 0) + 1;
        _clientMetrics[metric.clientId]?['resource'] =
            (_clientMetrics[metric.clientId]?['resource'] ?? 0) + 1;
      }
    }

    logger.info(
      'Диагностический сервер: получено ${metrics.length} метрик от клиента ${metrics.first.clientId}',
    );
  }

  // Обработка трейс-события
  void handleTraceEvent(RpcMetric<RpcTraceMetric> event) {
    // Подсчитываем в общей статистике
    _metricCounts['trace'] = (_metricCounts['trace'] ?? 0) + 1;
    _clientMetrics[event.clientId]?['trace'] =
        (_clientMetrics[event.clientId]?['trace'] ?? 0) + 1;

    // Тут может быть обработка события, но для примера просто логируем
    // RpcLog.debug(
    //   message: 'Трейс-событие от ${event.clientId}: ${event.content.method}',
    //   color: AnsiColor.yellow,
    // );
  }

  // Обработка метрики латентности
  void handleLatencyMetric(RpcMetric<RpcLatencyMetric> metric) {
    _metricCounts['latency'] = (_metricCounts['latency'] ?? 0) + 1;
    _clientMetrics[metric.clientId]?['latency'] =
        (_clientMetrics[metric.clientId]?['latency'] ?? 0) + 1;

    // Для важных метрик (долгое выполнение) можно выводить специальные уведомления
    if (metric.content.durationMs > 200) {
      logger.warning(
        'Клиент ${metric.clientId}: обнаружена высокая латентность '
        '${metric.content.operation} (${metric.content.durationMs}ms)',
      );
    }
  }

  // Обработка метрик стримов
  void handleStreamMetric(RpcMetric<RpcStreamMetric> metric) {
    _metricCounts['stream'] = (_metricCounts['stream'] ?? 0) + 1;
    _clientMetrics[metric.clientId]?['stream'] =
        (_clientMetrics[metric.clientId]?['stream'] ?? 0) + 1;
  }

  // Обработка метрик ошибок
  void handleErrorMetric(RpcMetric<RpcErrorMetric> metric) {
    _metricCounts['error'] = (_metricCounts['error'] ?? 0) + 1;
    _clientMetrics[metric.clientId]?['error'] =
        (_clientMetrics[metric.clientId]?['error'] ?? 0) + 1;

    // Для ошибок важно выводить уведомления
    logger.error(
      'Клиент ${metric.clientId}: ошибка - ${metric.content.message}',
    );
  }

  // Обработка метрик ресурсов
  void handleResourceMetric(RpcMetric<RpcResourceMetric> metric) {
    _metricCounts['resource'] = (_metricCounts['resource'] ?? 0) + 1;
    _clientMetrics[metric.clientId]?['resource'] =
        (_clientMetrics[metric.clientId]?['resource'] ?? 0) + 1;

    // Для высокого использования ресурсов можно выводить специальные уведомления
    if ((metric.content.cpuUsage ?? 0) > 0.7) {
      logger.warning(
        'Клиент ${metric.clientId}: высокая загрузка CPU - ${(metric.content.cpuUsage! * 100).toStringAsFixed(1)}%',
      );
    }
  }

  // Обработка логов
  void handleLog(RpcMetric<RpcLoggerMetric> log) {
    _metricCounts['logs'] = (_metricCounts['logs'] ?? 0) + 1;
    _clientMetrics[log.clientId]?['logs'] =
        (_clientMetrics[log.clientId]?['logs'] ?? 0) + 1;

    // Логи важного уровня (warning и выше) можно выводить специально
    final logLevel = log.content.level;
    if (logLevel == RpcLoggerLevel.warning ||
        logLevel == RpcLoggerLevel.error ||
        logLevel == RpcLoggerLevel.critical) {
      final color =
          logLevel == RpcLoggerLevel.warning
              ? AnsiColor.yellow
              : logLevel == RpcLoggerLevel.error
              ? AnsiColor.red
              : AnsiColor.brightRed;

      logger.log(
        level: logLevel,
        message:
            'Клиент ${log.clientId} [${logLevel.name.toUpperCase()}]: ${log.content.message}',
        color: color,
      );
    }
  }

  // Вывод статистики собранных метрик
  void printCollectedMetricsStats() {
    printHeader('Статистика собранных метрик');

    logger.info('Общее количество метрик по типам:', color: AnsiColor.cyan);
    for (final type in _metricCounts.keys) {
      if (type != 'total') {
        logger.info(
          '  $type: ${_metricCounts[type]} метрик',
          color: AnsiColor.cyan,
        );
      }
    }
    logger.info(
      '  Всего: ${_metricCounts['total']} метрик',
      color: AnsiColor.brightCyan,
    );

    logger.info('\nМетрики по клиентам:', color: AnsiColor.magenta);
    for (final clientId in _clientMetrics.keys) {
      final clientType =
          _clients[clientId]?.properties?['clientType'] ?? 'unknown';

      logger.info('Клиент $clientId ($clientType):', color: AnsiColor.magenta);

      for (final type in _clientMetrics[clientId]!.keys) {
        if (type != 'total') {
          logger.info(
            '  $type: ${_clientMetrics[clientId]![type]} метрик',
            color: AnsiColor.magenta,
          );
        }
      }

      logger.info(
        '  Всего: ${_clientMetrics[clientId]!['total']} метрик',
        color: AnsiColor.brightMagenta,
      );

      print('');
    }
  }
}

/// Вспомогательная функция для отображения заголовков
void printHeader(String title) {
  print('');
  logger.info(
    '========================================',
    color: AnsiColor.brightWhite,
  );
  logger.info(' $title', color: AnsiColor.brightWhite);
  logger.info(
    '========================================',
    color: AnsiColor.brightWhite,
  );
  print('');
}
