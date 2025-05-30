// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:web_socket_channel/io.dart';

/// Демонстрирует работу роутера RPC для маршрутизации сообщений между клиентами
///
/// Этот пример показывает:
/// 1. Запуск роутера на WebSocket
/// 2. Подключение нескольких клиентов
/// 3. Различные типы сообщений: unicast, multicast, broadcast
/// 4. Система событий роутера
/// 5. Request-Response паттерн
Future<void> main() async {
  print('🚀 Запуск роутера RPC демонстрации\n');

  // Запускаем роутер сервер
  final serverData = await startRouterServer();
  final server = serverData['server'] as HttpServer;
  final routerContract = serverData['contract'] as RouterResponderContract;

  print('✅ Роутер запущен на ws://localhost:8081\n');

  // Небольшая пауза для инициализации сервера
  await Future.delayed(Duration(milliseconds: 500));

  try {
    await runClientDemo();
  } catch (e, stackTrace) {
    print('❌ Ошибка в демонстрации: $e\n$stackTrace');
  } finally {
    // Закрываем роутер контракт
    await routerContract.dispose();

    // Закрываем сервер
    await server.close(force: true);
    print('🔚 Роутер остановлен');

    // Даем время системе на очистку
    await Future.delayed(Duration(milliseconds: 100));

    // Принудительно выходим из программы
    exit(0);
  }
}

/// Запускает роутер сервер
Future<Map<String, dynamic>> startRouterServer() async {
  // Создаем роутер контракт
  final routerContract = RouterResponderContract(
    logger: RpcLogger('RouterServer'),
  );

  // Создаем WebSocket сервер
  final server = await HttpServer.bind('localhost', 8081);

  server.listen((request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final websocket = await WebSocketTransformer.upgrade(request);
        final channel = IOWebSocketChannel(websocket);
        final transport = RpcWebSocketResponderTransport(
          channel,
          logger: RpcLogger('ServerTransport'),
        );

        // Создаем endpoint для каждого соединения
        final endpoint = RpcResponderEndpoint(
          transport: transport,
          debugLabel: 'RouterEndpoint',
        );

        // Регистрируем контракт и запускаем
        endpoint.registerServiceContract(routerContract);
        endpoint.start();

        print('🔌 Новое клиентское соединение');
      } catch (e) {
        print('❌ Ошибка WebSocket соединения: $e');
        request.response.statusCode = 500;
        await request.response.close();
      }
    } else {
      request.response.statusCode = 404;
      await request.response.close();
    }
  });

  return {
    'server': server,
    'contract': routerContract,
  };
}

/// Демонстрирует работу клиентов
Future<void> runClientDemo() async {
  print('👥 Запуск клиентов...\n');

  // Создаем трех клиентов
  final clients = <RouterClient>[];
  final clientNames = ['Alice', 'Bob', 'Charlie'];
  StreamSubscription? eventsSubscription;

  try {
    // Подключаем всех клиентов
    for (final name in clientNames) {
      try {
        final client = await createAndConnectClient(name);
        clients.add(client);
        print('✅ Клиент $name подключен с ID: ${client.clientId}\n');
      } catch (e) {
        print('❌ Ошибка подключения клиента $name: $e\n');
      }
    }

    if (clients.length < 2) {
      print('❌ Недостаточно клиентов для демонстрации');
      return;
    }

    // Настраиваем P2P для всех клиентов
    for (int i = 0; i < clients.length; i++) {
      final client = clients[i];
      final clientName = clientNames[i];

      await client.initializeP2P(
        onP2PMessage: (message) {
          switch (message.type) {
            case RouterMessageType.unicast:
              print('📩 $clientName получил unicast от ${message.senderId}: ${message.payload}');
              break;
            case RouterMessageType.multicast:
              print(
                  '📢 $clientName получил multicast от ${message.senderId} (группа: ${message.groupName}): ${message.payload}');
              break;
            case RouterMessageType.broadcast:
              print('📡 $clientName получил broadcast от ${message.senderId}: ${message.payload}');
              break;
            case RouterMessageType.request:
              print('🔔 $clientName получил request от ${message.senderId}: ${message.payload}');
              // Автоматически отвечаем на запросы
              _handleRequest(client, message);
              break;
            case RouterMessageType.response:
              print('✅ $clientName получил response от ${message.senderId}: ${message.payload}');
              break;
            case RouterMessageType.error:
              print('❌ $clientName получил ошибку: ${message.errorMessage}');
              break;
            default:
              print('📝 $clientName получил сообщение ${message.type}: ${message.payload}');
          }
        },
      );
    }

    // Подписываемся на события роутера
    await clients[0].subscribeToEvents();
    eventsSubscription = clients[0].events.listen((event) {
      print('🔔 Alice получила событие роутера ${event.type}: ${event.data}');
    });

    // Демонстрируем различные типы маршрутизации
    await demonstrateRouting(clients, clientNames);
  } finally {
    // Отменяем подписку на события
    await eventsSubscription?.cancel();

    // Закрываем все соединения
    print('\n🔚 Закрытие соединений...');
    for (final client in clients) {
      try {
        await client.dispose();
      } catch (e) {
        print('❌ Ошибка закрытия клиента: $e');
      }
    }
  }
}

/// Обрабатывает входящий request и отправляет response
void _handleRequest(RouterClient client, RouterMessage request) {
  final requestId = request.payload?['requestId'] as String?;
  final senderId = request.senderId;

  if (requestId != null && senderId != null) {
    // Отправляем ответ
    final responseMessage = RouterMessage.response(
      targetId: senderId,
      requestId: requestId,
      payload: {
        'originalRequest': request.payload,
        'respondedBy': client.clientId,
        'timestamp': DateTime.now().toIso8601String(),
      },
      senderId: client.clientId,
    );

    client.sendP2PMessage(responseMessage);
  }
}

/// Создает и подключает клиента
Future<RouterClient> createAndConnectClient(String name) async {
  // Создаем WebSocket транспорт
  final transport = RpcWebSocketCallerTransport.connect(
    Uri.parse('ws://localhost:8081'),
    logger: RpcLogger('Client_$name'),
  );

  // Создаем endpoint
  final endpoint = RpcCallerEndpoint(
    transport: transport,
    debugLabel: 'Client_$name',
  );

  // Создаем роутер клиент
  final client = RouterClient(
    callerEndpoint: endpoint,
    logger: RpcLogger('RouterClient_$name'),
  );

  // Регистрируемся в роутере
  await client.register(
    clientName: name,
    groups: ['developers', 'testers'],
  );

  return client;
}

/// Демонстрирует различные типы маршрутизации
Future<void> demonstrateRouting(
  List<RouterClient> clients,
  List<String> clientNames,
) async {
  final alice = clients[0];
  final bob = clients[1];
  final charlie = clients.length > 2 ? clients[2] : null;

  await Future.delayed(Duration(milliseconds: 200));

  print('🏓 === Демонстрация PING ===');
  // Тестируем задержку
  try {
    final latency = await alice.ping();
    print('⏱️  Alice: ping к роутеру = ${latency.inMilliseconds}ms\n');
  } catch (e) {
    print('❌ Alice: ошибка ping = $e\n');
  }

  print('🔍 === Демонстрация DISCOVERY ===');
  // Alice запрашивает список онлайн клиентов
  try {
    final onlineClients = await alice.getOnlineClients();
    print('🔍 Alice получила список онлайн клиентов:');
    for (final client in onlineClients) {
      print('   - ${client.clientName} (${client.clientId}) - группы: ${client.groups}');
    }
    print('');
  } catch (e) {
    print('❌ Alice: ошибка получения списка клиентов = $e\n');
  }

  print('🎯 === Демонстрация UNICAST ===');
  // Alice отправляет сообщение Bob'у
  await alice.sendUnicast(
    bob.clientId!,
    {'message': 'Привет, Bob! Это Alice 👋', 'time': DateTime.now().toIso8601String()},
  );

  await Future.delayed(Duration(milliseconds: 200));

  // Bob отвечает Alice
  await bob.sendUnicast(
    alice.clientId!,
    {'message': 'Привет, Alice! Как дела? 😊', 'time': DateTime.now().toIso8601String()},
  );

  await Future.delayed(Duration(milliseconds: 300));

  print('\n📢 === Демонстрация MULTICAST ===');
  // Alice отправляет сообщение группе разработчиков
  await alice.sendMulticast(
    'developers',
    {
      'message': 'Ребята, не забудьте про ретроспективу завтра! 📅',
      'sender': 'Alice',
      'time': DateTime.now().toIso8601String()
    },
  );

  await Future.delayed(Duration(milliseconds: 300));

  print('\n📡 === Демонстрация BROADCAST ===');
  // Bob отправляет сообщение всем
  await bob.sendBroadcast({
    'message': '🎉 Ура! Новая версия приложения готова к релизу!',
    'sender': 'Bob',
    'announcement': true,
    'time': DateTime.now().toIso8601String()
  });

  await Future.delayed(Duration(milliseconds: 200));

  // Charlie отвечает на broadcast (если есть)
  if (charlie != null) {
    await charlie.sendBroadcast({
      'message': '👏 Отличная работа команде! Поздравляю всех!',
      'sender': 'Charlie',
      'reaction': true,
      'time': DateTime.now().toIso8601String()
    });
  }

  await Future.delayed(Duration(milliseconds: 300));

  print('\n🔄 === Демонстрация REQUEST-RESPONSE ===');
  // Alice отправляет запрос Bob'у
  try {
    final response = await alice.sendRequest(
      bob.clientId!,
      {
        'question': 'Какая у тебя любимая фича в новой версии?',
        'from': 'Alice',
      },
      timeout: Duration(seconds: 3),
    );
    print('💬 Alice получила ответ от Bob: $response');
  } catch (e) {
    print('❌ Alice: ошибка request-response = $e');
  }

  await Future.delayed(Duration(milliseconds: 300));

  print('\n🚫 === Демонстрация ошибки ===');
  // Пытаемся отправить сообщение несуществующему клиенту
  await alice.sendUnicast(
    'nonexistent_client',
    {'message': 'Это сообщение не будет доставлено'},
  );

  await Future.delayed(Duration(milliseconds: 300));

  print('\n✅ === Демонстрация завершена ===');
}
