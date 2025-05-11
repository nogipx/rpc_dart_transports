// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:test/test.dart';

// Создаем сериализатор JSON для тестов
final jsonSerializer = JsonSerializer();

/// Тест для проверки двунаправленного стриминга через WebSocket
void main() {
  group('WebSocketTransport Bidirectional Streaming Test', () {
    late HttpServer webSocketServer;
    late RpcEndpoint serverEndpoint;
    late RpcEndpoint clientEndpoint;
    late RpcTransport serverTransport;

    // Completer для уведомления о готовности сервера
    final serverReady = Completer<void>();

    setUp(() async {
      // Запускаем HTTP сервер с поддержкой WebSocket на случайном порту
      webSocketServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverPort = webSocketServer.port;
      print('WebSocket сервер запущен на порту $serverPort');

      // Обработчик входящих соединений
      webSocketServer.listen((request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final webSocket = await WebSocketTransformer.upgrade(request);
          print('Новое WebSocket соединение установлено');

          // Создаем транспорт на стороне сервера
          serverTransport = createServerWebSocketTransport('server', webSocket);

          // Создаем эндпоинт сервера
          serverEndpoint = RpcEndpoint(
            transport: serverTransport,
            serializer: jsonSerializer,
            debugLabel: 'SERVER',
          );

          // Регистрируем обработчик на сервере
          serverEndpoint.registerMethod('ChatService', 'chatStream', (context) async {
            print('Сервер: получен запрос на чат-стрим');

            // Получаем ID сообщения для потока
            final messageId = context.messageId;

            // Слушаем входящие сообщения и отправляем ответы
            serverEndpoint
                .openStream('ChatService', 'chatStream', streamId: messageId)
                .listen((data) {
              // Проверяем на сигнал завершения
              if (data is Map<String, dynamic> &&
                  (data['_clientStreamEnd'] == true || data['_channelClosed'] == true)) {
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

          // Добавляем middleware для логирования
          serverEndpoint.addMiddleware(LoggingMiddleware(id: 'server'));

          // Уведомляем о готовности сервера
          if (!serverReady.isCompleted) {
            serverReady.complete();
          }
        } else {
          // Отклоняем не-WebSocket запросы
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
        }
      });

      // Создаем клиентский транспорт, подключающийся к серверу
      final clientTransport = WebSocketTransport.fromUrl(
        'client',
        'ws://localhost:$serverPort',
        autoConnect: true,
      );
      print('Клиентский транспорт создан');

      // Создаем клиентский эндпоинт
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: jsonSerializer,
        debugLabel: 'CLIENT',
      );

      // Добавляем middleware для логирования
      clientEndpoint.addMiddleware(LoggingMiddleware(id: 'client'));

      // Регистрируем метод на клиенте для поддержки канала
      clientEndpoint.registerMethod('ChatService', 'chatStream', (context) async {
        return {'status': 'bidirectional_streaming_started'};
      });

      // Ждем готовности сервера
      await serverReady.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Сервер не был готов за 5 секунд');
        },
      );

      print('Сервер и клиент готовы к тесту');
    });

    tearDown(() async {
      print('Завершение теста, освобождение ресурсов...');

      // Сначала закрываем клиентский эндпоинт
      try {
        await clientEndpoint.close();
        print('Клиентский эндпоинт закрыт');
      } catch (e) {
        print('Ошибка при закрытии клиентского эндпоинта: $e');
      }

      // Затем серверный эндпоинт
      try {
        if (serverReady.isCompleted) {
          await serverEndpoint.close();
          print('Серверный эндпоинт закрыт');
        }
      } catch (e) {
        print('Ошибка при закрытии серверного эндпоинта: $e');
      }

      // Наконец останавливаем сервер
      await webSocketServer.close();
      print('WebSocket сервер остановлен');
    });

    test('should successfully exchange messages bidirectionally via WebSocket', () async {
      print('Начало теста двунаправленного стриминга через WebSocket');

      // Список для сбора ответов от сервера
      final receivedMessages = <ChatMessage>[];
      final completer = Completer<void>();

      // Создаем уникальный ID для стрима
      final clientStreamId = 'test-chat-${DateTime.now().millisecondsSinceEpoch}';

      // Инициализируем стрим запросом
      print('Отправляем запрос на создание стрима с ID: $clientStreamId');
      await clientEndpoint.invoke(
        'ChatService',
        'chatStream',
        {},
        timeout: const Duration(seconds: 20),
        metadata: {
          'streamId': clientStreamId,
        },
      );
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
      await clientEndpoint.sendStreamData(
        clientStreamId,
        ChatMessage(
          text: 'Привет из WebSocket!',
          sender: 'Клиент',
        ).toJson(),
        serviceName: 'ChatService',
        methodName: 'chatStream',
      );
      print('Первое сообщение отправлено');
      await Future.delayed(const Duration(milliseconds: 200));

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
      await Future.delayed(const Duration(milliseconds: 200));

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

      // Ждем до 10 секунд для получения всех ответов
      await completer.future.timeout(
        const Duration(seconds: 10),
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

      await Future.delayed(const Duration(milliseconds: 200));

      // Проверяем результаты
      print('Получено ${receivedMessages.length} ответов');
      expect(receivedMessages.length, equals(3), reason: 'Должно быть получено 3 ответа');

      if (receivedMessages.isNotEmpty) {
        expect(receivedMessages[0].text, contains('Привет из WebSocket'),
            reason: 'Первый ответ должен содержать "Привет из WebSocket"');
      }

      if (receivedMessages.length >= 2) {
        expect(receivedMessages[1].text, contains('Как работает двунаправленный стриминг'),
            reason: 'Второй ответ должен содержать "Как работает двунаправленный стриминг"');
      }

      if (receivedMessages.length >= 3) {
        expect(receivedMessages[2].text, contains('Это последнее сообщение'),
            reason: 'Третий ответ должен содержать "Это последнее сообщение"');
      }

      expect(receivedMessages.every((msg) => msg.sender == 'Сервер'), isTrue,
          reason: 'Все сообщения должны быть от отправителя "Сервер"');

      print('Тест успешно завершен');
    }, timeout: Timeout(Duration(seconds: 5)));
  });
}

/// Сообщения для тестирования
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

/// Создает транспорт для сервера из существующего WebSocket соединения
RpcTransport createServerWebSocketTransport(String id, WebSocket webSocket) {
  // Создаем broadcast контроллер для входящих сообщений
  final controller = StreamController<Uint8List>.broadcast();

  // Подписываемся на сообщения из WebSocket
  webSocket.listen(
    (dynamic data) {
      if (data is String) {
        controller.add(Uint8List.fromList(data.codeUnits));
      } else if (data is List<int>) {
        controller.add(Uint8List.fromList(data));
      }
    },
    onError: (error) => controller.addError(error),
    onDone: () {
      if (!controller.isClosed) {
        controller.close();
      }
    },
  );

  // Создаем и возвращаем транспорт
  return _ServerWebSocketTransport(id, webSocket, controller.stream);
}

/// Транспорт для сервера на основе существующего WebSocket
class _ServerWebSocketTransport implements RpcTransport {
  @override
  final String id;
  final WebSocket _webSocket;
  final Stream<Uint8List> _incomingStream;
  bool _isAvailable = true;

  _ServerWebSocketTransport(this.id, this._webSocket, this._incomingStream);

  @override
  Future<RpcTransportActionStatus> close() async {
    _isAvailable = false;
    await _webSocket.close();
    return RpcTransportActionStatus.success;
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  Stream<Uint8List> receive() => _incomingStream;

  @override
  Future<RpcTransportActionStatus> send(Uint8List data, {Duration? timeout}) async {
    if (!_isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    try {
      _webSocket.add(data);
      return RpcTransportActionStatus.success;
    } catch (e) {
      print('Ошибка при отправке данных: $e');
      return RpcTransportActionStatus.unknownError;
    }
  }
}
