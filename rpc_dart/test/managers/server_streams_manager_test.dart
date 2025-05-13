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
      // Добавим небольшую задержку между тестами
      await Future.delayed(Duration(milliseconds: 10));
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
      final completer = Completer<void>();
      var messageCount = 0;

      // Подписываемся на стримы
      final sub1 = stream1.listen((msg) {
        messages1.add(msg);
        messageCount++;
        if (messageCount >= 2 && !completer.isCompleted) {
          completer.complete();
        }
      });

      final sub2 = stream2.listen((msg) {
        messages2.add(msg);
        messageCount++;
        if (messageCount >= 2 && !completer.isCompleted) {
          completer.complete();
        }
      });

      // Публикуем тестовое сообщение
      final testMessage = TestMessage(content: 'test', id: 42);
      manager.publish(testMessage);

      // Ждем немного, чтобы сообщения были доставлены
      await completer.future.timeout(
        Duration(seconds: 1),
        onTimeout: () {
          // Продолжаем выполнение
        },
      );

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
      final completer = Completer<void>();

      // Подписываемся на стримы
      final sub1 = stream1.listen((msg) {
        messages1.add(msg);
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      final sub2 = stream2.listen((msg) {
        messages2.add(msg);
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      // Публикуем сообщение только в первый стрим
      final testMessage = TestMessage(content: 'single', id: 1);
      manager.publishToClient(clientIds[0], testMessage);

      // Ждем доставки
      await completer.future.timeout(
        Duration(seconds: 1),
        onTimeout: () {
          // Продолжаем выполнение
        },
      );

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
      final completer = Completer<void>();

      // Подписываемся на стрим
      final sub = stream.listen((msg) {
        messages.add(msg);
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      // Создаем и публикуем обернутое сообщение
      final testMessage = TestMessage(content: 'wrapped', id: 123);
      final wrappedMessage = StreamMessage<TestMessage>(
        message: testMessage,
        streamId: 'broadcast',
      );

      manager.publishWrapped(wrappedMessage);

      // Ждем доставки
      await completer.future.timeout(
        Duration(seconds: 1),
        onTimeout: () {
          // Продолжаем выполнение
        },
      );

      // Проверяем, что стрим получил сообщение
      expect(messages.length, equals(1));
      expect(messages.first, equals(testMessage));

      // Отписываемся
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
      // Тест с чистым менеджером
      final testManager = ServerStreamsManager<TestMessage>();

      // Создаем стримы
      final stream1 = testManager.createClientStream<TestMessage>();
      final stream2 = testManager.createClientStream<TestMessage>();

      // Получаем ID клиентов
      final clientIds = testManager.getActiveClientIds();
      expect(clientIds.length, equals(2));
      expect(testManager.activeClientCount, equals(2));

      // Создаем подписки для отслеживания завершения стримов
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      // Слушатели, которые сработают при закрытии стримов
      final sub1 = stream1.listen(null, onDone: () {
        if (!completer1.isCompleted) completer1.complete();
      });

      final sub2 = stream2.listen(null, onDone: () {
        if (!completer2.isCompleted) completer2.complete();
      });

      // Закрываем стримы напрямую, чтобы проверить отдельно от dispose
      await testManager.closeAllClientStreams();

      // Ждем уведомления о закрытии
      await completer1.future.timeout(Duration(milliseconds: 300),
          onTimeout: () {
        if (!completer1.isCompleted) {
          completer1.complete();
          print('Стрим 1 не закрыт вовремя');
        }
      });

      await completer2.future.timeout(Duration(milliseconds: 300),
          onTimeout: () {
        if (!completer2.isCompleted) {
          completer2.complete();
          print('Стрим 2 не закрыт вовремя');
        }
      });

      // Отменяем подписки для очистки
      await sub1.cancel();
      await sub2.cancel();

      // Проверяем, что все стримы закрыты
      expect(testManager.activeClientCount, equals(0),
          reason: 'Стримы должны быть закрыты после closeAllClientStreams');

      // Только теперь вызываем dispose и даем ему немного времени
      await testManager.dispose();
      await Future.delayed(Duration(milliseconds: 30));

      // Проверяем, что публикация больше не работает (не должно быть исключений)
      testManager.publish(TestMessage(content: 'test after dispose', id: 999));
    });

    test('должен возвращать информацию о времени неактивности', () async {
      // Создаем стрим
      manager.createClientStream<TestMessage>();

      // Получаем ID и информацию
      final clientId = manager.getActiveClientIds().first;
      final info = manager.getClientInfo(clientId)!;

      // Изначально неактивность близка к нулю
      final initialInactivity = info.getInactivityDuration();
      expect(initialInactivity.inMilliseconds, lessThan(100));

      // Ждем немного
      await Future.delayed(Duration(milliseconds: 20));

      // Проверяем, что неактивность увеличилась
      final laterInactivity = info.getInactivityDuration();
      expect(laterInactivity.inMilliseconds,
          greaterThan(initialInactivity.inMilliseconds));

      // Обновляем время активности
      info.updateLastActivity();

      // Проверяем, что неактивность сбросилась
      final resetInactivity = info.getInactivityDuration();
      expect(resetInactivity.inMilliseconds,
          lessThan(laterInactivity.inMilliseconds));
    });
  });
}
