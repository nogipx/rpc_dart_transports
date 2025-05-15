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
}
