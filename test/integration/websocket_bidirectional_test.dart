import 'dart:async';
import 'dart:io';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

/// Тест для проверки двунаправленного стриминга через WebSocket
void main() {
  late HttpServer webSocketServer;
  late RpcEndpoint serverEndpoint;
  late RpcEndpoint clientEndpoint;

  // Completer для уведомления о готовности сервера
  final serverReady = Completer<void>();

  setUp(() async {
    // Запускаем HTTP сервер с поддержкой WebSocket
    webSocketServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    print('WebSocket сервер запущен на порту ${webSocketServer.port}');

    // Настраиваем обработчик входящих соединений
    webSocketServer.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        // Подключаемся к WebSocket
        WebSocket webSocket = await WebSocketTransformer.upgrade(request);
        print('Новое WebSocket соединение установлено');

        // Создаем транспорт на стороне сервера из существующего WebSocket
        final serverTransport =
            WebSocketTransport.fromWebSocket('server', webSocket);

        // Создаем серверный эндпоинт
        serverEndpoint = RpcEndpoint(serverTransport, JsonSerializer());

        // Добавляем middleware для логирования
        serverEndpoint.addMiddleware(LoggingMiddleware(id: 'server'));

        // Регистрируем обработчик двунаправленного стриминга на сервере
        serverEndpoint
            .bidirectionalMethod('ChatService', 'chatStream')
            .register<ChatMessage, ChatMessage>(
              handler: (incomingStream, messageId) {
                print('Сервер: запрос на создание двунаправленного стрима');
                // Обработчик преобразует сообщения от клиента в ответы
                return incomingStream.map((clientMessage) {
                  print('Сервер получил: ${clientMessage.text}');
                  return ChatMessage(
                    text: 'Ответ на: ${clientMessage.text}',
                    sender: 'Сервер',
                  );
                });
              },
              requestParser: ChatMessage.fromJson,
              responseParser: ChatMessage.fromJson,
            );

        // Уведомляем о готовности сервера
        if (!serverReady.isCompleted) {
          serverReady.complete();
        }
      } else {
        // Отклоняем запросы не-WebSocket
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      }
    });

    // Создаем клиентский транспорт, подключающийся к серверу
    final clientTransport = WebSocketTransport(
      'client',
      'ws://localhost:${webSocketServer.port}',
    );
    await clientTransport.connect();
    print('Клиент подключен к серверу');

    // Создаем клиентский endpoint
    clientEndpoint = RpcEndpoint(clientTransport, JsonSerializer());

    // Добавляем middleware для логирования
    clientEndpoint.addMiddleware(LoggingMiddleware(id: 'client'));

    // Ждем готовности сервера с таймаутом
    await serverReady.future.timeout(
      Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException('Сервер не был подготовлен за 5 секунд');
      },
    );
  });

  tearDown(() async {
    print('Завершение теста, освобождение ресурсов...');

    // Сначала закрываем каналы на клиенте и делаем паузу перед закрытием endpoints
    await Future.delayed(Duration(milliseconds: 500));

    // Закрываем endpoints в правильном порядке:
    // Сначала клиент, затем сервер
    try {
      await clientEndpoint.close();
      print('Клиентский endpoint закрыт');
    } catch (e) {
      print('Ошибка при закрытии клиентского endpoint: $e');
    }

    // Ждем, пока все сообщения будут обработаны
    await Future.delayed(Duration(milliseconds: 500));

    try {
      if (serverReady.isCompleted) {
        await serverEndpoint.close();
        print('Серверный endpoint закрыт');
      }
    } catch (e) {
      print('Ошибка при закрытии серверного endpoint: $e');
    }

    // Даем время на закрытие всех соединений перед остановкой сервера
    await Future.delayed(Duration(milliseconds: 500));

    // Останавливаем HTTP сервер
    await webSocketServer.close();
    print('WebSocket сервер остановлен');
  });

  test('Двунаправленный стриминг через WebSocket', () async {
    print('Начало теста двунаправленного стриминга');

    // Создаем двунаправленный канал на клиенте
    final channel = clientEndpoint
        .bidirectionalMethod('ChatService', 'chatStream')
        .createChannel<ChatMessage, ChatMessage>(
          requestParser: ChatMessage.fromJson,
          responseParser: ChatMessage.fromJson,
        );
    print('Двунаправленный канал создан');

    // Список для сбора ответов
    final responses = <ChatMessage>[];

    // Подписываемся на входящие сообщения
    final subscription = channel.incoming.listen(
      (message) {
        print('Клиент получил: ${message.text}');
        responses.add(message);
      },
      onError: (e) => print('Ошибка в канале: $e'),
      onDone: () => print('Канал закрыт'),
    );
    print('Подписка на сообщения установлена');

    // Отправляем несколько сообщений
    print('Отправка первого сообщения...');
    channel.send(ChatMessage(
      text: 'Привет из WebSocket!',
      sender: 'Клиент',
    ));
    await Future.delayed(Duration(milliseconds: 300));

    print('Отправка второго сообщения...');
    channel.send(ChatMessage(
      text: 'Как работает двунаправленный стриминг?',
      sender: 'Клиент',
    ));
    await Future.delayed(Duration(milliseconds: 300));

    print('Отправка третьего сообщения...');
    channel.send(ChatMessage(
      text: 'Это последнее сообщение',
      sender: 'Клиент',
    ));
    // Даем больше времени на обработку последнего сообщения
    await Future.delayed(Duration(milliseconds: 700));

    // Закрываем канал и делаем паузу перед отменой подписки
    print('Закрытие канала...');
    await channel.close();
    await Future.delayed(Duration(milliseconds: 300));
    await subscription.cancel();
    print('Канал закрыт.');

    // Проверяем результаты
    print('Получено ${responses.length} ответов');

    // Проверяем, что мы получили все ответы
    expect(responses.length, equals(3),
        reason: 'Должно быть получено 3 ответа');

    if (responses.isNotEmpty) {
      expect(responses[0].text, contains('Привет из WebSocket'),
          reason: 'Первый ответ должен содержать "Привет из WebSocket"');
    }

    if (responses.length >= 2) {
      expect(
          responses[1].text, contains('Как работает двунаправленный стриминг'),
          reason:
              'Второй ответ должен содержать "Как работает двунаправленный стриминг"');
    }

    if (responses.length >= 3) {
      expect(responses[2].text, contains('Это последнее сообщение'),
          reason: 'Третий ответ должен содержать "Это последнее сообщение"');
    }

    expect(responses.every((msg) => msg.sender == 'Сервер'), isTrue,
        reason: 'Все сообщения должны быть от отправителя "Сервер"');

    print('Тест успешно завершен');
  });
}

/// Сообщения для тестирования
class ChatMessage implements RpcSerializableMessage {
  final String text;
  final String sender;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.sender,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sender': sender,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      sender: json['sender'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() => 'ChatMessage(sender: $sender, text: $text)';
}
