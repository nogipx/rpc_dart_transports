import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'bidirectional_contract.dart';
import 'bidirectional_models.dart';

/// Имя метода для чата
const chatMethod = 'chat';

/// Константа с источником логов
final RpcLogger _logger = RpcLogger('BiDirectionalExample');

/// Пример двунаправленного стриминга (поток запросов <-> поток ответов)
/// Демонстрирует работу чата с помощью двунаправленного стриминга
Future<void> main({bool debug = false}) async {
  printHeader('Пример двунаправленного стриминга (чат)');

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
  _logger.info(message: 'Эндпоинты настроены');

  try {
    // Создаем и регистрируем серверную и клиентскую реализации чат-сервиса
    final serverContract = ServerChatService();
    final clientContract = ClientChatService(clientEndpoint);

    serverEndpoint.registerServiceContract(serverContract);
    clientEndpoint.registerServiceContract(clientContract);
    _logger.info(message: 'Сервисы чата зарегистрированы');

    // Демонстрация работы чата
    await demonstrateChatExample(clientContract);
  } catch (e) {
    _logger.error(message: 'Произошла ошибка', error: {'error': e.toString()});
  } finally {
    // Закрываем эндпоинты
    await clientEndpoint.close();
    await serverEndpoint.close();
    _logger.info(message: 'Эндпоинты закрыты');
  }

  printHeader('Пример завершен');
}

/// Печатает заголовок раздела
void printHeader(String title) {
  _logger.info(message: '-------------------------');
  _logger.info(message: ' $title');
  _logger.info(message: '-------------------------');
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
  printHeader('Демонстрация работы чата');

  // Устанавливаем имя пользователя
  final userName = 'Пользователь';
  _logger.info(message: '👤 Подключаемся к чату как "$userName"');

  // Открываем двунаправленный канал для чата
  final bidiStream = chatService.chatHandler();

  // Подписываемся на входящие сообщения
  final subscription = bidiStream.listen(
    (message) {
      final timestamp =
          message.timestamp != null
              ? '${message.timestamp!.substring(11, 19)} '
              : '';

      String formattedMessage = ''; // Инициализируем переменную

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
          break;
      }

      _logger.info(message: formattedMessage);
    },
    onError:
        (e) => _logger.error(message: 'Ошибка', error: {'error': e.toString()}),
    onDone: () => _logger.info(message: '🔚 Соединение закрыто'),
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

    // Используем метод send() класса BidiStream для отправки сообщений
    bidiStream.send(chatMessage);
    _logger.info(message: '📤 Отправлено: $text');
  }

  // Даем время получить ответы от сервера
  await Future.delayed(Duration(seconds: 3));

  // Закрываем канал и подписку
  await bidiStream.close();
  await subscription.cancel();

  printHeader('Демонстрация чата завершена');
}
