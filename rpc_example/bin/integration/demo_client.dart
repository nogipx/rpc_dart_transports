// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:rpc_dart/diagnostics/models/rpc_client_identity.dart';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

import '_contract.dart';

/// Демонстрационный клиент
///
/// Отправляет RPC-запросы серверу и диагностические данные в сервис диагностики.
void main() async {
  // Парсим аргументы
  final serverUrl = 'ws://192.168.1.118:31000';
  final diagnosticUrl = 'ws://192.168.1.118:30000';

  // Создаем клиент диагностики
  final clientId = 'demo_client';
  final traceId = '${clientId}_${DateTime.now().millisecondsSinceEpoch}';

  // Устанавливаем диагностический клиент в логгер для автоматической отправки логов
  RpcLoggerSettings.setDiagnostic(factoryDiagnosticClient(
    diagnosticUrl: Uri.parse(diagnosticUrl),
    clientIdentity: RpcClientIdentity(
      clientId: clientId,
      traceId: traceId,
    ),
  ));

  // Настраиваем логирование
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);
  final logger = DefaultRpcLogger(
    'DemoClient',
    coloredLoggingEnabled: true,
    logColors: RpcLoggerColors(
      debug: AnsiColor.cyan,
      info: AnsiColor.brightGreen,
      warning: AnsiColor.brightYellow,
      error: AnsiColor.brightRed,
      critical: AnsiColor.magenta,
    ),
  );

  logger.info('Запуск демонстрационного клиента...');

  // Создаем RPC эндпоинт для связи с сервером
  final rpcEndpoint = RpcEndpoint(
    debugLabel: 'demo_client',
    transport: ClientWebSocketTransport.fromUrl(
      id: 'server_connection',
      url: serverUrl,
      autoConnect: true,
    ),
  );

  // Создаем клиентский контракт для работы с сервером
  final demoClient = DemoClient(rpcEndpoint);

  logger.info('Подключение к серверу: $serverUrl');
  logger.info('Подключение к сервису диагностики: $diagnosticUrl');

  // Запускаем демонстрацию RPC вызовов
  await _demonstrateRpcCalls(demoClient, logger);

  // Обрабатываем сигналы завершения
  ProcessSignal.sigint.watch().listen((signal) async {
    logger.info('Получен сигнал завершения, закрываем клиент...');

    // Закрываем все соединения
    await rpcEndpoint.close();

    logger.info('Клиент остановлен');
    exit(0);
  });
}

/// Демонстрирует различные RPC вызовы
Future<void> _demonstrateRpcCalls(DemoClient client, RpcLogger logger) async {
  final random = Random();

  // Демонстрация унарного вызова - echo
  Timer.periodic(Duration(seconds: 5), (timer) async {
    try {
      final request = RpcString('Привет от клиента! ${DateTime.now()}');

      logger.info('Отправка унарного запроса: ${request.value}');
      final response = await client.echo(request);

      logger.info('Получен ответ: ${response.value}');
    } catch (e) {
      logger.error('Ошибка при выполнении echo запроса', error: e);
    }
  });

  // Демонстрация стриминга от сервера - generateNumbers
  Timer.periodic(Duration(seconds: 15), (timer) async {
    try {
      final count = random.nextInt(5) + 3; // 3-7 чисел
      logger.info('Запрос генерации $count чисел');

      final generateNumbersStream = client.generateNumbers(RpcInt(count));

      // Обрабатываем стрим от сервера
      int received = 0;
      await for (final number in generateNumbersStream) {
        received++;
        logger.info('Получено число от сервера: ${number.value} ($received/$count)');
      }
    } catch (e) {
      logger.error('Ошибка при получении стрима чисел', error: e);
    }
  });

  // Демонстрация клиентского стриминга - countWords
  Timer.periodic(Duration(seconds: 20), (timer) async {
    try {
      logger.info('Отправка потока слов на сервер');

      // Создаем поток слов
      final words = [
        'Привет',
        'мир программирования',
        'RPC в действии',
        'Dart это здорово',
        'WebSocket транспорт работает'
      ];

      final countWordsStream = client.countWords();
      for (final sentence in words) {
        countWordsStream.send(RpcString(sentence));
      }
      await countWordsStream.finishSending();
      final result = await countWordsStream.getResponse();

      logger.info('Сервер насчитал ${result?.value} слов в переданном потоке');
    } catch (e) {
      logger.error('Ошибка при отправке стрима слов', error: e);
    }
  });

  // Ресурсы клиента
  Timer.periodic(Duration(seconds: 12), (timer) {
    // Моделируем использование ресурсов
    final memoryUsage = random.nextInt(50) + 20; // 20-70 MB
    final cpuUsage = random.nextDouble() * 15; // 0-15%

    // Отправляем метрику ресурсов
    final resourceMetric = logger.diagnostic?.createResourceMetric(
      memoryUsage: memoryUsage,
      cpuUsage: cpuUsage,
    );

    logger.diagnostic?.reportResourceMetric(resourceMetric!);

    logger.debug('Использование ресурсов: Память $memoryUsage MB, CPU $cpuUsage%');
  });
}
