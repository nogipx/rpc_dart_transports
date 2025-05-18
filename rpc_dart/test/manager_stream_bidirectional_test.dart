import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Тестовое сообщение для использования в тестах
class TestMessage extends IRpcSerializableMessage {
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
  group('BidirectionalStreamsManager', () {
    late BidirectionalStreamsManager<TestMessage, TestMessage> manager;

    setUp(() {
      manager = BidirectionalStreamsManager<TestMessage, TestMessage>();
    });

    // Убедимся, что каждый тест корректно завершает ресурсы
    tearDown(() async {
      await manager.dispose();
      // Добавим небольшую задержку между тестами
      await Future.delayed(Duration(milliseconds: 10));
    });

    test('должен создавать двунаправленный стрим для клиента', () {
      final stream = manager.createClientBidiStream();
      expect(stream, isNotNull);
      expect(manager.activeClientCount, equals(1));
    });

    test('должен публиковать общие ответы', () async {
      // Создаем стрим клиента
      final stream = manager.createClientBidiStream();

      // Создаем список для сбора сообщений
      final receivedMessages = <TestMessage>[];
      final completer = Completer<void>();

      // Подписываемся на ответы с автоматическим завершением
      final subscription = stream.listen((message) {
        receivedMessages.add(message);
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      // Публикуем ответы через менеджер
      manager
          .publishResponse(TestMessage(content: 'Broadcast response', id: 1));

      // Ждем получения сообщения или таймаута
      await completer.future.timeout(
        Duration(seconds: 1),
        onTimeout: () {
          // Ничего не делаем, просто продолжаем выполнение
        },
      );

      // Проверяем, что получили ответ
      expect(receivedMessages.length, equals(1));
      expect(receivedMessages.first.content, equals('Broadcast response'));

      // Отписываемся
      await subscription.cancel();
    });

    test('должен отправлять ответы конкретному клиенту', () async {
      // Создаем два стрима клиентов
      final stream1 = manager.createClientBidiStream();
      final stream2 = manager.createClientBidiStream();

      // Получаем ID клиентов
      final clientIds = manager.getActiveClientIds();
      expect(clientIds.length, equals(2));

      // Готовим списки для сбора сообщений
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

      // Отправляем ответ только первому клиенту
      manager.sendResponseToClient(
          clientIds[0], TestMessage(content: 'Direct response', id: 100));

      // Ждем доставки или таймаута
      await completer.future.timeout(
        Duration(seconds: 1),
        onTimeout: () {
          // Ничего не делаем, просто продолжаем
        },
      );

      // Проверяем, что только один клиент получил сообщение
      expect(messages1.length + messages2.length, equals(1));

      // Очищаем подписки
      await sub1.cancel();
      await sub2.cancel();
    });

    test('должен отправлять ответы нескольким клиентам', () async {
      // Создаем несколько стримов клиентов
      final stream1 = manager.createClientBidiStream();
      final stream2 = manager.createClientBidiStream();
      final stream3 = manager.createClientBidiStream();

      // Получаем ID клиентов
      final clientIds = manager.getActiveClientIds();
      expect(clientIds.length, equals(3));

      // Готовим списки для сбора сообщений
      final messages1 = <TestMessage>[];
      final messages2 = <TestMessage>[];
      final messages3 = <TestMessage>[];
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

      final sub3 = stream3.listen((msg) {
        messages3.add(msg);
        // Для третьего клиента мы не ожидаем сообщений
      });

      // Отправляем ответ только первым двум клиентам
      manager.sendResponseToClients([clientIds[0], clientIds[1]],
          TestMessage(content: 'Group response', id: 200));

      // Ждем доставки
      await completer.future.timeout(
        Duration(seconds: 1),
        onTimeout: () {
          // Продолжаем выполнение
        },
      );

      // Проверяем, что два клиента получили сообщение, а третий - нет
      expect(messages1.length + messages2.length, equals(2));
      expect(messages3.length, equals(0));

      // Очищаем подписки
      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    });

    test('должен обрабатывать входящие запросы через коллбэк onRequestReceived',
        () async {
      // Список для хранения полученных запросов
      final receivedRequests = <StreamMessage<TestMessage>>[];
      final completer = Completer<void>();

      // Создаем менеджер с обработчиком
      final managerWithCallback =
          BidirectionalStreamsManager<TestMessage, TestMessage>(
        onRequestReceived: (request) {
          receivedRequests.add(request);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Создаем стрим для клиента
      final stream = managerWithCallback.createClientBidiStream();

      // Отправляем запрос с клиентской стороны
      stream.send(TestMessage(content: 'Client request', id: 300));

      // Ждем обработки
      await completer.future.timeout(
        Duration(seconds: 1),
        onTimeout: () {
          // Просто продолжаем выполнение
        },
      );

      // Проверяем, что запрос был получен
      expect(receivedRequests.length, equals(1));
      expect(receivedRequests.first.message.content, equals('Client request'));
      expect(receivedRequests.first.message.id, equals(300));

      // Проверяем, что streamId правильный
      final clientId = managerWithCallback.getActiveClientIds().first;
      expect(receivedRequests.first.streamId, equals(clientId));

      // Очищаем
      await managerWithCallback.dispose();
    });

    test('должен отвечать на запросы с помощью метода replyTo', () async {
      // Сохраняем ссылку на менеджер для использования в коллбэке
      late BidirectionalStreamsManager<TestMessage, TestMessage> managerRef;
      final completer = Completer<void>();

      // Создаем менеджер с обработчиком, который отвечает на запросы
      final managerWithReplies =
          BidirectionalStreamsManager<TestMessage, TestMessage>(
        onRequestReceived: (request) {
          // Отвечаем на запрос через ранее сохраненную ссылку
          managerRef.replyTo(
              request,
              TestMessage(
                  content: 'Reply to: ${request.message.content}',
                  id: request.message.id + 1000),
              metadata: {'reply_time': DateTime.now().toIso8601String()});
        },
      );

      // Сохраняем ссылку на созданный менеджер
      managerRef = managerWithReplies;

      // Создаем стрим для клиента
      final stream = managerWithReplies.createClientBidiStream();

      // Список для сбора ответов
      final responses = <TestMessage>[];

      // Подписываемся на ответы
      final subscription = stream.listen((msg) {
        responses.add(msg);
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      // Отправляем запрос
      stream.send(TestMessage(content: 'Hello from client', id: 42));

      // Ждем ответа
      await completer.future.timeout(
        Duration(seconds: 1),
        onTimeout: () {
          // Просто продолжаем
        },
      );

      // Проверяем ответ
      expect(responses.length, equals(1));
      expect(responses.first.content, equals('Reply to: Hello from client'));
      expect(responses.first.id, equals(1042)); // 42 + 1000

      // Очищаем
      await subscription.cancel();
      await managerWithReplies.dispose();
    });

    test('должен корректно закрывать клиентские стримы', () async {
      // Создаем несколько стримов
      manager.createClientBidiStream(); // Первый стрим
      manager.createClientBidiStream(); // Второй стрим

      expect(manager.activeClientCount, equals(2));

      // Получаем ID клиентов
      final clientIds = manager.getActiveClientIds();

      // Закрываем первый стрим с проверкой завершения
      final closeCompleter1 = Completer<void>();

      // Используем Future.microtask для обертки операции, чтобы избежать блокировок
      Future.microtask(() async {
        await manager.closeClientStream(clientIds[0]);
        if (!closeCompleter1.isCompleted) {
          closeCompleter1.complete();
        }
      });

      // Ожидаем с таймаутом
      await closeCompleter1.future.timeout(Duration(milliseconds: 500),
          onTimeout: () {
        if (!closeCompleter1.isCompleted) {
          closeCompleter1.complete();
          print('Таймаут при закрытии первого стрима');
        }
      });

      // Проверяем, что осталось только 1 стрим
      expect(manager.activeClientCount, equals(1));
      expect(manager.getActiveClientIds().contains(clientIds[0]), isFalse);

      // Закрываем второй стрим с проверкой завершения
      final closeCompleter2 = Completer<void>();

      Future.microtask(() async {
        await manager.closeClientStream(clientIds[1]);
        if (!closeCompleter2.isCompleted) {
          closeCompleter2.complete();
        }
      });

      // Ожидаем с таймаутом
      await closeCompleter2.future.timeout(Duration(milliseconds: 500),
          onTimeout: () {
        if (!closeCompleter2.isCompleted) {
          closeCompleter2.complete();
          print('Таймаут при закрытии второго стрима');
        }
      });

      // Проверяем, что не осталось стримов
      expect(manager.activeClientCount, equals(0));

      // Небольшая задержка для завершения всех асинхронных операций
      await Future.delayed(Duration(milliseconds: 10));
    });

    test('должен получать неактивные клиентские ID', () async {
      // Создаем два стрима
      manager.createClientBidiStream();
      manager.createClientBidiStream();

      // Получаем ID
      final clientIds = manager.getActiveClientIds();

      // Ждем немного, чтобы один стрим стал "неактивным"
      await Future.delayed(Duration(milliseconds: 20));

      // Обновляем активность только для первого стрима
      final clientInfo = manager.getClientStreamInfo(clientIds[0]);
      clientInfo?.updateLastActivity();

      // Ждем еще немного
      await Future.delayed(Duration(milliseconds: 20));

      // Получаем неактивные ID с небольшим порогом
      final inactiveIds =
          manager.getInactiveClientIds(Duration(milliseconds: 30));

      // Должен быть только один неактивный клиент (второй)
      expect(inactiveIds.length, equals(1));
      expect(inactiveIds.contains(clientIds[1]), isTrue);
    });

    test('должен возвращать информацию о длительности работы стрима', () async {
      // Создаем стрим
      manager.createClientBidiStream();

      // Получаем ID
      final clientId = manager.getActiveClientIds().first;

      // Получаем информацию о стриме
      final info = manager.getClientStreamInfo(clientId);
      expect(info, isNotNull);

      // Первоначальная длительность должна быть маленькой
      final initialDuration = info!.getActiveDuration();
      expect(initialDuration.inMilliseconds, lessThan(100));

      // Ждем немного
      await Future.delayed(Duration(milliseconds: 20));

      // Проверяем, что длительность увеличилась
      final laterDuration = info.getActiveDuration();
      expect(laterDuration.inMilliseconds,
          greaterThan(initialDuration.inMilliseconds));
    });

    test('должен возвращать информацию о времени неактивности', () async {
      // Создаем стрим
      manager.createClientBidiStream();

      // Получаем ID и информацию
      final clientId = manager.getActiveClientIds().first;
      final info = manager.getClientStreamInfo(clientId)!;

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
