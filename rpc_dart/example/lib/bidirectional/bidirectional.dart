import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'bidirectional_contract.dart';
import 'bidirectional_models.dart';

/// Имя метода для чата
const chatMethod = 'chat';

/// Пример двунаправленного стриминга (поток запросов <-> поток ответов)
/// Демонстрирует работу чата с помощью двунаправленного стриминга
Future<void> main({bool debug = false}) async {
  print('=== Пример двунаправленного стриминга (чат) ===\n');

  // Создаем и настраиваем эндпоинты
  final endpoints = setupEndpoints();
  final serverEndpoint = endpoints.server;
  final clientEndpoint = endpoints.client;

  // Добавляем middleware для отладки и логирования
  if (debug) {
    serverEndpoint.addMiddleware(DebugMiddleware(id: "server"));
    clientEndpoint.addMiddleware(DebugMiddleware(id: "client"));
  } else {
    serverEndpoint.addMiddleware(LoggingMiddleware(id: "server"));
    clientEndpoint.addMiddleware(LoggingMiddleware(id: "client"));
  }
  print('Эндпоинты настроены');

  try {
    // Создаем и регистрируем серверную и клиентскую реализации чат-сервиса
    final serverContract = ServerChatService();
    final clientContract = ClientChatService(clientEndpoint);

    serverEndpoint.registerServiceContract(serverContract);
    clientEndpoint.registerServiceContract(clientContract);
    print('Сервисы чата зарегистрированы');

    // Демонстрация работы чата
    await demonstrateChatExample(clientContract);
  } catch (e) {
    print('Произошла ошибка: $e');
  } finally {
    // Закрываем эндпоинты
    await clientEndpoint.close();
    await serverEndpoint.close();
    print('\nЭндпоинты закрыты');
  }

  print('\n=== Пример завершен ===');
}

/// Настраиваем транспорт и эндпоинты
({RpcEndpoint server, RpcEndpoint client}) setupEndpoints() {
  // Создаем транспорт в памяти для локального тестирования
  final serverTransport = MemoryTransport("server");
  final clientTransport = MemoryTransport("client");

  // Соединяем транспорты между собой
  serverTransport.connect(clientTransport);
  clientTransport.connect(serverTransport);

  // Создаем эндпоинты с метками для отладки
  final serverEndpoint = RpcEndpoint(
    transport: serverTransport,
    debugLabel: "server",
  );
  final clientEndpoint = RpcEndpoint(
    transport: clientTransport,
    debugLabel: "client",
  );

  return (server: serverEndpoint, client: clientEndpoint);
}

/// Демонстрация работы чата
Future<void> demonstrateChatExample(ClientChatService chatService) async {
  print('\n=== Демонстрация работы чата ===\n');

  // Устанавливаем имя пользователя
  final userName = 'Пользователь';
  print('👤 Подключаемся к чату как "$userName"');

  // Открываем двунаправленный канал для чата
  final channel = await chatService.chat();

  // Подписываемся на входящие сообщения
  final subscription = channel.incoming.listen(
    (message) {
      final timestamp =
          message.timestamp != null
              ? '${message.timestamp!.substring(11, 19)} '
              : '';

      String formattedMessage;

      // Форматируем сообщение в зависимости от типа
      switch (message.type) {
        case MessageType.system:
          formattedMessage = '🔧 $timestamp${message.text}';
          break;
        case MessageType.info:
          formattedMessage = 'ℹ️ $timestamp${message.text}';
          break;
        case MessageType.action:
          formattedMessage = '⚡ $timestamp${message.sender} ${message.text}';
          break;
        case MessageType.text:
          if (message.sender == userName) {
            formattedMessage = '↪️ $timestamp${message.text}';
          } else {
            formattedMessage = '${message.sender}: ${message.text}';
          }
      }

      print(formattedMessage);
    },
    onError: (e) => print('❌ Ошибка: $e'),
    onDone: () => print('🔚 Соединение закрыто'),
  );

  // Имитируем отправку сообщений от пользователя
  await Future.delayed(Duration(milliseconds: 1500));

  final messages = [
    'Привет! Я новый пользователь',
    'Как пользоваться этим чатом?',
    'Спасибо за помощь!',
    'До свидания',
  ];

  for (final text in messages) {
    await Future.delayed(Duration(milliseconds: 1500));

    final chatMessage = ChatMessage(
      sender: userName,
      text: text,
      type: MessageType.text,
      timestamp: DateTime.now().toIso8601String(),
    );

    channel.send(chatMessage);
    print('📤 Отправлено: $text');
  }

  // Даем время получить ответы от сервера
  await Future.delayed(Duration(seconds: 3));

  // Закрываем канал и подписку
  await channel.close();
  await subscription.cancel();

  print('\n=== Демонстрация чата завершена ===');
}
