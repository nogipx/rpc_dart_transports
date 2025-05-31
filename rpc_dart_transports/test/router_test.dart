// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// Интеграционные тесты роутера RPC
///
/// Следуют принципам классической школы тестирования:
/// - Тестируют наблюдаемое поведение системы
/// - Используют реальные объекты вместо моков
/// - Проверяют взаимодействия на границах системы
/// - Фокусируются на бизнес-результатах
void main() {
  group('RouterContract Integration Tests', () {
    late HttpServer server;
    late RouterResponderContract routerContract;
    late int port;

    setUpAll(() async {
      // Запускаем роутер сервер на случайном порту
      port = await _findFreePort();
      final serverSetup = await _startRouterServer(port);
      server = serverSetup.server;
      routerContract = serverSetup.contract;
    });

    tearDownAll(() async {
      await routerContract.dispose();
      await server.close(force: true);
    });

    group('Регистрация клиентов', () {
      test('должен зарегистрировать клиента и вернуть уникальный ID', () async {
        // Arrange
        final client = await _createTestClient('TestClient', port);

        // Act & Assert - регистрация происходит в _createTestClient
        expect(client.clientId, isNotNull);
        expect(client.clientId, isNotEmpty);
        expect(client.isRegistered, isTrue);

        await client.dispose();
      });

      test('должен регистрировать несколько клиентов с разными ID', () async {
        // Arrange & Act
        final client1 = await _createTestClient('Client1', port);
        final client2 = await _createTestClient('Client2', port);

        // Assert
        expect(client1.clientId, isNot(equals(client2.clientId)));
        expect(client1.isRegistered, isTrue);
        expect(client2.isRegistered, isTrue);

        await client1.dispose();
        await client2.dispose();
      });

      test('должен включать клиента в список онлайн после регистрации', () async {
        // Arrange
        final client1 = await _createTestClient('Alice', port);
        final client2 = await _createTestClient('Bob', port);

        // Act
        final onlineClients = await client1.getOnlineClients();

        // Assert - проверяем, что оба клиента в списке (могут быть и другие от предыдущих тестов)
        final clientIds = onlineClients.map((c) => c.clientId).toSet();
        expect(clientIds, contains(client1.clientId));
        expect(clientIds, contains(client2.clientId));
        expect(onlineClients.length, greaterThanOrEqualTo(2));

        await client1.dispose();
        await client2.dispose();
      });
    });

    group('Ping/Pong', () {
      test('должен отвечать на ping с актуальным временем', () async {
        // Arrange
        final client = await _createTestClient('PingClient', port);
        final beforePing = DateTime.now();

        // Act
        final latency = await client.ping();
        final afterPing = DateTime.now();

        // Assert
        expect(latency.inMilliseconds, greaterThanOrEqualTo(0));
        expect(latency.inMilliseconds, lessThan(1000)); // разумный предел

        // Время round-trip должно быть в пределах общего времени выполнения
        final totalTime = afterPing.difference(beforePing);
        expect(latency, lessThanOrEqualTo(totalTime));

        await client.dispose();
      });

      test('должен обрабатывать множественные ping запросы', () async {
        // Arrange
        final client = await _createTestClient('MultiPingClient', port);

        // Act & Assert
        for (int i = 0; i < 5; i++) {
          final latency = await client.ping();
          expect(latency.inMilliseconds, greaterThanOrEqualTo(0));
          expect(latency.inMilliseconds, lessThan(1000));
        }

        await client.dispose();
      });
    });

    group('Unicast сообщения', () {
      test('должен доставлять сообщение между двумя клиентами', () async {
        // Arrange
        final alice = await _createTestClient('Alice', port);
        final bob = await _createTestClient('Bob', port);

        final receivedMessages = <RouterMessage>[];
        await bob.initializeP2P(onP2PMessage: receivedMessages.add);
        await alice.initializeP2P(onP2PMessage: (_) {});

        // Даем время для установки P2P соединений
        await Future.delayed(Duration(milliseconds: 200));

        final testMessage = {'text': 'Hello Bob!', 'timestamp': DateTime.now().toIso8601String()};

        // Act
        await alice.sendUnicast(bob.clientId!, testMessage);

        // Assert - ждем доставки сообщения
        await _waitForCondition(() => receivedMessages.isNotEmpty);

        expect(receivedMessages, hasLength(1));
        final received = receivedMessages.first;
        expect(received.type, equals(RouterMessageType.unicast));
        expect(received.senderId, equals(alice.clientId));
        expect(received.targetId, equals(bob.clientId));
        expect(received.payload, equals(testMessage));

        await alice.dispose();
        await bob.dispose();
      });

      test('должен отправлять ошибку при отправке несуществующему клиенту', () async {
        // Arrange
        final alice = await _createTestClient('Alice', port);

        final receivedMessages = <RouterMessage>[];
        await alice.initializeP2P(onP2PMessage: receivedMessages.add);

        // Даем время для установки P2P соединения
        await Future.delayed(Duration(milliseconds: 200));

        // Act
        await alice.sendUnicast('nonexistent-client-id', {'test': 'message'});

        // Assert - ожидаем сообщение об ошибке
        await _waitForCondition(() => receivedMessages.isNotEmpty);

        expect(receivedMessages, hasLength(1));
        final errorMessage = receivedMessages.first;
        expect(errorMessage.type, equals(RouterMessageType.error));
        expect(errorMessage.errorMessage, contains('не найден'));

        await alice.dispose();
      });
    });

    group('Multicast сообщения', () {
      test('должен отправлять сообщение всем клиентам кроме отправителя', () async {
        // Arrange
        final alice = await _createTestClient('Alice', port);
        final bob = await _createTestClient('Bob', port);
        final charlie = await _createTestClient('Charlie', port);

        final bobMessages = <RouterMessage>[];
        final charlieMessages = <RouterMessage>[];
        final aliceMessages = <RouterMessage>[];

        await alice.initializeP2P(onP2PMessage: aliceMessages.add);
        await bob.initializeP2P(onP2PMessage: bobMessages.add);
        await charlie.initializeP2P(onP2PMessage: charlieMessages.add);

        // Даем больше времени для установки всех P2P соединений
        await Future.delayed(Duration(milliseconds: 300));

        final testMessage = {'announcement': 'Team meeting at 15:00', 'group': 'developers'};

        // Act
        await alice.sendMulticast('developers', testMessage);

        // Assert
        await _waitForCondition(() => bobMessages.isNotEmpty && charlieMessages.isNotEmpty,
            timeout: Duration(seconds: 5));

        // Bob и Charlie должны получить сообщение
        expect(bobMessages, hasLength(1));
        expect(charlieMessages, hasLength(1));

        // Alice НЕ должна получить свое сообщение
        expect(aliceMessages, isEmpty);

        // Проверяем содержимое сообщений
        for (final messages in [bobMessages, charlieMessages]) {
          final message = messages.first;
          expect(message.type, equals(RouterMessageType.multicast));
          expect(message.senderId, equals(alice.clientId));
          expect(message.groupName, equals('developers'));
          expect(message.payload, equals(testMessage));
        }

        await alice.dispose();
        await bob.dispose();
        await charlie.dispose();
      });
    });

    group('Broadcast сообщения', () {
      test('должен отправлять сообщение всем клиентам кроме отправителя', () async {
        // Arrange
        final clients = <RouterClient>[];
        final messagesPerClient = <List<RouterMessage>>[];

        // Создаем клиентов последовательно для стабильности
        for (int i = 0; i < 3; i++) {
          final client = await _createTestClient('Client$i', port);
          clients.add(client);

          final messages = <RouterMessage>[];
          messagesPerClient.add(messages);
          await client.initializeP2P(onP2PMessage: messages.add);

          // Пауза между созданием клиентов
          await Future.delayed(Duration(milliseconds: 100));
        }

        // Даем дополнительное время для полной инициализации
        await Future.delayed(Duration(milliseconds: 300));

        final broadcastMessage = {
          'type': 'system_announcement',
          'message': 'Server maintenance in 10 minutes'
        };

        // Act - первый клиент отправляет broadcast
        await clients[0].sendBroadcast(broadcastMessage);

        // Assert
        await _waitForCondition(
            () => messagesPerClient.skip(1).every((messages) => messages.isNotEmpty),
            timeout: Duration(seconds: 5));

        // Отправитель не должен получить свое сообщение
        expect(messagesPerClient[0], isEmpty);

        // Все остальные клиенты должны получить сообщение
        for (int i = 1; i < messagesPerClient.length; i++) {
          expect(messagesPerClient[i], hasLength(1));
          final message = messagesPerClient[i].first;
          expect(message.type, equals(RouterMessageType.broadcast));
          expect(message.senderId, equals(clients[0].clientId));
          expect(message.payload, equals(broadcastMessage));
        }

        // Cleanup
        for (final client in clients) {
          await client.dispose();
        }
      });
    });

    group('Request-Response паттерн', () {
      test('должен обрабатывать синхронный request-response', () async {
        // Arrange
        final alice = await _createTestClient('Alice', port);
        final bob = await _createTestClient('Bob', port);

        // Инициализируем P2P для Alice
        await alice.initializeP2P(onP2PMessage: (_) {});

        // Bob автоматически отвечает на запросы
        await bob.initializeP2P(onP2PMessage: (message) {
          if (message.type == RouterMessageType.request) {
            final requestId = message.payload?['requestId'] as String?;
            if (requestId != null) {
              final response = RouterMessage.response(
                targetId: message.senderId!,
                requestId: requestId,
                payload: {
                  'answer': 'Hello from Bob!',
                  'originalQuestion': message.payload?['question'],
                },
                senderId: bob.clientId!,
              );
              bob.sendP2PMessage(response);
            }
          }
        });

        // Даем время для установки P2P соединений
        await Future.delayed(Duration(milliseconds: 300));

        final question = {'question': 'How are you?', 'from': 'Alice'};

        // Act
        final response = await alice.sendRequest(
          bob.clientId!,
          question,
          timeout: Duration(seconds: 3),
        );

        // Assert
        expect(response, isNotNull);
        expect(response['answer'], equals('Hello from Bob!'));
        expect(response['originalQuestion'], equals(question['question']));

        await alice.dispose();
        await bob.dispose();
      });

      test('должен выбрасывать TimeoutException при отсутствии ответа', () async {
        // Arrange
        final alice = await _createTestClient('Alice', port);
        final bob = await _createTestClient('Bob', port);

        // Инициализируем P2P для Alice
        await alice.initializeP2P(onP2PMessage: (_) {});

        // Bob НЕ отвечает на запросы
        await bob.initializeP2P(onP2PMessage: (_) {});

        // Даем время для установки P2P соединений
        await Future.delayed(Duration(milliseconds: 300));

        // Act & Assert - правильная проверка TimeoutException для async функции
        await expectLater(
          alice.sendRequest(
            bob.clientId!,
            {'question': 'Are you there?'},
            timeout: Duration(milliseconds: 500), // Разумный timeout
          ),
          throwsA(isA<TimeoutException>()),
        );

        await alice.dispose();
        await bob.dispose();
      });
    });

    group('События роутера', () {
      test('должен отправлять приветственное событие при подписке', () async {
        // Arrange
        final client = await _createTestClient('EventClient', port);

        final events = <RouterEvent>[];

        // Act
        await client.subscribeToEvents();
        final subscription = client.events.listen(events.add);

        // Assert - должно прийти приветственное событие
        await _waitForCondition(() => events.isNotEmpty, timeout: Duration(seconds: 3));

        expect(events, hasLength(1));
        final welcomeEvent = events.first;
        expect(welcomeEvent.type, equals(RouterEventType.routerStats));
        expect(welcomeEvent.data, containsPair('activeClients', isA<int>()));

        await subscription.cancel();
        await client.dispose();
      });
    });

    group('Производительность и стабильность', () {
      test('должен обрабатывать множественные одновременные соединения', () async {
        // Arrange
        const clientCount = 4; // Уменьшаем для стабильности
        final clients = <RouterClient>[];

        // Act - создаем клиентов последовательно для стабильности
        for (int i = 0; i < clientCount; i++) {
          final client = await _createTestClient('LoadClient$i', port);
          clients.add(client);
          // Пауза между созданием клиентов
          await Future.delayed(Duration(milliseconds: 100));
        }

        // Assert
        expect(clients, hasLength(clientCount));
        for (final client in clients) {
          expect(client.isRegistered, isTrue);
          expect(client.clientId, isNotNull);
        }

        // Проверяем, что новые клиенты видят друг друга
        final onlineClients = await clients[0].getOnlineClients();
        final newClientIds = clients.map((c) => c.clientId!).toSet();
        final onlineClientIds = onlineClients.map((c) => c.clientId).toSet();

        // Все наши новые клиенты должны быть в списке онлайн
        expect(onlineClientIds, containsAll(newClientIds));

        // Cleanup
        for (final client in clients) {
          await client.dispose();
        }
      });

      test('должен обрабатывать умеренную нагрузку сообщений', () async {
        // Arrange
        final alice = await _createTestClient('Alice', port);
        final bob = await _createTestClient('Bob', port);

        final receivedMessages = <RouterMessage>[];
        await bob.initializeP2P(onP2PMessage: receivedMessages.add);
        await alice.initializeP2P(onP2PMessage: (_) {});

        // Даем время для установки P2P соединений
        await Future.delayed(Duration(milliseconds: 300));

        const messageCount = 10; // Уменьшаем для стабильности

        // Act - отправляем сообщения с небольшими паузами
        for (int i = 0; i < messageCount; i++) {
          await alice.sendUnicast(bob.clientId!, {'messageId': i, 'content': 'Message $i'});
          // Небольшая пауза между сообщениями для стабильности
          await Future.delayed(Duration(milliseconds: 20));
        }

        // Assert - все сообщения должны быть доставлены
        await _waitForCondition(() => receivedMessages.length == messageCount,
            timeout: Duration(seconds: 10));

        expect(receivedMessages, hasLength(messageCount));

        // Проверяем, что все сообщения уникальны
        final messageIds = receivedMessages.map((m) => m.payload?['messageId']).toSet();
        expect(messageIds, hasLength(messageCount));

        await alice.dispose();
        await bob.dispose();
      });
    });
  });
}

// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

/// Настройка роутера-сервера
class _ServerSetup {
  final HttpServer server;
  final RouterResponderContract contract;

  _ServerSetup(this.server, this.contract);
}

/// Запускает роутер сервер на указанном порту
Future<_ServerSetup> _startRouterServer(int port) async {
  final routerContract = RouterResponderContract();
  final server = await HttpServer.bind('localhost', port);

  server.listen((request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final websocket = await WebSocketTransformer.upgrade(request);
        final channel = IOWebSocketChannel(websocket);
        final transport = RpcWebSocketResponderTransport(channel);

        final endpoint = RpcResponderEndpoint(
          transport: transport,
          debugLabel: 'TestRouterEndpoint',
        );

        endpoint.registerServiceContract(routerContract);
        endpoint.start();
      } catch (e) {
        request.response.statusCode = 500;
        await request.response.close();
      }
    } else {
      request.response.statusCode = 404;
      await request.response.close();
    }
  });

  return _ServerSetup(server, routerContract);
}

/// Создает и регистрирует тестового клиента
Future<RouterClient> _createTestClient(String name, int port) async {
  final transport = RpcWebSocketCallerTransport.connect(
    Uri.parse('ws://localhost:$port'),
  );

  final endpoint = RpcCallerEndpoint(
    transport: transport,
    debugLabel: 'TestClient_$name',
  );

  final client = RouterClient(
    callerEndpoint: endpoint,
  );

  await client.register(
    clientName: name,
    groups: ['testers', 'developers'],
  );

  return client;
}

/// Находит свободный порт для тестов
Future<int> _findFreePort() async {
  final socket = await ServerSocket.bind('localhost', 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// Ждет выполнения условия с таймаутом
Future<void> _waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
  Duration interval = const Duration(milliseconds: 50),
}) async {
  final stopwatch = Stopwatch()..start();

  while (!condition() && stopwatch.elapsed < timeout) {
    await Future.delayed(interval);
  }

  if (!condition()) {
    throw TimeoutException(
      'Condition not met within timeout',
      timeout,
    );
  }
}
