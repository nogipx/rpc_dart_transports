import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

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
  group('ServerStreamsManager - расширенные тесты', () {
    late ServerStreamsManager<TestMessage> manager;

    setUp(() {
      manager = ServerStreamsManager<TestMessage>();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('должен обновлять время последней активности при публикации в клиента',
        () async {
      // Создаем стрим
      manager.createClientStream<TestMessage>();

      // Получаем ID
      final clientId = manager.getActiveClientIds().first;

      // Получаем текущее время активности
      final wrapper = manager.getClientInfo(clientId);
      expect(wrapper, isNotNull);

      final firstActivity = wrapper!.lastActivity;

      // Ждем немного
      await Future.delayed(Duration(milliseconds: 100));

      // Публикуем сообщение
      manager.publishToClient(
          clientId, TestMessage(content: 'update activity', id: 777));

      // Проверяем, что время активности обновилось
      final afterActivity = wrapper.lastActivity;
      expect(afterActivity.isAfter(firstActivity), isTrue);
    });

    test('должен корректно обрабатывать метаданные при публикации', () async {
      // Создаем стрим и получаем его ID
      final stream = manager.createClientStream<TestMessage>();

      // Готовим список для приема сообщений
      final receivedMessages = <TestMessage>[];

      // Подписываемся на стрим
      final sub = stream.listen(receivedMessages.add);

      // Метаданные
      final metadata = {'source': 'test', 'priority': 'high'};

      // Публикуем с метаданными
      final testMessage = TestMessage(content: 'with metadata', id: 42);

      // Публикуем как обернутое сообщение
      final wrappedMessage = StreamMessage<TestMessage>(
        message: testMessage,
        streamId: 'broadcast',
        metadata: metadata,
      );

      manager.publishWrapped(wrappedMessage);

      // Ждем доставки
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем
      expect(receivedMessages.length, equals(1));
      expect(receivedMessages.first, equals(testMessage));

      // Очищаем
      await sub.cancel();
    });

    test('должен проверять факт активности клиентов', () async {
      // Создаем стрим
      final stream = manager.createClientStream<TestMessage>();

      // Получаем его ID
      final clientId = manager.getActiveClientIds().first;

      // Проверка первоначальной длительности (должна быть маленькой)
      final wrapper = manager.getClientInfo(clientId);
      final initialDuration = wrapper!.getActiveDuration();
      expect(initialDuration.inMilliseconds, lessThan(100));

      // Ждем
      await Future.delayed(Duration(milliseconds: 150));

      // Проверяем, что длительность увеличилась
      final laterDuration = wrapper.getActiveDuration();
      expect(laterDuration.inMilliseconds,
          greaterThan(initialDuration.inMilliseconds));

      // Закрываем стрим
      await stream.close();
    });

    test('поведение стрима после закрытия', () async {
      // Создаем стрим
      final stream = manager.createClientStream<TestMessage>();

      // Получаем ID
      final clientId = manager.getActiveClientIds().first;

      // Готовим список для сбора сообщений
      final messages = <TestMessage>[];

      // Подписываемся
      final sub = stream.listen(messages.add);

      // Закрываем стрим
      await manager.closeClientStream(clientId);

      // Пытаемся опубликовать
      manager.publish(TestMessage(content: 'after close', id: 999));

      // Ждем
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что сообщение не было получено
      expect(messages, isEmpty);

      // Проверяем, что стрим удален
      expect(manager.getActiveClientIds().contains(clientId), isFalse);

      // Очищаем
      await sub.cancel();
    });

    test('проверка входящих запросов от клиента', () async {
      // Создаем стрим
      final stream = manager.createClientStream<TestMessage>();

      // Получаем ID клиента
      final clientId = manager.getActiveClientIds().first;

      // Готовим списки для событий
      final clientReceived = <TestMessage>[];

      // Подписываемся на стрим
      final sub = stream.listen(clientReceived.add);

      // Отправляем запрос с клиентской стороны
      // Это должно вызвать onDone в контроллере запросов
      stream.sendRequest(TestMessage(content: 'client request', id: 1));

      // Публикуем ответное сообщение
      manager.publishToClient(
          clientId, TestMessage(content: 'server response', id: 2));

      // Ждем обработки
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что клиент получил ответ
      expect(clientReceived.length, equals(1));
      expect(clientReceived.first.content, equals('server response'));

      // Закрываем стрим с клиентской стороны
      await stream.close();

      // Ждем обработки закрытия
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что стрим был удален из менеджера
      expect(manager.getActiveClientIds().contains(clientId), isFalse);

      // Очищаем
      await sub.cancel();
    });
  });
}
