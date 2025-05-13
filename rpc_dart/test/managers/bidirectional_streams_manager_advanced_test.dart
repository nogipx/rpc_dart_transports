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
  group('BidirectionalStreamsManager - Продвинутые тесты', () {
    late BidirectionalStreamsManager<TestMessage, TestMessage> manager;

    setUp(() {
      manager = BidirectionalStreamsManager<TestMessage, TestMessage>();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('should handle multiple requests and responses concurrently',
        () async {
      const numClients = 5;
      const messagesPerClient = 10;
      final receivedRequestsCount = <String, int>{};
      final receivedResponsesCount = <String, List<TestMessage>>{};
      final streams =
          <String, dynamic>{}; // Используем dynamic вместо конкретного типа

      // Сохраняем ссылку на внешний объект
      late BidirectionalStreamsManager<TestMessage, TestMessage> managerRef;

      // Создаем менеджер с обработчиком запросов, который отвечает на каждый запрос
      final concurrentManager =
          BidirectionalStreamsManager<TestMessage, TestMessage>(
        onRequestReceived: (request) {
          // Увеличиваем счетчик полученных запросов для этого клиента
          receivedRequestsCount[request.streamId] =
              (receivedRequestsCount[request.streamId] ?? 0) + 1;

          // Отвечаем на запрос через ранее сохраненный менеджер
          managerRef.replyTo(
            request,
            TestMessage(
                content: 'Reply to: ${request.message.content}',
                id: request.message.id * 2),
          );
        },
      );

      // Сохраняем ссылку на созданный менеджер
      managerRef = concurrentManager;

      // Создаем несколько клиентских стримов
      for (var i = 0; i < numClients; i++) {
        final stream = concurrentManager.createClientBidiStream();
        final clientId = concurrentManager
            .getActiveClientIds()
            .firstWhere((id) => !streams.containsKey(id));

        streams[clientId] = stream;
        receivedResponsesCount[clientId] = [];

        // Подписываемся на ответы
        stream.listen((response) {
          receivedResponsesCount[clientId]!.add(response);
        });
      }

      // Каждый клиент отправляет несколько запросов
      for (var clientId in streams.keys) {
        for (var i = 0; i < messagesPerClient; i++) {
          streams[clientId].send(
              TestMessage(content: 'Request from $clientId: $i', id: i + 1));
        }
      }

      // Ждем обработки всех запросов и ответов
      await Future.delayed(Duration(milliseconds: 100 * numClients));

      // Проверяем, что все запросы были обработаны и получены ответы
      for (var clientId in streams.keys) {
        expect(receivedRequestsCount[clientId], equals(messagesPerClient),
            reason:
                'Клиент $clientId должен отправить $messagesPerClient запросов');
        expect(
            receivedResponsesCount[clientId]!.length, equals(messagesPerClient),
            reason:
                'Клиент $clientId должен получить $messagesPerClient ответов');
      }

      // Проверяем общее количество обработанных запросов
      final totalRequests =
          receivedRequestsCount.values.fold(0, (sum, count) => sum + count);
      expect(totalRequests, equals(numClients * messagesPerClient),
          reason:
              'Общее количество запросов должно быть $numClients * $messagesPerClient');

      // Очищаем ресурсы
      await concurrentManager.dispose();
    });

    test('should handle pausing and resuming streams', () async {
      // Сохраняем ссылку на внешний объект
      late BidirectionalStreamsManager<TestMessage, TestMessage> managerRef;

      // Создаем менеджер с обработчиком запросов
      final pauseManager =
          BidirectionalStreamsManager<TestMessage, TestMessage>(
        onRequestReceived: (request) {
          // Используем внешнюю ссылку на менеджер
          managerRef.replyTo(
            request,
            TestMessage(
                content: 'Reply to: ${request.message.content}',
                id: request.message.id),
          );
        },
      );

      // Сохраняем ссылку на созданный менеджер
      managerRef = pauseManager;

      // Создаем стрим клиента
      final stream = pauseManager.createClientBidiStream();
      final receivedMessages = <TestMessage>[];
      final subscription = stream.listen(receivedMessages.add);

      // Приостанавливаем подписку
      subscription.pause();

      // Отправляем запрос
      stream.send(TestMessage(content: 'Paused request', id: 42));

      // Ждем немного
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что сообщение не получено (подписка приостановлена)
      expect(receivedMessages.length, equals(0));

      // Возобновляем подписку
      subscription.resume();

      // Отправляем еще один запрос
      stream.send(TestMessage(content: 'Resumed request', id: 43));

      // Ждем обработки
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что получены оба сообщения
      // (как обработанное во время паузы, так и новое)
      expect(receivedMessages.length, equals(2));

      // Очищаем ресурсы
      await subscription.cancel();
      await pauseManager.dispose();
    });

    test('should handle client info properties', () async {
      // Создаем клиентский стрим
      manager.createClientBidiStream(); // Создаем стрим без сохранения ссылки
      final clientId = manager.getActiveClientIds().first;

      // Получаем информацию о стриме
      final streamInfo = manager.getClientStreamInfo(clientId);
      expect(streamInfo, isNotNull);

      // Проверяем время создания
      expect(streamInfo!.getActiveDuration().inSeconds, lessThan(1));

      // Обновляем время последней активности
      streamInfo.updateLastActivity();

      // Проверяем, что время неактивности обновлено
      expect(streamInfo.getInactivityDuration().inMilliseconds, lessThan(100));
    });

    test('should handle client groups', () async {
      // Создаем несколько клиентских стримов
      final streams = List.generate(5, (_) => manager.createClientBidiStream());
      final clientIds = manager.getActiveClientIds();

      // Выделяем группы клиентов
      final group1 = clientIds.sublist(0, 2);
      final group2 = clientIds.sublist(2, 4);
      final standalone = clientIds.last;

      // Готовим списки для сбора сообщений от разных групп
      final group1Messages = <String, List<TestMessage>>{};
      final group2Messages = <String, List<TestMessage>>{};
      final standaloneMessages = <TestMessage>[];

      // Настраиваем отслеживание сообщений для каждой группы
      for (var id in group1) {
        group1Messages[id] = [];
        final streamIndex = clientIds.indexOf(id);
        streams[streamIndex].listen((msg) => group1Messages[id]!.add(msg));
      }

      for (var id in group2) {
        group2Messages[id] = [];
        final streamIndex = clientIds.indexOf(id);
        streams[streamIndex].listen((msg) => group2Messages[id]!.add(msg));
      }

      final standaloneIndex = clientIds.indexOf(standalone);
      streams[standaloneIndex].listen(standaloneMessages.add);

      // Отправляем сообщение первой группе
      manager.sendResponseToClients(
          group1, TestMessage(content: 'Group 1 message', id: 1));

      // Отправляем сообщение второй группе
      manager.sendResponseToClients(
          group2, TestMessage(content: 'Group 2 message', id: 2));

      // Отправляем сообщение отдельному клиенту
      manager.sendResponseToClient(
          standalone, TestMessage(content: 'Standalone message', id: 3));

      // Отправляем общее сообщение всем
      manager
          .publishResponse(TestMessage(content: 'Broadcast to all', id: 100));

      // Ждем доставки
      await Future.delayed(Duration(milliseconds: 100));

      // Проверяем, что группа 1 получила свое сообщение + широковещательное
      for (var id in group1) {
        expect(group1Messages[id]!.length, equals(2));
        expect(
            group1Messages[id]!.any((msg) => msg.content == 'Group 1 message'),
            isTrue);
        expect(
            group1Messages[id]!.any((msg) => msg.content == 'Broadcast to all'),
            isTrue);
      }

      // Проверяем, что группа 2 получила свое сообщение + широковещательное
      for (var id in group2) {
        expect(group2Messages[id]!.length, equals(2));
        expect(
            group2Messages[id]!.any((msg) => msg.content == 'Group 2 message'),
            isTrue);
        expect(
            group2Messages[id]!.any((msg) => msg.content == 'Broadcast to all'),
            isTrue);
      }

      // Проверяем, что отдельный клиент получил свое сообщение + широковещательное
      expect(standaloneMessages.length, equals(2));
      expect(
          standaloneMessages.any((msg) => msg.content == 'Standalone message'),
          isTrue);
      expect(standaloneMessages.any((msg) => msg.content == 'Broadcast to all'),
          isTrue);
    });
  });
}
