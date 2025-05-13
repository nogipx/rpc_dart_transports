import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

import 'package:rpc_dart/src/managers/server_streams_manager.dart';
import 'package:rpc_dart/src/managers/stream_message.dart';

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

  @override
  String toString() => 'TestMessage(content: $content, id: $id)';
}

void main() {
  group('ServerStreamsManager', () {
    late ServerStreamsManager<TestMessage> manager;

    setUp(() {
      manager = ServerStreamsManager<TestMessage>();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('должен создавать клиентский стрим', () {
      final stream = manager.createClientStream<TestMessage>();
      expect(stream, isNotNull);
      expect(manager.activeClientCount, equals(1));
    });

    test('должен публиковать данные во все стримы', () async {
      // Создаем два клиентских стрима
      final stream1 = manager.createClientStream<TestMessage>();
      final stream2 = manager.createClientStream<TestMessage>();

      // Готовим списки для сбора сообщений из стримов
      final messages1 = <TestMessage>[];
      final messages2 = <TestMessage>[];

      // Подписываемся на стримы
      final sub1 = stream1.listen(messages1.add);
      final sub2 = stream2.listen(messages2.add);

      // Публикуем тестовое сообщение
      final testMessage = TestMessage(content: 'test', id: 42);
      manager.publish(testMessage);

      // Ждем немного, чтобы сообщения были доставлены
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что оба стрима получили сообщение
      expect(messages1.length, equals(1));
      expect(messages2.length, equals(1));
      expect(messages1.first, equals(testMessage));
      expect(messages2.first, equals(testMessage));

      // Отписываемся, чтобы избежать утечек
      await sub1.cancel();
      await sub2.cancel();
    });

    test('должен публиковать данные в конкретный стрим', () async {
      // Создаем два клиентских стрима
      final stream1 = manager.createClientStream<TestMessage>();
      final stream2 = manager.createClientStream<TestMessage>();

      // Получаем их ID
      final clientIds = manager.getActiveClientIds();
      expect(clientIds.length, equals(2));

      // Готовим списки для сбора сообщений из стримов
      final messages1 = <TestMessage>[];
      final messages2 = <TestMessage>[];

      // Подписываемся на стримы
      final sub1 = stream1.listen(messages1.add);
      final sub2 = stream2.listen(messages2.add);

      // Публикуем сообщение только в первый стрим
      final testMessage = TestMessage(content: 'single', id: 1);
      manager.publishToClient(clientIds[0], testMessage);

      // Ждем немного, чтобы сообщение было доставлено
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что только один стрим получил сообщение
      // Точно не знаем, какой стрим имеет ID clientIds[0],
      // так что проверяем, что в сумме получено одно сообщение
      expect(messages1.length + messages2.length, equals(1));

      // Отписываемся, чтобы избежать утечек
      await sub1.cancel();
      await sub2.cancel();
    });

    test('должен публиковать обернутые сообщения', () async {
      // Создаем клиентский стрим
      final stream = manager.createClientStream<TestMessage>();

      // Готовим список для сбора сообщений
      final messages = <TestMessage>[];

      // Подписываемся на стрим
      final sub = stream.listen(messages.add);

      // Создаем и публикуем обернутое сообщение
      final testMessage = TestMessage(content: 'wrapped', id: 123);
      final wrappedMessage = StreamMessage<TestMessage>(
        message: testMessage,
        streamId: 'broadcast',
      );

      manager.publishWrapped(wrappedMessage);

      // Ждем немного, чтобы сообщение было доставлено
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что стрим получил сообщение
      expect(messages.length, equals(1));
      expect(messages.first, equals(testMessage));

      // Отписываемся, чтобы избежать утечек
      await sub.cancel();
    });

    test('должен возвращать список активных клиентов', () {
      // Изначально список пуст
      expect(manager.getActiveClientIds(), isEmpty);

      // Создаем несколько стримов
      manager.createClientStream<TestMessage>();
      manager.createClientStream<TestMessage>();
      manager.createClientStream<TestMessage>();

      // Проверяем, что список содержит 3 элемента
      expect(manager.getActiveClientIds().length, equals(3));
    });

    test('должен правильно считать количество активных клиентов', () {
      expect(manager.activeClientCount, equals(0));

      manager.createClientStream<TestMessage>();
      expect(manager.activeClientCount, equals(1));

      manager.createClientStream<TestMessage>();
      expect(manager.activeClientCount, equals(2));
    });

    test('должен закрывать конкретный клиентский стрим', () async {
      // Создаем несколько стримов
      manager.createClientStream<TestMessage>();
      manager.createClientStream<TestMessage>();

      // Получаем список ID
      final clientIds = manager.getActiveClientIds();
      expect(clientIds.length, equals(2));

      // Закрываем первый стрим
      await manager.closeClientStream(clientIds[0]);

      // Проверяем, что осталось стримов на 1 меньше
      expect(manager.activeClientCount, equals(1));
      expect(manager.getActiveClientIds().length, equals(1));
      expect(manager.getActiveClientIds().contains(clientIds[0]), isFalse);
    });

    test('должен закрывать все клиентские стримы', () async {
      // Создаем несколько стримов
      manager.createClientStream<TestMessage>();
      manager.createClientStream<TestMessage>();
      manager.createClientStream<TestMessage>();

      expect(manager.activeClientCount, equals(3));

      // Закрываем все стримы
      await manager.closeAllClientStreams();

      // Проверяем, что все стримы закрыты
      expect(manager.activeClientCount, equals(0));
      expect(manager.getActiveClientIds(), isEmpty);
    });

    test('должен освобождать все ресурсы при dispose', () async {
      // Создаем стримы
      manager.createClientStream<TestMessage>();
      manager.createClientStream<TestMessage>();

      expect(manager.activeClientCount, equals(2));

      // Вызываем dispose
      await manager.dispose();

      // Проверяем, что все стримы закрыты
      expect(manager.activeClientCount, equals(0));
      expect(manager.getActiveClientIds(), isEmpty);

      // Проверяем, что публикация больше не работает (не должно быть исключений)
      manager.publish(TestMessage(content: 'test after dispose', id: 999));
    });
  });
}
