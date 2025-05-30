// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:web_socket_channel/io.dart';

/// Пример использования Router для маршрутизации сообщений между клиентами
void main() async {
  // Включаем подробное логирование
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.info);

  print('🚀 Запуск примера Router RPC\n');

  // Запускаем WebSocket сервер с роутером
  await startRouterServer();

  // Даем серверу время на запуск
  await Future.delayed(Duration(seconds: 1));

  // Запускаем несколько клиентов
  await runClients();
}

/// Запускает WebSocket сервер с роутером
Future<void> startRouterServer() async {
  print('📡 Запуск WebSocket сервера роутера...');

  final server = await HttpServer.bind('localhost', 8081);
  print('✅ Сервер запущен на ws://localhost:8081\n');

  // Создаем роутер контракт
  final routerContract = RouterResponderContract(
    logger: RpcLogger('RouterServer'),
  );

  // Обрабатываем WebSocket подключения
  server.listen((request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        final channel = IOWebSocketChannel(socket);

        // Создаем транспорт для каждого клиента
        final transport = RpcWebSocketResponderTransport(
          channel,
          logger: RpcLogger('ServerTransport'),
        );

        // Создаем endpoint для этого клиента
        final endpoint = RpcResponderEndpoint(
          transport: transport,
          debugLabel: 'RouterEndpoint',
        );

        // Регистрируем роутер контракт
        endpoint.registerServiceContract(routerContract);
        endpoint.start();

        print('🔌 Новое WebSocket подключение установлено');

        // Обрабатываем закрытие соединения
        socket.done.then((_) {
          print('🔌 WebSocket соединение закрыто');
          endpoint.close();
        });
      } catch (e) {
        print('❌ Ошибка при обработке WebSocket: $e');
      }
    }
  });
}

/// Запускает несколько клиентов для демонстрации роутинга
Future<void> runClients() async {
  print('👥 Запуск клиентов...\n');

  // Создаем трех клиентов
  final clients = <RouterCallerContract>[];
  final clientNames = ['Alice', 'Bob', 'Charlie'];

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

  // Настраиваем обработчики сообщений
  for (final client in clients) {
    client.messages.listen((message) {
      final clientName = clientNames[clients.indexOf(client)];
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
        case RouterMessageType.error:
          print('❌ $clientName получил ошибку: ${message.errorMessage}');
          break;
        default:
          print('📝 $clientName получил сообщение ${message.type}: ${message.payload}');
      }
    });
  }

  // Демонстрируем различные типы маршрутизации
  await demonstrateRouting(clients, clientNames);

  // Закрываем все соединения
  print('\n🔚 Закрытие соединений...');
  for (final client in clients) {
    await client.disconnect();
  }

  exit(0);
}

/// Создает и подключает клиента
Future<RouterCallerContract> createAndConnectClient(String name) async {
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
  final client = RouterCallerContract(
    endpoint,
    logger: RpcLogger('RouterClient_$name'),
  );

  // Подключаемся к роутеру
  await client.connect(
    clientName: name,
    groups: ['developers', 'testers'],
  );

  return client;
}

/// Демонстрирует различные типы маршрутизации
Future<void> demonstrateRouting(
  List<RouterCallerContract> clients,
  List<String> clientNames,
) async {
  final alice = clients[0];
  final bob = clients[1];
  final charlie = clients.length > 2 ? clients[2] : null;

  await Future.delayed(Duration(milliseconds: 500));

  print('🎯 === Демонстрация UNICAST ===');
  // Alice отправляет сообщение Bob'у
  await alice.sendUnicast(
    targetId: bob.clientId!,
    payload: {'message': 'Привет, Bob! Это Alice 👋', 'time': DateTime.now().toIso8601String()},
  );

  await Future.delayed(Duration(milliseconds: 500));

  // Bob отвечает Alice
  await bob.sendUnicast(
    targetId: alice.clientId!,
    payload: {'message': 'Привет, Alice! Как дела? 😊', 'time': DateTime.now().toIso8601String()},
  );

  await Future.delayed(Duration(seconds: 1));

  print('\n📢 === Демонстрация MULTICAST ===');
  // Alice отправляет сообщение группе разработчиков
  await alice.sendMulticast(
    groupName: 'developers',
    payload: {
      'message': 'Ребята, не забудьте про ретроспективу завтра! 📅',
      'sender': 'Alice',
      'time': DateTime.now().toIso8601String()
    },
  );

  await Future.delayed(Duration(seconds: 1));

  print('\n📡 === Демонстрация BROADCAST ===');
  // Bob отправляет сообщение всем
  await bob.sendBroadcast(
    payload: {
      'message': '🎉 Ура! Новая версия приложения готова к релизу!',
      'sender': 'Bob',
      'announcement': true,
      'time': DateTime.now().toIso8601String()
    },
  );

  await Future.delayed(Duration(milliseconds: 500));

  // Charlie отвечает на broadcast (если есть)
  if (charlie != null) {
    await charlie.sendBroadcast(
      payload: {
        'message': '👏 Отличная работа команде! Поздравляю всех!',
        'sender': 'Charlie',
        'reaction': true,
        'time': DateTime.now().toIso8601String()
      },
    );
  }

  await Future.delayed(Duration(seconds: 1));

  print('\n🏓 === Демонстрация PING ===');
  // Тестируем задержку
  try {
    final latency = await alice.ping();
    print('⏱️  Alice: ping к роутеру = ${latency.inMilliseconds}ms');
  } catch (e) {
    print('❌ Alice: ошибка ping = $e');
  }

  await Future.delayed(Duration(milliseconds: 500));

  print('\n📡 === Демонстрация СОБЫТИЙ РОУТЕРА ===');
  // Alice подписывается на системные события
  try {
    await alice.subscribeToEvents();
    print('✅ Alice подписалась на события роутера');

    // Слушаем события
    alice.events.listen((event) {
      print('🔔 Alice получила событие ${event.type}: ${event.data}');
    });

    await Future.delayed(Duration(seconds: 1));
  } catch (e) {
    print('❌ Alice: ошибка подписки на события = $e');
  }

  print('\n🚫 === Демонстрация ошибки ===');
  // Пытаемся отправить сообщение несуществующему клиенту
  await alice.sendUnicast(
    targetId: 'nonexistent_client',
    payload: {'message': 'Это сообщение не будет доставлено'},
  );

  await Future.delayed(Duration(seconds: 2));
}
