// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// Пример использования RouterClientWithReconnect
void main() async {
  await basicReconnectExample();
  await advancedReconnectExample();
  await chatClientExample();
}

/// Базовый пример автоматического переподключения
Future<void> basicReconnectExample() async {
  print('=== Базовый пример RouterClientWithReconnect ===');

  final logger = RpcLogger('ReconnectExample');

  // Создаем клиент с автоматическим переподключением
  final routerClient = RouterClientWithReconnect(
    serverUri: Uri.parse('ws://localhost:8080'), // Замените на ваш сервер
    logger: logger,
  );

  try {
    // Слушаем события состояния соединения
    routerClient.connectionState.listen((state) {
      print('Состояние соединения: $state');
    });

    // Подключаемся
    print('Подключение к роутеру...');
    await routerClient.connect();

    // Регистрируемся
    final clientId = await routerClient.register(
      clientName: 'TestClient',
      groups: ['test'],
      metadata: {'version': '1.0'},
    );
    print('Зарегистрирован клиент: $clientId');

    // Инициализируем P2P
    await routerClient.initializeP2P(
      onP2PMessage: (message) {
        print('Получено P2P сообщение: ${message.type} от ${message.senderId}');
      },
    );
    print('P2P соединение инициализировано');

    // Подписываемся на события роутера
    await routerClient.subscribeToEvents();
    routerClient.events.listen((event) {
      print('Событие роутера: ${event.type}');
    });

    // Имитируем работу клиента
    print('Клиент работает... (переподключение будет автоматическим)');

    // Отправляем сообщения периодически
    final timer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        if (routerClient.isConnected) {
          await routerClient.sendBroadcast({
            'message': 'Тестовое сообщение от ${DateTime.now()}',
          });
          print('Отправлено broadcast сообщение');
        }
      } catch (e) {
        print('Ошибка отправки сообщения: $e');
      }
    });

    // Работаем 30 секунд
    await Future.delayed(Duration(seconds: 30));
    timer.cancel();
  } catch (e) {
    print('Ошибка: $e');
  } finally {
    await routerClient.dispose();
    print('Клиент закрыт\n');
  }
}

/// Продвинутая конфигурация переподключения
Future<void> advancedReconnectExample() async {
  print('=== Продвинутая конфигурация переподключения ===');

  // Кастомная конфигурация переподключения
  final reconnectConfig = ReconnectConfig(
    strategy: ReconnectStrategy.exponentialBackoff,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 15),
    maxAttempts: 0, // Бесконечные попытки
    backoffMultiplier: 1.5,
    connectionTimeout: Duration(seconds: 10),
    enableJitter: true,
  );

  final routerClient = RouterClientWithReconnect(
    serverUri: Uri.parse('ws://localhost:8080'),
    reconnectConfig: reconnectConfig,
    logger: RpcLogger('AdvancedReconnect'),
  );

  try {
    // Детальная статистика состояния
    routerClient.connectionState.listen((state) {
      final timestamp = DateTime.now().toString().substring(11, 19);
      print('[$timestamp] Состояние: $state');
    });

    await routerClient.connect();
    await routerClient.register(clientName: 'AdvancedClient');

    print('Клиент настроен с продвинутой конфигурацией');
    print('- Стратегия: экспоненциальная задержка');
    print('- Начальная задержка: 1s');
    print('- Максимальная задержка: 15s');
    print('- Jitter включен');
    print('- Бесконечные попытки переподключения');

    // Работаем некоторое время
    await Future.delayed(Duration(seconds: 20));
  } catch (e) {
    print('Ошибка: $e');
  } finally {
    await routerClient.dispose();
    print('');
  }
}

/// Пример чат-клиента с переподключением
Future<void> chatClientExample() async {
  print('=== Чат-клиент с автоматическим переподключением ===');

  final chatClient = ChatClientWithReconnect(
    serverUri: Uri.parse('ws://localhost:8080'),
    userName: 'TestUser',
  );

  try {
    await chatClient.start();

    // Отправляем несколько сообщений
    await Future.delayed(Duration(seconds: 2));
    await chatClient.sendMessage('Привет всем!');

    await Future.delayed(Duration(seconds: 3));
    await chatClient.sendMessage('Как дела?');

    // Работаем некоторое время
    await Future.delayed(Duration(seconds: 15));
  } catch (e) {
    print('Ошибка чат-клиента: $e');
  } finally {
    await chatClient.stop();
    print('Чат-клиент остановлен');
  }
}

/// Пример реализации чат-клиента с переподключением
class ChatClientWithReconnect {
  final Uri serverUri;
  final String userName;

  late final RouterClientWithReconnect _routerClient;
  String? _clientId;

  ChatClientWithReconnect({
    required this.serverUri,
    required this.userName,
  });

  /// Запускает чат-клиент
  Future<void> start() async {
    print('Запуск чат-клиента: $userName');

    // Создаем клиент с переподключением
    _routerClient = RouterClientWithReconnect(
      serverUri: serverUri,
      reconnectConfig: ReconnectConfig(
        strategy: ReconnectStrategy.exponentialBackoff,
        initialDelay: Duration(seconds: 2),
        maxDelay: Duration(seconds: 30),
        enableJitter: true,
      ),
      logger: RpcLogger('ChatClient'),
    );

    // Слушаем состояние соединения
    _routerClient.connectionState.listen((state) {
      switch (state) {
        case ReconnectState.connected:
          print('[$userName] ✅ Подключен к чату');
          break;
        case ReconnectState.disconnected:
          print('[$userName] ❌ Отключен от чата');
          break;
        case ReconnectState.reconnecting:
          print('[$userName] 🔄 Переподключение...');
          break;
        case ReconnectState.waiting:
          print('[$userName] ⏳ Ожидание переподключения...');
          break;
        case ReconnectState.stopped:
          print('[$userName] ⛔ Переподключение остановлено');
          break;
      }
    });

    // Подключаемся и регистрируемся
    await _routerClient.connect();
    _clientId = await _routerClient.register(
      clientName: userName,
      groups: ['chat'],
      metadata: {'type': 'chat_client'},
    );

    // Инициализируем P2P для получения сообщений
    await _routerClient.initializeP2P(
      onP2PMessage: _handleChatMessage,
      filterRouterHeartbeats: true,
    );

    print('[$userName] Чат-клиент готов к работе (ID: $_clientId)');
  }

  /// Обрабатывает входящие чат-сообщения
  void _handleChatMessage(RouterMessage message) {
    if (message.type == RouterMessageType.multicast &&
        message.payload?['chatMessage'] != null) {
      final chatText = message.payload!['chatMessage'] as String;
      final senderName = message.payload!['senderName'] as String;
      final timestamp = DateTime.now().toString().substring(11, 19);

      print('[$timestamp] <$senderName>: $chatText');
    }
  }

  /// Отправляет сообщение в чат
  Future<void> sendMessage(String text) async {
    if (!_routerClient.isConnected) {
      print('[$userName] ⚠️ Нет соединения, сообщение не отправлено: $text');
      return;
    }

    try {
      await _routerClient.sendMulticast('chat', {
        'chatMessage': text,
        'senderName': userName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Отображаем свое сообщение
      final timestamp = DateTime.now().toString().substring(11, 19);
      print('[$timestamp] <$userName>: $text');
    } catch (e) {
      print('[$userName] ❌ Ошибка отправки сообщения: $e');
    }
  }

  /// Останавливает чат-клиент
  Future<void> stop() async {
    await _routerClient.dispose();
  }
}
