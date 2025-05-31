// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// Базовые интеграционные тесты роутера RPC
///
/// Следуют принципам классической школы тестирования:
/// - Тестируют наблюдаемое поведение системы
/// - Используют реальные объекты вместо моков
/// - Проверяют взаимодействия на границах системы
/// - Фокусируются на бизнес-результатах
void main() {
  group('RouterContract Basic Tests', () {
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

    group('Основная функциональность', () {
      test('должен регистрировать клиента и возвращать уникальный ID',
          () async {
        // Arrange & Act
        final client = await _createTestClient('TestClient', port);

        // Assert
        expect(client.clientId, isNotNull);
        expect(client.clientId, isNotEmpty);
        expect(client.isRegistered, isTrue);

        await client.dispose();
      });

      test('должен отвечать на ping с корректной задержкой', () async {
        // Arrange
        final client = await _createTestClient('PingClient', port);
        final beforePing = DateTime.now();

        // Act
        final latency = await client.ping();
        final afterPing = DateTime.now();

        // Assert
        expect(latency.inMilliseconds, greaterThanOrEqualTo(0));
        expect(latency.inMilliseconds, lessThan(1000));

        final totalTime = afterPing.difference(beforePing);
        expect(latency, lessThanOrEqualTo(totalTime));

        await client.dispose();
      });

      test('должен возвращать список зарегистрированных клиентов', () async {
        // Arrange
        final client1 = await _createTestClient('Alice', port);
        final client2 = await _createTestClient('Bob', port);

        // Act
        final onlineClients = await client1.getOnlineClients();

        // Assert
        final clientIds = onlineClients.map((c) => c.clientId).toSet();
        expect(clientIds, contains(client1.clientId));
        expect(clientIds, contains(client2.clientId));
        expect(onlineClients.length, greaterThanOrEqualTo(2));

        await client1.dispose();
        await client2.dispose();
      });
    });

    group('P2P сообщения', () {
      test('должен доставлять unicast сообщение между клиентами', () async {
        // Arrange
        final alice = await _createTestClient('Alice', port);
        final bob = await _createTestClient('Bob', port);

        final receivedMessages = <RouterMessage>[];
        await bob.initializeP2P(onP2PMessage: receivedMessages.add);
        await alice.initializeP2P(onP2PMessage: (_) {});

        // Даем время для установки P2P соединений
        await Future.delayed(Duration(milliseconds: 100));

        final testMessage = {
          'text': 'Hello Bob!',
          'timestamp': DateTime.now().toIso8601String()
        };

        // Act
        await alice.sendUnicast(bob.clientId!, testMessage);

        // Assert
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

      test('должен отправлять ошибку при unicast несуществующему клиенту',
          () async {
        // Arrange
        final alice = await _createTestClient('Alice', port);

        final receivedMessages = <RouterMessage>[];
        await alice.initializeP2P(onP2PMessage: receivedMessages.add);

        // Даем время для установки P2P соединения
        await Future.delayed(Duration(milliseconds: 100));

        // Act
        await alice.sendUnicast('nonexistent-client-id', {'test': 'message'});

        // Assert
        await _waitForCondition(() => receivedMessages.isNotEmpty);

        expect(receivedMessages, hasLength(1));
        final errorMessage = receivedMessages.first;
        expect(errorMessage.type, equals(RouterMessageType.error));
        expect(errorMessage.errorMessage, contains('не найден'));

        await alice.dispose();
      });

      test(
          'должен отправлять broadcast сообщение всем клиентам кроме отправителя',
          () async {
        // Arrange
        final clients = <RouterClient>[];
        final messagesPerClient = <List<RouterMessage>>[];

        // Создаем 3 клиента
        for (int i = 0; i < 3; i++) {
          final client = await _createTestClient('Client$i', port);
          clients.add(client);

          final messages = <RouterMessage>[];
          messagesPerClient.add(messages);
          await client.initializeP2P(onP2PMessage: messages.add);
        }

        // Даем время для установки всех P2P соединений
        await Future.delayed(Duration(milliseconds: 200));

        final broadcastMessage = {
          'type': 'system_announcement',
          'message': 'Server maintenance in 10 minutes'
        };

        // Act
        await clients[0].sendBroadcast(broadcastMessage);

        // Assert
        await _waitForCondition(() =>
            messagesPerClient.skip(1).every((messages) => messages.isNotEmpty));

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

    group('События роутера', () {
      test('должен отправлять события подписчикам', () async {
        // Arrange
        final client = await _createTestClient('EventClient', port);

        final events = <RouterEvent>[];

        // Act
        await client.subscribeToEvents();
        final subscription = client.events.listen(events.add);

        // Assert
        await _waitForCondition(() => events.isNotEmpty);

        expect(events, hasLength(1));
        final welcomeEvent = events.first;
        expect(welcomeEvent.type, equals(RouterEventType.routerStats));
        expect(welcomeEvent.data, containsPair('activeClients', isA<int>()));

        await subscription.cancel();
        await client.dispose();
      });
    });

    group('Масштабируемость', () {
      test('должен обрабатывать множественные соединения', () async {
        // Arrange
        const clientCount = 5;
        final clients = <RouterClient>[];

        // Act
        for (int i = 0; i < clientCount; i++) {
          final client = await _createTestClient('LoadClient$i', port);
          clients.add(client);
        }

        // Assert
        expect(clients, hasLength(clientCount));
        for (final client in clients) {
          expect(client.isRegistered, isTrue);
          expect(client.clientId, isNotNull);
        }

        // Проверяем, что все клиенты видят друг друга
        final onlineClients = await clients[0].getOnlineClients();
        final newClientIds = clients.map((c) => c.clientId!).toSet();
        final onlineClientIds = onlineClients.map((c) => c.clientId).toSet();

        expect(onlineClientIds, containsAll(newClientIds));

        // Cleanup
        for (final client in clients) {
          await client.dispose();
        }
      });

      test('должен обрабатывать последовательную отправку сообщений', () async {
        // Arrange
        final alice = await _createTestClient('Alice', port);
        final bob = await _createTestClient('Bob', port);

        final receivedMessages = <RouterMessage>[];
        await bob.initializeP2P(onP2PMessage: receivedMessages.add);
        await alice.initializeP2P(onP2PMessage: (_) {});

        // Даем время для установки P2P соединений
        await Future.delayed(Duration(milliseconds: 100));

        const messageCount = 5;

        // Act - отправляем сообщения последовательно
        for (int i = 0; i < messageCount; i++) {
          await alice.sendUnicast(
              bob.clientId!, {'messageId': i, 'content': 'Message $i'});
          // Небольшая пауза между сообщениями
          await Future.delayed(Duration(milliseconds: 50));
        }

        // Assert
        await _waitForCondition(() => receivedMessages.length == messageCount);

        expect(receivedMessages, hasLength(messageCount));

        // Проверяем, что все сообщения уникальны и в правильном порядке
        for (int i = 0; i < messageCount; i++) {
          final message = receivedMessages[i];
          expect(message.payload?['messageId'], equals(i));
        }

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
  Duration timeout = const Duration(seconds: 2),
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
