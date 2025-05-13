import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Простое сообщение для тестов
class SimpleMessage implements IRpcSerializableMessage {
  final String text;

  SimpleMessage(this.text);

  @override
  Map<String, dynamic> toJson() => {'text': text};

  static SimpleMessage fromJson(Map<String, dynamic> json) =>
      SimpleMessage(json['text'] as String);

  @override
  String toString() => 'SimpleMessage($text)';
}

void main() {
  group('Тестирование MemoryTransport с менеджерами стримов', () {
    late MemoryTransport transportA;
    late MemoryTransport transportB;
    late ServerStreamsManager<SimpleMessage> streamManager;

    setUp(() {
      // Создаем и соединяем транспорты
      transportA = MemoryTransport('transportA');
      transportB = MemoryTransport('transportB');

      transportA.connect(transportB);
      transportB.connect(transportA);

      // Создаем менеджер стримов
      streamManager = ServerStreamsManager<SimpleMessage>();

      print('Настройка тестов завершена');
    });

    tearDown(() async {
      await streamManager.dispose();
      await transportA.close();
      await transportB.close();
      print('Освобождение ресурсов завершено');
    });

    test('Базовый тест отправки и получения через MemoryTransport', () async {
      final receivedMessages = <String>[];
      final completer = Completer<void>();

      print('Настройка подписки на транспорт B');

      // Подписываемся на получение сообщений
      final subscription = transportB.receive().listen((data) {
        print('Транспорт B получил данные: ${data.length} байт');

        try {
          final jsonString = utf8.decode(data);
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final message = json['text'] as String;

          print('Декодировано сообщение: $message');
          receivedMessages.add(message);

          if (receivedMessages.length >= 3) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        } catch (e) {
          print('Ошибка при обработке данных: $e');
        }
      });

      print('Отправка тестовых сообщений');

      // Отправляем несколько сообщений
      for (var i = 1; i <= 3; i++) {
        final message = SimpleMessage('Test message $i');
        final json = message.toJson();
        final jsonString = jsonEncode(json);
        final data = Uint8List.fromList(utf8.encode(jsonString));

        print('Отправка сообщения $i: $jsonString');
        final result = await transportA.send(data);
        print('Результат отправки $i: $result');
      }

      // Ждем получения всех сообщений или тайм-аута
      print('Ожидание получения сообщений');
      await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print(
              'ПРЕДУПРЕЖДЕНИЕ: Истекло время ожидания, получено ${receivedMessages.length} сообщений');
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Проверяем результаты
      print('Проверка результатов');
      expect(receivedMessages.length, equals(3),
          reason: 'Должно быть получено 3 сообщения');
      expect(receivedMessages[0], equals('Test message 1'));
      expect(receivedMessages[1], equals('Test message 2'));
      expect(receivedMessages[2], equals('Test message 3'));

      // Очистка
      await subscription.cancel();
      print('Тест завершен успешно');
    });

    test('ServerStreamsManager с MemoryTransport', () async {
      final clientMessages = <String>[];
      final completer = Completer<void>();

      print('Создание клиентского стрима');
      // Создаем клиентский стрим через менеджер
      final clientStream = streamManager.createClientStream<SimpleMessage>();

      // Проверяем, что стрим создан
      expect(streamManager.activeClientCount, equals(1));
      final clientId = streamManager.getActiveClientIds().first;
      print('Создан клиентский стрим с ID: $clientId');

      // Обрабатываем данные от клиентского стрима
      clientStream.listen((message) {
        print('Клиентский стрим получил сообщение: ${message.text}');
        clientMessages.add(message.text);

        if (clientMessages.length >= 3) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });

      // Публикуем сообщения для клиента через менеджер
      print('Публикация сообщений через менеджер');
      streamManager.publish(SimpleMessage('Broadcast 1'));
      streamManager.publish(SimpleMessage('Broadcast 2'));
      streamManager.publishToClient(clientId, SimpleMessage('Direct message'));

      // Ждем получения всех сообщений или тайм-аута
      print('Ожидание получения сообщений');
      await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print(
              'ПРЕДУПРЕЖДЕНИЕ: Истекло время ожидания, получено ${clientMessages.length} сообщений');
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Проверяем результаты
      print('Проверка результатов');
      expect(clientMessages.length, equals(3),
          reason: 'Должно быть получено 3 сообщения');

      // Проверяем наличие всех сообщений (без учета порядка)
      expect(clientMessages,
          containsAll(['Broadcast 1', 'Broadcast 2', 'Direct message']),
          reason: 'Должны быть получены все сообщения в любом порядке');

      print('Тест завершен успешно');
    });

    test('ServerStreamsManager с несколькими клиентами', () async {
      // Создаем счетчики и списки сообщений для двух клиентов
      final clientMessages1 = <String>[];
      final clientMessages2 = <String>[];
      final allCompleted = Completer<void>();

      print('Создание нескольких клиентских стримов');

      // Создаем два клиентских стрима
      final clientStream1 = streamManager.createClientStream<SimpleMessage>();
      final clientStream2 = streamManager.createClientStream<SimpleMessage>();

      // Проверяем, что стримы созданы
      expect(streamManager.activeClientCount, equals(2));
      final clientIds = streamManager.getActiveClientIds();
      print('Созданы клиентские стримы с ID: ${clientIds.join(", ")}');

      // Функция проверки завершения для обоих клиентов
      void checkCompletion() {
        // Проверяем, что обе подписки получили хотя бы по одному сообщению
        if (clientMessages1.isNotEmpty &&
            clientMessages2.isNotEmpty &&
            !allCompleted.isCompleted) {
          allCompleted.complete();
        }
      }

      // Подписываемся на первый стрим
      clientStream1.listen((message) {
        print('Клиент 1 получил сообщение: ${message.text}');
        clientMessages1.add(message.text);
        checkCompletion();
      });

      // Подписываемся на второй стрим
      clientStream2.listen((message) {
        print('Клиент 2 получил сообщение: ${message.text}');
        clientMessages2.add(message.text);
        checkCompletion();
      });

      // Отправляем широковещательное сообщение
      print('Публикация широковещательного сообщения');
      streamManager.publish(SimpleMessage('Broadcast to all clients'));

      // Ждем получения сообщений обоими клиентами
      print('Ожидание получения сообщений');
      await allCompleted.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print(
              'ПРЕДУПРЕЖДЕНИЕ: Истекло время ожидания, получено сообщений: Клиент 1 - ${clientMessages1.length}, Клиент 2 - ${clientMessages2.length}');
          if (!allCompleted.isCompleted) {
            allCompleted.complete();
          }
        },
      );

      // Отправляем индивидуальное сообщение первому клиенту
      print('Отправка индивидуального сообщения первому клиенту');
      streamManager.publishToClient(
          clientIds[0], SimpleMessage('Message for client 1'));

      // Даем время на доставку
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем результаты
      print('Проверка результатов');

      // Оба клиента должны получить широковещательное сообщение
      expect(clientMessages1.contains('Broadcast to all clients'), isTrue);
      expect(clientMessages2.contains('Broadcast to all clients'), isTrue);

      // Всего должно быть как минимум 3 сообщения (2 широковещательных + 1 индивидуальное)
      expect(clientMessages1.length + clientMessages2.length,
          greaterThanOrEqualTo(3));

      print('Тест завершен успешно');
    });
  });
}
