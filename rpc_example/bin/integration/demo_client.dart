// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';
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

  // Настраиваем логирование
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.info);
  final logger = DefaultRpcLogger(
    'DemoClient',
    coloredLoggingEnabled: true,
    colors: RpcLoggerColors(
      debug: AnsiColor.cyan,
      info: AnsiColor.brightGreen,
      warning: AnsiColor.brightYellow,
      error: AnsiColor.brightRed,
      critical: AnsiColor.magenta,
    ),
  );

  logger.info('Запуск демонстрационного клиента...');

  try {
    // Устанавливаем диагностический клиент в логгер для автоматической отправки логов
    final diagnosticClient = await factoryDiagnosticClient(
      diagnosticUrl: Uri.parse(diagnosticUrl),
      clientIdentity: RpcClientIdentity(
        clientId: clientId,
        traceId: traceId,
      ),
    );

    RpcLoggerSettings.setDiagnostic(diagnosticClient);
    logger.info('Диагностический клиент успешно инициализирован и подключен');
  } catch (e) {
    logger.error('Ошибка при инициализации диагностического клиента: $e');
  }

  // Создаем RPC эндпоинт для связи с сервером
  final transport = ClientWebSocketTransport.fromUrl(
    id: clientId,
    url: serverUrl,
  );

  final endpoint = RpcEndpoint(
    transport: transport,
    debugLabel: clientId,
  );

  await transport.connect();

  // Создаем клиента и регистрируем его методы
  final demoClient = DemoClient(endpoint);

  // Выполняем демонстрационные вызовы
  await _runDemo(demoClient, logger);

  // Закрываем соединение
  await endpoint.close();
  exit(0);
}

/// Демонстрационные вызовы различных RPC методов
Future<void> _runDemo(DemoClient client, RpcLogger logger) async {
  logger.info('=== Демо унарного вызова ===');
  final echoResponse = await client.echo(RpcString('Привет, сервер!'));
  logger.info('Ответ от сервера: ${echoResponse.value}');

  logger.info('=== Демо серверного стриминга ===');
  final numbersStream = client.generateNumbers(RpcInt(5));
  // Получаем числа из серверного стрима
  await for (final number in numbersStream) {
    logger.info('Получено число: ${number.value}');
  }
  logger.info('Стрим чисел завершен');

  logger.info('=== Демо клиентского стриминга ===');
  final wordsCounter = client.countWords();

  // Отправляем несколько предложений
  final sentences = [
    'Это первое предложение',
    'А это второе, оно длиннее',
    'Это последнее предложение для подсчета слов'
  ];

  for (final sentence in sentences) {
    wordsCounter.send(RpcString(sentence));
    logger.info('Отправлено: "$sentence"');
  }

  // Завершаем отправку
  await wordsCounter.finishSending();

  // Получаем результат
  final wordCount = await wordsCounter.getResponse();
  logger.info('Всего слов: ${wordCount?.value}');

  logger.info('=== Демо двунаправленного стриминга ===');
  final chat = client.chat();

  // Запускаем получение сообщений в отдельном потоке
  unawaited(_receiveMessages(chat, logger));

  // Отправляем несколько сообщений
  final messages = ['Привет, сервер!', 'Как дела?', 'Это тестирование двунаправленного стриминга'];

  for (final message in messages) {
    chat.send(RpcString(message));
    logger.info('Клиент отправил: "$message"');
    await Future.delayed(Duration(milliseconds: 500));
  }

  // Ждем некоторое время перед завершением
  await Future.delayed(Duration(seconds: 1));

  // Завершаем чат
  await chat.close();
  logger.info('Чат завершен');
}

/// Функция для получения и отображения сообщений из чата
Future<void> _receiveMessages(BidiStream<RpcString, RpcString> chat, RpcLogger logger) async {
  await for (final message in chat) {
    logger.info('Получено от сервера: "${message.value}"');
  }
}
