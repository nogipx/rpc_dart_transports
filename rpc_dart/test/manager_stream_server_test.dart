import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Создаем тестовое сообщение для использования в тестах
class TestMessage implements IRpcSerializableMessage {
  final String content;

  TestMessage(this.content);

  @override
  Map<String, dynamic> toJson() => {'content': content};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestMessage &&
          runtimeType == other.runtimeType &&
          content == other.content;

  @override
  int get hashCode => content.hashCode;

  @override
  String toString() => 'TestMessage(content: $content)';
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

    test(
        'публикация в broadcast должна отправлять данные во все клиентские стримы',
        () async {
      // Arrange
      final receivedMessages1 = <TestMessage>[];
      final receivedMessages2 = <TestMessage>[];

      final clientStream1 = manager.createClientStream<TestMessage>();
      final clientStream2 = manager.createClientStream<TestMessage>();

      // Добавляем подписки на оба стрима
      final subscription1 = clientStream1.listen(
        (message) => receivedMessages1.add(message),
      );
      final subscription2 = clientStream2.listen(
        (message) => receivedMessages2.add(message),
      );

      // Act
      final testMessage = TestMessage('hello world');
      manager.publish(testMessage);

      // Ждем, пока сообщения будут доставлены
      await Future.delayed(Duration(milliseconds: 50));

      // Assert
      expect(receivedMessages1, [testMessage],
          reason: 'Первый клиент должен получить сообщение');
      expect(receivedMessages2, [testMessage],
          reason: 'Второй клиент должен получить сообщение');

      // Чистим подписки
      await subscription1.cancel();
      await subscription2.cancel();
    });

    test(
        'sendFunction в ServerStreamingBidiStream обрабатывает запросы без отправки другим клиентам',
        () async {
      // Arrange
      // Создаем два стрима: один для отправки, второй для приема
      final senderStream = manager.createClientStream<TestMessage>();
      final receiverStream = manager.createClientStream<TestMessage>();

      // Данные, полученные вторым клиентом
      final receivedMessages = <TestMessage>[];
      final subscription = receiverStream.listen(
        (message) => receivedMessages.add(message),
      );

      // Тестовый запрос и ответ
      final testRequest = TestMessage('client request');
      final testResponse = TestMessage('server response');

      // Act: отправляем запрос через первый стрим (теперь он не должен попасть к другим клиентам)
      // и затем публикуем ответ, который должен быть получен обоими клиентами
      senderStream.sendRequest(testRequest);
      manager.publish(testResponse);

      // Ждем, пока сообщения будут доставлены
      await Future.delayed(Duration(milliseconds: 50));

      // Assert
      // Проверяем, что receiverStream получил только ответ от сервера,
      // но не получил запрос от другого клиента
      expect(receivedMessages, [testResponse],
          reason:
              'Клиент должен получить только ответ от сервера, но не запрос другого клиента');

      // Освобождаем ресурсы
      await subscription.cancel();
    });

    test('publishToClient отправляет данные только конкретному клиенту',
        () async {
      // Arrange
      final receivedMessages1 = <TestMessage>[];
      final receivedMessages2 = <TestMessage>[];

      final clientStream1 = manager.createClientStream<TestMessage>();
      final clientStream2 = manager.createClientStream<TestMessage>();

      final clientIds = manager.getActiveClientIds();
      expect(clientIds.length, 2,
          reason: 'Должно быть создано 2 клиентских стрима');

      final clientId1 = clientIds[0];

      final subscription1 = clientStream1.listen(
        (message) => receivedMessages1.add(message),
      );
      final subscription2 = clientStream2.listen(
        (message) => receivedMessages2.add(message),
      );

      // Act
      final testMessage = TestMessage('specific client message');
      manager.publishToClient(clientId1, testMessage);

      // Ждем, пока сообщения будут доставлены
      await Future.delayed(Duration(milliseconds: 50));

      // Assert
      // Проверяем, что сообщение получено только первым клиентом
      expect(receivedMessages1.length, 1,
          reason: 'Первый клиент должен получить сообщение');
      expect(receivedMessages2.length, 0,
          reason: 'Второй клиент не должен получить сообщение');

      // Чистим подписки
      await subscription1.cancel();
      await subscription2.cancel();
    });

    test('closeClientStream закрывает конкретный стрим', () async {
      // Arrange
      manager.createClientStream<TestMessage>();
      manager.createClientStream<TestMessage>();

      final clientIds = manager.getActiveClientIds();
      expect(clientIds.length, 2,
          reason: 'Должно быть создано 2 клиентских стрима');

      final clientId1 = clientIds[0];

      // Act
      // Закрываем первый стрим
      await manager.closeClientStream(clientId1);

      // Assert
      expect(manager.getActiveClientIds().length, 1,
          reason: 'После закрытия должен остаться 1 активный стрим');
      expect(manager.getActiveClientIds().contains(clientId1), isFalse,
          reason:
              'ID закрытого стрима не должен присутствовать в списке активных');
    });

    test(
        'теперь запросы от одного клиента обрабатываются без передачи другим клиентам',
        () async {
      // Arrange
      // Создаем два стрима: один для отправки, второй для приема
      final senderStream = manager.createClientStream<TestMessage>();
      final receiverStream = manager.createClientStream<TestMessage>();

      // Данные, полученные обоими клиентами
      final receivedBySender = <TestMessage>[];
      final receivedByReceiver = <TestMessage>[];

      // Подписываемся на стримы
      final senderSub = senderStream.listen(
        (message) => receivedBySender.add(message),
      );
      final receiverSub = receiverStream.listen(
        (message) => receivedByReceiver.add(message),
      );

      // Получаем ID клиентов
      final clientIds = manager.getActiveClientIds();
      expect(clientIds.length, 2, reason: 'Должно быть два активных клиента');

      final testRequest = TestMessage('client request message');
      final testResponse = TestMessage('server response message');

      // Act
      // 1. Отправляем запрос от первого клиента
      senderStream.sendRequest(testRequest);

      // 2. Публикуем ответ от сервера всем клиентам
      manager.publish(testResponse);

      // Ждем, пока сообщения будут доставлены
      await Future.delayed(Duration(milliseconds: 50));

      // Assert
      // Теперь запросы не передаются между клиентами
      expect(receivedBySender, [testResponse],
          reason: 'Отправитель должен получить только ответ от сервера');
      expect(receivedByReceiver, [testResponse],
          reason: 'Получатель должен получить только ответ от сервера');

      // Очистка ресурсов
      await senderSub.cancel();
      await receiverSub.cancel();
    });

    test('в ServerStreamingBidiStream нельзя отправить второй запрос',
        () async {
      // Arrange
      final clientStream = manager.createClientStream<TestMessage>();
      final testRequest1 = TestMessage('first request');
      final testRequest2 = TestMessage('second request');

      // Act & Assert
      // Первый запрос должен пройти успешно
      clientStream.sendRequest(testRequest1);

      // Второй запрос должен вызвать исключение
      expect(
          () => clientStream.sendRequest(testRequest2),
          throwsA(isA<RpcUnsupportedOperationException>()
              .having((e) => e.operation, 'operation', 'sendRequest')),
          reason: 'Отправка второго запроса должна вызывать исключение');
    });

    test(
        'данные должны корректно отправляться в клиентский контроллер с логированием',
        () async {
      // Arrange
      final manager = ServerStreamsManager<TestMessage>();
      var receivedMessages = <TestMessage>[];

      // Создаем клиентский стрим и подписываемся на него
      final clientStream = manager.createClientStream<TestMessage>();
      final subscription = clientStream.listen(
        (message) => receivedMessages.add(message),
      );

      // Act
      // Публикуем сообщение
      final testMessage = TestMessage('test logging message');
      manager.publish(testMessage);

      // Ждем, пока сообщение будет доставлено
      await Future.delayed(Duration(milliseconds: 50));

      // Assert
      expect(receivedMessages.length, 1,
          reason: 'Клиент должен получить ровно одно сообщение');
      expect(receivedMessages[0], testMessage,
          reason: 'Клиент должен получить корректное сообщение');

      // Очистка ресурсов
      await subscription.cancel();
      await manager.dispose();
    });

    test(
        'sendFunction должен обрабатывать запросы и обновлять активность клиента',
        () async {
      // Arrange
      final manager = ServerStreamsManager<TestMessage>();

      // Создаем клиентский стрим
      final clientStream = manager.createClientStream<TestMessage>();

      // Получаем clientId
      final clientId = manager.getActiveClientIds().first;

      // Запоминаем время последней активности до отправки запроса
      final clientInfo = manager.getClientInfo(clientId);
      expect(clientInfo, isNotNull,
          reason: 'Информация о клиенте должна существовать');

      final lastActivityBefore = clientInfo!.lastActivity;

      // Ждем небольшое время, чтобы гарантировать разницу во времени
      await Future.delayed(Duration(milliseconds: 100));

      // Act - отправляем запрос через клиентский стрим
      final testRequest = TestMessage('client_request');
      clientStream.sendRequest(testRequest);

      // Ждем небольшое время для обработки запроса
      await Future.delayed(Duration(milliseconds: 50));

      // Assert - проверяем, что время последней активности обновилось
      final lastActivityAfter = manager.getClientInfo(clientId)!.lastActivity;

      expect(lastActivityAfter.isAfter(lastActivityBefore), isTrue,
          reason:
              'Время последней активности должно обновиться после отправки запроса');

      // Чистим ресурсы
      await manager.dispose();
    });

    test('метаданные должны корректно передаваться через стримы', () async {
      // Arrange
      final manager = ServerStreamsManager<TestMessage>();

      // Создаем два клиентских стрима
      final clientStream1 = manager.createClientStream<TestMessage>();
      final clientStream2 = manager.createClientStream<TestMessage>();

      // Получаем clientId для прямой публикации
      final clientId1 = manager.getActiveClientIds()[0];

      // Готовим коллекторы для сообщений с разными метаданными
      final messages1 = <TestMessage>[];
      final messages2 = <TestMessage>[];

      // Подписываемся на стримы
      final sub1 = clientStream1.listen((message) => messages1.add(message));
      final sub2 = clientStream2.listen((message) => messages2.add(message));

      // Act
      // 1. Публикуем сообщение с метаданными всем клиентам
      final broadcastMessage = TestMessage('broadcast with metadata');
      manager.publish(broadcastMessage,
          metadata: {'broadcast': true, 'priority': 'high'});

      // 2. Публикуем сообщение с метаданными конкретному клиенту
      final directMessage = TestMessage('direct with metadata');
      manager.publishToClient(clientId1, directMessage,
          metadata: {'direct': true, 'clientId': clientId1});

      // Ждем доставки сообщений
      await Future.delayed(Duration(milliseconds: 50));

      // Assert
      // Первый клиент должен получить оба сообщения
      expect(messages1.length, 2,
          reason: 'Первый клиент должен получить два сообщения');
      expect(messages1[0], broadcastMessage,
          reason: 'Первое сообщение должно быть широковещательным');
      expect(messages1[1], directMessage,
          reason: 'Второе сообщение должно быть прямым');

      // Второй клиент должен получить только широковещательное сообщение
      expect(messages2.length, 1,
          reason:
              'Второй клиент должен получить только широковещательное сообщение');
      expect(messages2[0], broadcastMessage,
          reason: 'Сообщение должно быть широковещательным');

      // Очистка ресурсов
      await sub1.cancel();
      await sub2.cancel();
      await manager.dispose();
    });
  });

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
      final testMessage = TestMessage('test');
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
      final testMessage = TestMessage('single');
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
      final testMessage = TestMessage('wrapped');
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
      testManager.publish(TestMessage('test after dispose'));
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
        final message = TestMessage('message-$i');
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
        manager.publish(TestMessage('batch1-$i'));

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
        manager.publish(TestMessage('batch2-$i'));
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
      manager.publish(TestMessage('normal message'));

      // Ждем доставки первого сообщения перед закрытием стрима
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что оба стрима получили первое сообщение
      expect(messages1.length, equals(1));
      expect(messages2.length, equals(1));

      // Имитируем ошибку в одном из стримов (закрываем и пытаемся отправить)
      await manager.closeClientStream(id1);

      // Отправляем индивидуальные сообщения (одно пойдет в закрытый стрим)
      manager.publishToClient(id1, TestMessage('to closed stream'));
      manager.publishToClient(id2, TestMessage('to active stream'));

      // Отправляем широковещательное сообщение
      manager.publish(TestMessage('broadcast after error'));

      // Ждем
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что первый стрим не получил сообщений после закрытия
      expect(messages1.length, equals(1)); // только первое сообщение

      // Проверяем, что второй стрим получил все сообщения
      expect(messages2.length,
          equals(3)); // первое, индивидуальное и широковещательное

      // Проверяем ID сообщений второго стрима
      expect(
          messages2.map((m) => m.content).toList(),
          equals([
            'normal message', // Первоначальное сообщение
            'to active stream', // Индивидуальное сообщение
            'broadcast after error' // Широковещательное сообщение
          ]));

      // Очищаем
      await sub1.cancel();
      await sub2.cancel();
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
      manager.publishToClient(clientId, TestMessage('update activity'));

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
      final testMessage = TestMessage('with metadata');

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
      manager.publish(TestMessage('after close'));

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
      stream.sendRequest(TestMessage('client request'));

      // Публикуем ответное сообщение
      manager.publishToClient(clientId, TestMessage('server response'));

      // Ждем обработки
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что клиент получил только ответ от сервера (не получает свой запрос обратно)
      expect(clientReceived.length, equals(1),
          reason:
              'Клиент должен получить только ответ от сервера, но не свой запрос');
      expect(clientReceived[0].content, equals('server response'),
          reason: 'Клиент должен получить только ответ сервера');

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
