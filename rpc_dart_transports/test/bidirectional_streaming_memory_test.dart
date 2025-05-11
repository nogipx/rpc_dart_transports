// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Сообщения для тестирования
class ChatMessage implements IRpcSerializableMessage {
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

// Используем JsonSerializer для тестов
final jsonSerializer = JsonSerializer();

/// Тест для проверки двунаправленного стриминга
void main() {
  group('Bidirectional Streaming Test', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;

    setUp(() {
      // Создаем пару связанных транспортов для теста
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: jsonSerializer,
        debugLabel: 'CLIENT',
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: jsonSerializer,
        debugLabel: 'SERVER',
      );

      // Добавляем middleware для логирования
      clientEndpoint.addMiddleware(LoggingMiddleware(id: 'client'));
      serverEndpoint.addMiddleware(LoggingMiddleware(id: 'server'));

      // Регистрируем обработчик на сервере
      serverEndpoint.registerMethod('ChatService', 'chatStream',
          (context) async {
        print('Сервер: получен запрос на чат-стрим');

        // Получаем ID сообщения для потока
        final messageId = context.messageId;

        // Слушаем входящие сообщения и отправляем ответы
        serverEndpoint
            .openStream('ChatService', 'chatStream', streamId: messageId)
            .listen((data) {
          // Проверяем на сигнал завершения
          if (data is Map<String, dynamic> &&
              (data['_clientStreamEnd'] == true ||
                  data['_channelClosed'] == true)) {
            print('Сервер: получен сигнал завершения');
            return;
          }

          // Обрабатываем сообщение чата
          if (data is Map<String, dynamic>) {
            try {
              final message = ChatMessage.fromJson(data);
              print('Сервер получил: ${message.text} от ${message.sender}');

              // Создаем ответное сообщение
              final response = ChatMessage(
                text: 'Ответ на: ${message.text}',
                sender: 'Сервер',
              );

              // Отправляем ответ
              serverEndpoint.sendStreamData(
                messageId,
                response.toJson(),
                serviceName: 'ChatService',
                methodName: 'chatStream',
              );

              print('Сервер отправил ответ на: ${message.text}');
            } catch (e) {
              print('Ошибка при обработке сообщения: $e');
            }
          }
        });

        // Возвращаем статус для начала двунаправленного стрима
        return {'status': 'bidirectional_streaming_started'};
      });

      // Регистрируем такой же метод на клиенте для поддержки канала
      clientEndpoint.registerMethod('ChatService', 'chatStream',
          (context) async {
        return {'status': 'bidirectional_streaming_started'};
      });
    });

    tearDown(() async {
      print('Завершение теста, освобождение ресурсов...');
      await clientEndpoint.close();
      await serverEndpoint.close();
    });

    test('should successfully exchange messages bidirectionally', () async {
      print('Начало теста двунаправленного стриминга');

      // Список для сбора ответов от сервера
      final receivedMessages = <ChatMessage>[];
      final completer = Completer<void>();

      // Создаем уникальный ID для стрима
      final clientStreamId =
          'test-chat-${DateTime.now().millisecondsSinceEpoch}';

      // Инициализируем стрим запросом
      print('Отправляем запрос на создание стрима с ID: $clientStreamId');
      await clientEndpoint.invoke('ChatService', 'chatStream', {},
          metadata: {'streamId': clientStreamId});
      print('Запрос на создание стрима отправлен');

      // Слушаем ответы от сервера
      clientEndpoint
          .openStream('ChatService', 'chatStream', streamId: clientStreamId)
          .listen((data) {
        if (data is Map<String, dynamic>) {
          try {
            final message = ChatMessage.fromJson(data);
            print('Клиент получил: ${message.text}');
            receivedMessages.add(message);

            // Когда получили 3 сообщения, завершаем тест
            if (receivedMessages.length == 3) {
              completer.complete();
            }
          } catch (e) {
            print('Ошибка при разборе ответа: $e');
          }
        }
      });

      // Отправляем несколько сообщений
      print('Отправка первого сообщения...');
      clientEndpoint.sendStreamData(
        clientStreamId,
        ChatMessage(
          text: 'Привет из потока!',
          sender: 'Клиент',
        ).toJson(),
        serviceName: 'ChatService',
        methodName: 'chatStream',
      );
      await Future.delayed(const Duration(milliseconds: 100));

      print('Отправка второго сообщения...');
      clientEndpoint.sendStreamData(
        clientStreamId,
        ChatMessage(
          text: 'Как работает двунаправленный стриминг?',
          sender: 'Клиент',
        ).toJson(),
        serviceName: 'ChatService',
        methodName: 'chatStream',
      );
      await Future.delayed(const Duration(milliseconds: 100));

      print('Отправка третьего сообщения...');
      clientEndpoint.sendStreamData(
        clientStreamId,
        ChatMessage(
          text: 'Это последнее сообщение',
          sender: 'Клиент',
        ).toJson(),
        serviceName: 'ChatService',
        methodName: 'chatStream',
      );

      // Ждем до 5 секунд для получения всех ответов
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Таймаут ожидания ответов');
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Закрываем стрим
      print('Закрытие стрима...');
      clientEndpoint.sendStreamData(
        clientStreamId,
        {'_clientStreamEnd': true},
        serviceName: 'ChatService',
        methodName: 'chatStream',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Проверяем результаты
      print('Получено ${receivedMessages.length} ответов');
      expect(receivedMessages.length, equals(3),
          reason: 'Должно быть получено 3 ответа');

      if (receivedMessages.isNotEmpty) {
        expect(receivedMessages[0].text, contains('Привет из потока'),
            reason: 'Первый ответ должен содержать "Привет из потока"');
      }

      if (receivedMessages.length >= 2) {
        expect(receivedMessages[1].text,
            contains('Как работает двунаправленный стриминг'),
            reason:
                'Второй ответ должен содержать "Как работает двунаправленный стриминг"');
      }

      if (receivedMessages.length >= 3) {
        expect(receivedMessages[2].text, contains('Это последнее сообщение'),
            reason: 'Третий ответ должен содержать "Это последнее сообщение"');
      }

      expect(receivedMessages.every((msg) => msg.sender == 'Сервер'), isTrue,
          reason: 'Все сообщения должны быть от отправителя "Сервер"');

      print('Тест успешно завершен');
    });
  });
}
