// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:math' as math;
import 'package:rpc_dart/diagnostics.dart';

/// Пример продвинутой диагностики с кастомным логгером и метриками
Future<void> main({bool debug = true}) async {
  print('\n=== Продвинутый пример диагностики в RPC ===\n');

  // Настраиваем логирование
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Создаем цветной логгер для диагностики
  final logger = DefaultRpcLogger(
    'DiagnosticsDemo',
    coloredLoggingEnabled: true,
    logColors: RpcLoggerColors(
      debug: AnsiColor.cyan,
      info: AnsiColor.brightGreen,
      warning: AnsiColor.brightYellow,
      error: AnsiColor.brightRed,
      critical: AnsiColor.magenta,
    ),
  );

  logger.info('Инициализация приложения');

  try {
    // Демонстрация метрик производительности с помощью простой утилиты
    logger.info('Начинаем демонстрацию метрик производительности');

    final metrics = <String, List<int>>{};

    // Измеряем время выполнения разных операций
    await measureOperation('fast_operation', metrics, () async {
      await Future.delayed(Duration(milliseconds: 10));
    });

    await measureOperation('medium_operation', metrics, () async {
      await Future.delayed(Duration(milliseconds: 100));
    });

    await measureOperation('slow_operation', metrics, () async {
      await Future.delayed(Duration(milliseconds: 300));
    });

    // Повторяем для получения статистики
    for (int i = 0; i < 5; i++) {
      await measureOperation('fast_operation', metrics, () async {
        await Future.delayed(
          Duration(milliseconds: 10 + math.Random().nextInt(20)),
        );
      });

      await measureOperation('medium_operation', metrics, () async {
        await Future.delayed(
          Duration(milliseconds: 100 + math.Random().nextInt(50)),
        );
      });

      await measureOperation('slow_operation', metrics, () async {
        await Future.delayed(
          Duration(milliseconds: 300 + math.Random().nextInt(100)),
        );
      });
    }

    // Анализируем собранные метрики
    logger.info('Анализ собранных метрик производительности:');

    for (final entry in metrics.entries) {
      final opName = entry.key;
      final timings = entry.value;

      final minValue = timings.reduce((a, b) => math.min(a, b));
      final maxValue = timings.reduce((a, b) => math.max(a, b));
      final avg = timings.reduce((a, b) => a + b) / timings.length;
      final p95 = calculatePercentile(timings, 95);

      logger.info(
        '📊 Операция: $opName',
        data: {
          'запусков': timings.length,
          'мин (мс)': minValue,
          'макс (мс)': maxValue,
          'ср (мс)': avg.toStringAsFixed(2),
          'p95 (мс)': p95,
        },
      );
    }

    // Демонстрация обработки ошибок
    logger.info('Демонстрация обработки и анализа ошибок');

    final errorLogger = RpcLogger('ErrorHandler');

    try {
      // Имитируем ошибку в приложении
      await executeWithPotentialError();
    } catch (e, stack) {
      // Регистрируем ошибку с подробной диагностической информацией
      errorLogger.error(
        'Произошла ошибка в приложении',
        error: e,
        stackTrace: stack,
        context: 'UserService.login',
        data: {
          'user_id': '12345',
          'session_id': generateSessionId(),
          'timestamp': DateTime.now().toIso8601String(),
          'client_info': {
            'platform': 'iOS',
            'version': '15.2',
            'device': 'iPhone 13 Pro',
          },
        },
      );

      // Анализируем ошибку и предлагаем решение
      logger.info(
        'Анализ ошибки:',
        data: {
          'тип_ошибки': e.runtimeType.toString(),
          'сообщение': e.toString(),
          'рекомендации': 'Проверить соединение и повторить попытку',
          'код_ошибки': 'ERR_CONNECTION_FAILED',
        },
      );
    }

    // Демонстрация трассировки
    logger.info('Демонстрация трассировки запросов');

    final traceId = generateTraceId();
    final traceLogger = RpcLogger('Trace');

    traceLogger.info(
      'Начало обработки запроса',
      data: {'trace_id': traceId, 'request_id': generateRequestId()},
    );

    // Имитация многоуровневого вызова с трассировкой
    await executeWithTracing(traceId, traceLogger, 1);

    traceLogger.info(
      'Завершение обработки запроса',
      data: {'trace_id': traceId, 'status': 'success', 'duration_ms': 1500},
    );
  } catch (e, stack) {
    logger.error(
      'Необработанная ошибка в примере',
      error: e,
      stackTrace: stack,
    );
  }

  print('\n=== Пример завершен ===\n');
}

// Вспомогательные функции

/// Измеряет время выполнения операции и собирает метрики
Future<void> measureOperation(
  String operationName,
  Map<String, List<int>> metrics,
  Future<void> Function() operation,
) async {
  final logger = RpcLogger('Performance');

  // Начинаем замер времени
  final stopwatch = Stopwatch()..start();

  // Выполняем операцию
  await operation();

  // Завершаем замер
  stopwatch.stop();
  final elapsedMs = stopwatch.elapsedMilliseconds;

  // Сохраняем результат
  metrics.putIfAbsent(operationName, () => []).add(elapsedMs);

  logger.debug('Выполнена операция $operationName за $elapsedMsмс');
}

/// Вычисляет процентиль для массива значений
int calculatePercentile(List<int> values, int percentile) {
  if (values.isEmpty) return 0;
  if (values.length == 1) return values.first;

  // Сортируем копию массива
  final sortedValues = List<int>.from(values)..sort();

  // Вычисляем индекс для процентиля
  final n = (sortedValues.length - 1) * percentile / 100;
  final k = n.floor();
  final d = n - k;

  // Если k+1 выходит за границы массива, возвращаем последнее значение
  if (k >= sortedValues.length - 1) return sortedValues.last;

  // Линейная интерполяция
  return (sortedValues[k] + d * (sortedValues[k + 1] - sortedValues[k]))
      .round();
}

/// Имитирует операцию, которая может завершиться с ошибкой
Future<void> executeWithPotentialError() async {
  await Future.delayed(Duration(milliseconds: 200));
  throw StateError('Не удалось установить соединение с сервером');
}

/// Генерирует случайный идентификатор сессии
String generateSessionId() {
  final random = math.Random();
  return 'sess_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}';
}

/// Генерирует идентификатор запроса
String generateRequestId() {
  final random = math.Random();
  return 'req_${random.nextInt(1000000).toString().padLeft(6, '0')}';
}

/// Генерирует идентификатор трассировки
String generateTraceId() {
  final random = math.Random();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'trace_${timestamp}_${random.nextInt(1000000).toString().padLeft(6, '0')}';
}

/// Имитирует вложенные вызовы с трассировкой
Future<void> executeWithTracing(
  String traceId,
  RpcLogger logger,
  int depth,
) async {
  final serviceName =
      ['AuthService', 'UserService', 'DatabaseService', 'CacheService'][depth %
          4];
  final methodName = ['validate', 'getProfile', 'query', 'fetch'][depth % 4];

  logger.debug(
    '[$depth] Вызов $serviceName.$methodName',
    data: {
      'trace_id': traceId,
      'depth': depth,
      'service': serviceName,
      'method': methodName,
    },
  );

  // Имитация задержки
  await Future.delayed(Duration(milliseconds: 100));

  if (depth < 3) {
    // Рекурсивно вызываем вложенный уровень
    await executeWithTracing(traceId, logger, depth + 1);
  }

  logger.debug(
    '[$depth] Завершение $serviceName.$methodName',
    data: {
      'trace_id': traceId,
      'depth': depth,
      'service': serviceName,
      'method': methodName,
      'duration_ms': 100 + (depth < 3 ? 300 : 0),
    },
  );
}
