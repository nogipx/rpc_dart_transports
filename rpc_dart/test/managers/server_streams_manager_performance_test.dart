import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

import 'package:rpc_dart/src/managers/server_streams_manager.dart';

// Тестовое сообщение для использования в тестах
class TestMessage implements IRpcSerializableMessage {
  final String content;
  final int id;

  TestMessage({required this.content, required this.id});

  @override
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'id': id,
    };
  }

  static TestMessage fromJson(Map<String, dynamic> json) {
    return TestMessage(
      content: json['content'] as String,
      id: json['id'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestMessage &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          id == other.id;

  @override
  int get hashCode => content.hashCode ^ id.hashCode;
}

void main() {
  group('ServerStreamsManager - стресс-тесты', () {
    late ServerStreamsManager<TestMessage> manager;

    setUp(() {
      manager = ServerStreamsManager<TestMessage>();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test(
        'должен обрабатывать последовательность сообщений в правильном порядке',
        () async {
      // Создаем стримы
      final stream1 = manager.createClientStream<TestMessage>();
      final stream2 = manager.createClientStream<TestMessage>();

      // Готовим списки для сбора сообщений
      final messages1 = <TestMessage>[];
      final messages2 = <TestMessage>[];

      // Подписываемся на стримы
      final sub1 = stream1.listen(messages1.add);
      final sub2 = stream2.listen(messages2.add);

      // Публикуем серию сообщений
      for (int i = 0; i < 100; i++) {
        final message = TestMessage(content: 'message-$i', id: i);
        manager.publish(message);

        // Добавляем небольшую задержку для имитации реальной нагрузки
        if (i % 10 == 0) {
          await Future.delayed(Duration(milliseconds: 1));
        }
      }

      // Даем время на обработку всех сообщений
      await Future.delayed(Duration(milliseconds: 100));

      // Проверяем количество сообщений
      expect(messages1.length, equals(100));
      expect(messages2.length, equals(100));

      // Проверяем правильный порядок сообщений
      for (int i = 0; i < 100; i++) {
        expect(messages1[i].id, equals(i));
        expect(messages2[i].id, equals(i));
        expect(messages1[i].content, equals('message-$i'));
        expect(messages2[i].content, equals('message-$i'));
      }

      // Очищаем
      await sub1.cancel();
      await sub2.cancel();
    });

    test('должен обрабатывать добавление и удаление стримов во время работы',
        () async {
      // Создаем первоначальные стримы
      final streams = <ServerStreamingBidiStream<TestMessage, TestMessage>>[];
      final allReceivedMessages = <List<TestMessage>>[];
      final subscriptions = <StreamSubscription<TestMessage>>[];

      // Функция для создания стрима и подписки
      Future<void> addStream() async {
        final stream = manager.createClientStream<TestMessage>();
        streams.add(stream);

        final messages = <TestMessage>[];
        allReceivedMessages.add(messages);

        final sub = stream.listen(messages.add);
        subscriptions.add(sub);
      }

      // Создаем первые 5 стримов
      for (int i = 0; i < 5; i++) {
        await addStream();
      }

      // Начинаем публиковать сообщения
      for (int i = 0; i < 50; i++) {
        manager.publish(TestMessage(content: 'batch1-$i', id: i));

        // На каждой 10-й итерации добавляем новый стрим
        if (i % 10 == 0 && i > 0) {
          await addStream();
        }

        // На каждой 15-й итерации удаляем случайный стрим
        if (i % 15 == 0 && i > 0 && manager.activeClientCount > 3) {
          final idToRemove =
              manager.getActiveClientIds()[i % manager.activeClientCount];
          await manager.closeClientStream(idToRemove);
        }

        // Небольшая задержка
        if (i % 10 == 0) {
          await Future.delayed(Duration(milliseconds: 5));
        }
      }

      // Публикуем еще пачку сообщений
      for (int i = 50; i < 100; i++) {
        manager.publish(TestMessage(content: 'batch2-$i', id: i));
      }

      // Ждем обработки
      await Future.delayed(Duration(milliseconds: 100));

      // Проверяем, что все активные стримы получили сообщения
      for (int i = 0; i < allReceivedMessages.length; i++) {
        if (i < manager.activeClientCount) {
          // Этот стрим должен был получить сообщения
          expect(allReceivedMessages[i].isNotEmpty, isTrue);
        }
      }

      // Очищаем
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    });

    test('должен правильно обрабатывать ошибки и не влиять на другие стримы',
        () async {
      // Создаем стримы
      final stream1 = manager.createClientStream<TestMessage>();
      final stream2 = manager.createClientStream<TestMessage>();

      // ID стримов
      final clientIds = manager.getActiveClientIds();
      final id1 = clientIds[0];
      final id2 = clientIds[1];

      // Списки сообщений и ошибок
      final messages1 = <TestMessage>[];
      final messages2 = <TestMessage>[];
      final errors1 = <Object>[];
      final errors2 = <Object>[];

      // Подписываемся с обработчиками ошибок
      final sub1 = stream1.listen(
        messages1.add,
        onError: errors1.add,
      );

      final sub2 = stream2.listen(
        messages2.add,
        onError: errors2.add,
      );

      // Отправляем сообщение
      manager.publish(TestMessage(content: 'normal message', id: 1));

      // Ждем доставки первого сообщения перед закрытием стрима
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что оба стрима получили первое сообщение
      expect(messages1.length, equals(1));
      expect(messages2.length, equals(1));

      // Имитируем ошибку в одном из стримов (закрываем и пытаемся отправить)
      await manager.closeClientStream(id1);

      // Отправляем индивидуальные сообщения (одно пойдет в закрытый стрим)
      manager.publishToClient(
          id1, TestMessage(content: 'to closed stream', id: 2));
      manager.publishToClient(
          id2, TestMessage(content: 'to active stream', id: 3));

      // Отправляем широковещательное сообщение
      manager.publish(TestMessage(content: 'broadcast after error', id: 4));

      // Ждем
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что первый стрим не получил сообщений после закрытия
      expect(messages1.length, equals(1)); // только первое сообщение

      // Проверяем, что второй стрим получил все сообщения
      expect(messages2.length,
          equals(3)); // первое, индивидуальное и широковещательное

      // Проверяем ID сообщений второго стрима
      expect(messages2.map((m) => m.id).toList(), equals([1, 3, 4]));

      // Очищаем
      await sub1.cancel();
      await sub2.cancel();
    });
  });
}
