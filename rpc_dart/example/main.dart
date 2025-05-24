// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования RPC Dart на основе содержимого README
///
/// Демонстрирует:
/// - Создание контракта API
/// - Серверная и клиентская реализации
/// - Все типы RPC взаимодействий:
///   - Унарный RPC
///   - Двунаправленный стриминг
///   - Серверный стриминг
///   - Клиентский стриминг
void main() async {
  // Настройка логгера с уровнем DEBUG
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);
  final logger = RpcLogger('Example');
  logger.info('Запуск примера RPC Dart...');

  // Создание транспортов в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединение транспортов между собой
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);

  // Создание эндпоинтов
  final client = RpcEndpoint(transport: clientTransport);
  final server = RpcEndpoint(transport: serverTransport);

  // Регистрация сервера
  final demoServer = DemoServer();
  server.registerServiceContract(demoServer);

  // Создание клиента
  final demoClient = DemoClient(client);

  // 1. Унарный RPC
  logger.info('=== Пример унарного RPC ===');
  try {
    final response = await demoClient.echo(RpcString("Привет!"));
    logger.info('Ответ: ${response.value}');
  } on RpcException catch (e) {
    logger.error('Ошибка RPC: ${e.message}');
  }

  // 2. Двунаправленный стриминг
  logger.info('=== Пример двунаправленного стриминга ===');
  try {
    logger.debug(
        'ДИАГНОСТИКА: Вызываем demoClient.chat() для создания двунаправленного стрима');
    final chat = demoClient.chat();
    logger.debug('ДИАГНОСТИКА: Получен объект chat типа: ${chat.runtimeType}');

    // Подписка на сообщения с детальным логированием
    logger.debug('ДИАГНОСТИКА: Подписываемся на сообщения из стрима chat');
    final subscription = chat.listen((message) {
      logger.info('Получено от сервера: "${message.value}"');
      logger.debug(
          'ДИАГНОСТИКА: Получено сообщение от сервера типа ${message.runtimeType}: JSON=${message.toJson()}');
    }, onError: (error) {
      logger.error('ДИАГНОСТИКА: Ошибка в стриме chat: $error');
    }, onDone: () {
      logger.debug('ДИАГНОСТИКА: Стрим chat завершен (вызван onDone)');
    });
    logger.debug(
        'ДИАГНОСТИКА: Подписка на стрим chat создана: ${subscription.hashCode}');

    // Ждем немного перед отправкой сообщений для установки соединения
    logger.debug('ДИАГНОСТИКА: Ожидаем 1 секунду перед отправкой сообщений');
    await Future.delayed(Duration(seconds: 1));
    logger.debug(
        'ДИАГНОСТИКА: Соединение установлено, начинаем отправку сообщений');

    // Отправка нескольких сообщений с увеличенными интервалами
    final messages = [
      "Привет, сервер!",
      "Как дела?",
      "Это тестирование двунаправленного стриминга"
    ];

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      logger.info('Отправка #${i + 1}: "$message"');
      logger.debug('ДИАГНОСТИКА: Вызываем chat.send() для сообщения #${i + 1}');
      chat.send(RpcString(message));
      logger.debug(
          'ДИАГНОСТИКА: Сообщение #${i + 1} отправлено через chat.send()');

      // Увеличиваем интервал до 500мс между сообщениями
      logger.debug(
          'ДИАГНОСТИКА: Ожидаем 500мс перед отправкой следующего сообщения');
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Ждем дольше перед завершением - 5 секунд
    logger.debug(
        'ДИАГНОСТИКА: Отправка сообщений завершена, ожидаем ответы от сервера (5 секунд)');
    await Future.delayed(Duration(seconds: 5));

    // Закрываем стрим
    logger.debug(
        'ДИАГНОСТИКА: Вызываем subscription.cancel() для отмены подписки');
    await subscription.cancel();
    logger.debug(
        'ДИАГНОСТИКА: Подписка отменена, вызываем chat.close() для закрытия стрима');
    await chat.close();
    logger.debug('ДИАГНОСТИКА: Стрим chat закрыт через chat.close()');
    logger.info('Чат завершен');
  } on RpcException catch (e) {
    logger.error('ДИАГНОСТИКА: Ошибка RpcException в чате: ${e.message}');
  } catch (e, stack) {
    logger.error('ДИАГНОСТИКА: Непредвиденная ошибка в чате: $e',
        error: e, stackTrace: stack);
  }

  // 3. Серверный стриминг
  logger.info('=== Пример серверного стриминга ===');
  try {
    final stream = demoClient.generateNumbers(RpcInt(5));
    await for (final number in stream) {
      logger.info('Получено число: ${number.value}');
    }
    logger.info('Стрим чисел завершен');
  } on RpcException catch (e) {
    logger.error('Ошибка при получении чисел: ${e.message}');
  }

  // 4. Клиентский стриминг
  logger.info('=== Пример клиентского стриминга ===');
  try {
    final counter = demoClient.countWords();

    final sentences = [
      "Привет мир",
      "Это пример клиентского стриминга",
      "В RPC Dart"
    ];

    for (final sentence in sentences) {
      logger.info('Отправка: "$sentence"');
      counter.send(RpcString(sentence));
    }

    await counter.finishSending();
    final wordCount = await counter.getResponse();
    logger.info('Всего слов: ${wordCount?.value}');
  } on RpcException catch (e) {
    logger.error('Ошибка при отправке слов: ${e.message}');
  }

  // Завершение работы примера
  logger.info('Пример завершен. Закрытие соединений...');
  await client.close();
  await server.close();
}

/// Контракт для демонстрационного сервиса
abstract class DemoServiceContract extends OldRpcServiceContract {
  DemoServiceContract() : super('demo_service');

  @override
  void setup() {
    // Регистрируем унарный метод
    addUnaryRequestMethod<RpcString, RpcString>(
      methodName: 'echo',
      handler: echo,
      argumentParser: RpcString.fromJson,
      responseParser: RpcString.fromJson,
    );

    // Регистрируем метод с серверным стримингом
    addServerStreamingMethod<RpcInt, RpcString>(
      methodName: 'generateNumbers',
      handler: generateNumbers,
      argumentParser: RpcInt.fromJson,
      responseParser: RpcString.fromJson,
    );

    // Регистрируем метод с клиентским стримингом
    addClientStreamingMethod<RpcString, RpcInt>(
      methodName: 'countWords',
      handler: countWords,
      argumentParser: RpcString.fromJson,
      responseParser: RpcInt.fromJson,
    );

    // Регистрируем двунаправленный метод
    addBidirectionalStreamingMethod<RpcString, RpcString>(
      methodName: 'chat',
      handler: chat,
      argumentParser: RpcString.fromJson,
      responseParser: RpcString.fromJson,
    );

    super.setup();
  }

  // Унарный метод - эхо
  Future<RpcString> echo(RpcString request);

  // Метод с клиентским стримингом
  ClientStreamingBidiStream<RpcString, RpcInt> countWords();

  // Метод с серверным стримингом
  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt count);

  // Двунаправленный метод
  BidiStream<RpcString, RpcString> chat();
}

/// Серверная реализация
final class DemoServer extends DemoServiceContract {
  final logger = RpcLogger('DemoServer');

  @override
  Future<RpcString> echo(RpcString request) async {
    logger.debug('Получен запрос echo: ${request.value}');
    return RpcString(request.value);
  }

  @override
  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt count) {
    // Создаем генератор с функцией, которая принимает стрим запросов и возвращает стрим ответов
    final generator = BidiStreamGenerator<RpcInt, RpcString>((requests) async* {
      for (int i = 1; i <= count.value; i++) {
        await Future.delayed(Duration(milliseconds: 500));
        yield RpcString('Число $i');
      }
    });

    // Создаем и возвращаем стрим для сервера
    return generator.createServerStreaming(initialRequest: count);
  }

  @override
  ClientStreamingBidiStream<RpcString, RpcInt> countWords() {
    final generator = BidiStreamGenerator<RpcString, RpcInt>((requests) async* {
      int totalWords = 0;

      await for (final request in requests) {
        final words =
            request.value.split(' ').where((word) => word.isNotEmpty).length;
        totalWords += words;
      }

      yield RpcInt(totalWords);
    });

    return generator.createClientStreaming();
  }

  @override
  BidiStream<RpcString, RpcString> chat() {
    final logger = RpcLogger('ChatServer');
    logger.debug('ДИАГНОСТИКА: chat: Создание обработчика чата');

    // Используем правильную реализацию с async* генератором
    final generator =
        BidiStreamGenerator<RpcString, RpcString>((requests) async* {
      logger.debug('ДИАГНОСТИКА: chat: Запущен генератор чата');

      // Сначала отправляем приветственное сообщение
      logger.debug('ДИАГНОСТИКА: chat: Отправляем приветственное сообщение');
      yield RpcString('Привет, я сервер!');

      // Обрабатываем входящие сообщения
      logger.debug(
          'ДИАГНОСТИКА: chat: Начинаем await for по входящим сообщениям');
      try {
        int messageCount = 0;
        await for (final request in requests) {
          messageCount++;
          logger.debug(
              'ДИАГНОСТИКА: chat: Получено сообщение #$messageCount от клиента: "${request.value}", тип: ${request.runtimeType}');

          // Формируем ответ с небольшой задержкой для имитации обработки
          logger.debug('ДИАГНОСТИКА: chat: Задержка перед ответом 100мс');
          await Future.delayed(Duration(milliseconds: 100));

          // Отправляем ответ
          final response = RpcString('Ответ на: "${request.value}"');
          logger.debug(
              'ДИАГНОСТИКА: chat: Подготовлен ответ: "${response.value}", тип: ${response.runtimeType}');
          logger
              .debug('ДИАГНОСТИКА: chat: Выполняем yield для отправки ответа');
          yield response;
          logger.debug('ДИАГНОСТИКА: chat: Ответ отправлен через yield');
        }
        logger.debug(
            'ДИАГНОСТИКА: chat: Цикл await for завершен, больше сообщений нет');
      } catch (e, stack) {
        logger.error('ДИАГНОСТИКА: chat: Ошибка в обработке запросов: $e',
            error: e, stackTrace: stack);
        // При ошибке отправляем специальное сообщение и затем завершаем стрим
        yield RpcString('Ошибка на сервере: $e');
      }

      logger.debug('ДИАГНОСТИКА: chat: Генератор завершает работу');
    });

    logger.debug('ДИАГНОСТИКА: chat: Создан BidiStream для чата');
    final stream = generator.create();
    logger.debug('ДИАГНОСТИКА: chat: Возвращаем BidiStream из метода chat()');
    return stream;
  }
}

/// Клиентская реализация
final class DemoClient extends DemoServiceContract {
  final RpcEndpoint _endpoint;

  DemoClient(this._endpoint);

  @override
  BidiStream<RpcString, RpcString> chat() {
    return _endpoint
        .bidirectionalStreaming(
          serviceName: 'demo_service',
          methodName: 'chat',
        )
        .call(
          responseParser: RpcString.fromJson,
        );
  }

  @override
  ClientStreamingBidiStream<RpcString, RpcInt> countWords() {
    return _endpoint
        .clientStreaming(
          serviceName: 'demo_service',
          methodName: 'countWords',
        )
        .call(
          responseParser: RpcInt.fromJson,
        );
  }

  @override
  Future<RpcString> echo(RpcString request) {
    return _endpoint
        .unaryRequest(
          serviceName: 'demo_service',
          methodName: 'echo',
        )
        .call(
          request: request,
          responseParser: RpcString.fromJson,
        );
  }

  @override
  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt count) {
    return _endpoint
        .serverStreaming(
          serviceName: 'demo_service',
          methodName: 'generateNumbers',
        )
        .call(
          request: count,
          responseParser: RpcString.fromJson,
        );
  }
}
