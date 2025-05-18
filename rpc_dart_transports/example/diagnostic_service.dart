// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:io';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// Сервис диагностики для сбора метрик с удаленных клиентов по сети
///
/// Запускает WebSocket сервер, к которому могут подключаться клиенты и серверы
/// для отправки диагностических данных.
void main() async {
  // Парсим аргументы
  final host = '0.0.0.0';
  final port = 30000;

  // Настраиваем логирование
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);
  final logger = DefaultRpcLogger(
    'DiagnosticService',
    coloredLoggingEnabled: true,
    logColors: RpcLoggerColors(
      debug: AnsiColor.cyan,
      info: AnsiColor.brightGreen,
      warning: AnsiColor.brightYellow,
      error: AnsiColor.brightRed,
      critical: AnsiColor.magenta,
    ),
  );

  logger.info('Запуск сервиса диагностики...');
  logger.info('Настройка WebSocket сервера $host:$port');

  // Создаем WebSocket транспорт с сервером
  final serverTransport = await ServerWebSocketTransport.create(
    host: host,
    port: port,
    id: 'diagnostic_server',
    onClientConnected: (clientId, socket) {
      logger.info('Клиент подключен: $clientId');
    },
    onClientDisconnected: (clientId) {
      logger.info('Клиент отключен: $clientId');
    },
  );

  // Создаем эндпоинт диагностики с нашим серверным транспортом
  final diagnosticEndpoint = RpcEndpoint(
    transport: serverTransport,
    debugLabel: 'diagnostic_server',
  );

  // Хранилище информации о клиентах
  final clientsInfo = <String, RpcClientIdentity>{};

  // Коллекция для хранения полученных метрик
  final collectedMetrics = <RpcMetric>[];

  // Создаем контракт диагностического сервиса используя встроенную реализацию
  final diagnosticContract = RpcDiagnosticServerContract(
    // Обработчик для пакетной отправки метрик
    onSendMetrics: (metrics) {
      logger.info('Получены метрики: ${metrics.length} шт.');
      collectedMetrics.addAll(metrics);
      _processMetrics(metrics, logger);
    },

    // Обработчики для отдельных типов метрик
    onTraceEvent: (metric) {
      logger.debug('Получена трассировка: ${metric.content.method}');
      collectedMetrics.add(metric);
      _processMetric(metric, metric.clientId, logger);
    },

    onLatencyMetric: (metric) {
      logger.debug('Получена метрика задержки: ${metric.content.operation}');
      collectedMetrics.add(metric);
      _processMetric(metric, metric.clientId, logger);
    },

    onStreamMetric: (metric) {
      logger.debug('Получена метрика потока: ${metric.content.streamId}');
      collectedMetrics.add(metric);
      _processMetric(metric, metric.clientId, logger);
    },

    onErrorMetric: (metric) {
      logger.warning('Получена метрика ошибки: ${metric.content.message}');
      collectedMetrics.add(metric);
      _processMetric(metric, metric.clientId, logger);
    },

    onResourceMetric: (metric) {
      logger.debug('Получена метрика ресурсов');
      collectedMetrics.add(metric);
      _processMetric(metric, metric.clientId, logger);
    },

    // Обработчик для логирования
    onLog: (metric) {
      logger.info('Получено сообщение лога: ${metric.content.message}');
      collectedMetrics.add(metric);
    },

    // Обработчик регистрации клиентов
    onRegisterClient: (clientIdentity) {
      logger.info('Клиент зарегистрирован: ${clientIdentity.clientId}');
      clientsInfo[clientIdentity.clientId] = clientIdentity;
      logger.debug('Информация о клиенте:', data: clientIdentity.toJson());
    },

    // Обработчик пинга
    onPing: () async {
      logger.debug('Получен пинг');
      return true;
    },
  );

  // Регистрируем контракт в эндпоинте
  diagnosticEndpoint.registerServiceContract(diagnosticContract);

  logger.info('Сервис диагностики запущен и ожидает подключений');
  logger.info('Для подключения клиентов используйте адрес: ws://$host:$port');

  // Обрабатываем сигналы завершения
  ProcessSignal.sigint.watch().listen((signal) async {
    logger.info('Получен сигнал завершения, закрываем сервер...');

    // Закрываем транспорт и эндпоинт
    await serverTransport.close();
    await diagnosticEndpoint.close();

    logger.info('Сервер остановлен');
    exit(0);
  });
}

/// Обрабатывает список метрик
void _processMetrics(List<RpcMetric> metrics, RpcLogger logger) {
  for (final metric in metrics) {
    _processMetric(metric, metric.clientId, logger);
  }
}

/// Обрабатывает отдельную метрику с выводом в лог
void _processMetric(RpcMetric metric, String clientId, RpcLogger logger) {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(metric.timestamp);
  final formattedTime = '${timestamp.hour}:${timestamp.minute}:${timestamp.second}';

  // В зависимости от типа метрики, логируем разную информацию
  switch (metric.metricType) {
    case RpcMetricType.trace:
      final traceMetric = metric.content as RpcTraceMetric;
      logger.debug(
        'Трассировка от $clientId: ${traceMetric.service}.${traceMetric.method}',
        data: {'time': formattedTime, 'type': traceMetric.eventType.name},
      );
      break;

    case RpcMetricType.latency:
      final latencyMetric = metric.content as RpcLatencyMetric;
      final durationMs = latencyMetric.endTime - latencyMetric.startTime;
      logger.debug(
        'Задержка от $clientId: ${latencyMetric.operation} (${durationMs}ms)',
        data: {'time': formattedTime, 'success': latencyMetric.success},
      );
      break;

    case RpcMetricType.error:
      final errorMetric = metric.content as RpcErrorMetric;
      logger.warning(
        'Ошибка от $clientId: ${errorMetric.message}',
        data: {'time': formattedTime, 'code': errorMetric.code},
      );
      break;

    case RpcMetricType.stream:
      final streamMetric = metric.content as RpcStreamMetric;
      logger.debug(
        'Стрим от $clientId: ${streamMetric.streamId}',
        data: {'time': formattedTime, 'event': streamMetric.eventType.name},
      );
      break;

    case RpcMetricType.resource:
      final resourceMetric = metric.content as RpcResourceMetric;
      logger.debug(
        'Ресурсы от $clientId',
        data: {
          'time': formattedTime,
          'memory': resourceMetric.memoryUsage,
          'cpu': resourceMetric.cpuUsage,
        },
      );
      break;

    default:
      logger.debug('Неизвестная метрика от $clientId: ${metric.metricType}');
  }
}
