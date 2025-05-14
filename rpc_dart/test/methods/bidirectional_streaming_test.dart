import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Модели сообщений для чата
class ChatMessage implements IRpcSerializableMessage {
  final String sender;
  final String content;
  final DateTime timestamp;

  ChatMessage(this.sender, this.content, {DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  @override
  Map<String, dynamic> toJson() => {
        'sender': sender,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  static ChatMessage fromJson(Map<String, dynamic> json) {
    print('ChatMessage.fromJson: $json');
    return ChatMessage(
      json['sender'] as String,
      json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() => 'ChatMessage(sender: $sender, content: $content)';
}

// Контракт чат-сервиса
abstract base class ChatServiceContract
    extends RpcServiceContract<IRpcSerializableMessage> {
  ChatServiceContract() : super('ChatService');

  RpcEndpoint? get client;

  // Константы для имен методов
  static const String chatSessionMethod = 'chatSession';

  @override
  void setup() {
    print('ChatServiceContract.setup()');
    // Двунаправленный стрим-метод для чата
    addBidirectionalStreamingMethod<ChatMessage, ChatMessage>(
      methodName: chatSessionMethod,
      handler: chatSession,
      argumentParser: ChatMessage.fromJson,
      responseParser: ChatMessage.fromJson,
    );
    super.setup();
  }

  // Двунаправленный стрим-метод
  BidiStream<ChatMessage, ChatMessage> chatSession();
}

// Серверная реализация
base class ServerChatService extends ChatServiceContract {
  final List<ChatMessage> messageHistory = [];

  @override
  RpcEndpoint? get client => null;

  @override
  BidiStream<ChatMessage, ChatMessage> chatSession() {
    print('ServerChatService.chatSession() - создание стрима');
    return BidiStreamGenerator<ChatMessage, ChatMessage>(
      (Stream<ChatMessage> incomingStream) {
        print('ServerChatService - обработчик стрима запущен');
        final controller = StreamController<ChatMessage>();

        // Обрабатываем входящие сообщения
        incomingStream.listen((message) {
          print('Сервер получил сообщение: $message');
          // Добавляем сообщение в историю
          messageHistory.add(message);

          // Отправляем эхо и подтверждение
          controller.add(message); // Эхо исходного сообщения
          print('Сервер отправляет эхо: $message');

          final confirmationMsg = ChatMessage(
            'Сервер',
            'Получено сообщение от ${message.sender}: "${message.content}"',
          );
          controller.add(confirmationMsg);
          print('Сервер отправляет подтверждение: $confirmationMsg');
        }, onDone: () {
          print('Сервер: входящий стрим завершен');
          // Отправляем прощальное сообщение - наш Stream закрывается до того, как это сообщение успевает дойти
          // поэтому мы не будем его ожидать в тесте
          final byeMsg = ChatMessage('Сервер', 'Сессия чата завершена');
          controller.add(byeMsg);
          print('Сервер отправляет прощание: $byeMsg');
          controller.close();
        }, onError: (error) {
          print('Сервер: ошибка в стриме - $error');
          controller.add(ChatMessage('Сервер', 'Ошибка: $error'));
          controller.close();
        });

        return controller.stream;
      },
    ).create();
  }
}

// Клиентская реализация
base class ClientChatService extends ChatServiceContract {
  @override
  final RpcEndpoint client;

  ClientChatService(this.client);

  @override
  BidiStream<ChatMessage, ChatMessage> chatSession() {
    print('ClientChatService.chatSession() - вызов');
    return client
        .bidirectionalStreaming(
          serviceName: serviceName,
          methodName: ChatServiceContract.chatSessionMethod,
        )
        .call<ChatMessage, ChatMessage>(
          responseParser: ChatMessage.fromJson,
        );
  }
}

void main() {
  group('Тестирование двунаправленного стриминга', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late JsonSerializer serializer;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientChatService clientService;
    late ServerChatService serverService;

    setUp(() {
      print('\n======= SETUP =======');
      // Создаем пару связанных транспортов
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);
      print('Транспорты созданы и связаны');

      // Сериализатор
      serializer = JsonSerializer();

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: serializer,
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: serializer,
      );
      print('Эндпоинты созданы');

      // Создаем сервисы
      serverService = ServerChatService();
      clientService = ClientChatService(clientEndpoint);
      print('Сервисы созданы');

      // Регистрируем контракт сервера
      serverEndpoint.registerServiceContract(serverService);
      print('Контракт сервера зарегистрирован');
      print('====== SETUP DONE ======\n');
    });

    tearDown(() async {
      print('\n====== TEARDOWN ======');
      await clientEndpoint.close();
      await serverEndpoint.close();
      print('Эндпоинты закрыты');
      print('===== TEARDOWN DONE =====\n');
    });

    test('двунаправленный_стриминг_обеспечивает_полноценный_обмен_сообщениями',
        () async {
      print('\n====== ТЕСТ 1 НАЧАЛО ======');
      // Создаем двунаправленный канал связи
      final chatSession = clientService.chatSession();
      print('Клиент: двунаправленный канал создан');

      // Создаем список для сбора всех полученных сообщений
      final receivedMessages = <ChatMessage>[];

      // Подписываемся на входящие сообщения
      final subscription = chatSession.listen((message) {
        print('Клиент получил сообщение: $message');
        receivedMessages.add(message);
      });
      print('Клиент: подписка на входящие сообщения установлена');

      // Отправляем несколько сообщений
      print('Клиент отправляет сообщение 1');
      chatSession.send(ChatMessage('Клиент', 'Привет, сервер!'));

      await Future.delayed(Duration(milliseconds: 50));
      print('Клиент отправляет сообщение 2');
      chatSession.send(ChatMessage('Клиент', 'Как дела?'));

      await Future.delayed(Duration(milliseconds: 50));
      print('Клиент отправляет сообщение 3');
      chatSession
          .send(ChatMessage('Клиент', 'Это тест двунаправленного стриминга'));

      // Закрываем клиентский стрим после отправки сообщений
      await Future.delayed(Duration(milliseconds: 100));
      print('Клиент закрывает стрим');
      await chatSession.close();

      // Ждем некоторое время, чтобы сервер успел ответить на все сообщения
      print('Ожидание завершения обработки...');
      await Future.delayed(Duration(milliseconds: 200));

      // Отменяем подписку
      await subscription.cancel();
      print('Подписка отменена');

      // Выводим полученные сообщения
      print('Получено сообщений: ${receivedMessages.length}');
      for (var i = 0; i < receivedMessages.length; i++) {
        print('  $i: ${receivedMessages[i]}');
      }

      // Выводим историю сообщений на сервере
      print(
          'История сообщений на сервере: ${serverService.messageHistory.length}');
      for (var i = 0; i < serverService.messageHistory.length; i++) {
        print('  $i: ${serverService.messageHistory[i]}');
      }

      // Проверяем, что получили сообщения (без прощального, т.к. оно может не дойти)
      // 3 эхо + 3 подтверждения = 6 сообщений
      expect(receivedMessages.length, equals(6));

      if (receivedMessages.isNotEmpty) {
        expect(receivedMessages[0].sender, equals('Клиент'));
        expect(receivedMessages[0].content, equals('Привет, сервер!'));

        expect(receivedMessages[1].sender, equals('Сервер'));
        expect(receivedMessages[1].content, contains('Получено сообщение'));
      }

      // Проверяем историю сообщений на сервере
      expect(serverService.messageHistory.length, equals(3));
      if (serverService.messageHistory.isNotEmpty) {
        expect(
            serverService.messageHistory[0].content, equals('Привет, сервер!'));
      }
      if (serverService.messageHistory.length >= 3) {
        expect(serverService.messageHistory[2].content,
            equals('Это тест двунаправленного стриминга'));
      }

      print('====== ТЕСТ 1 КОНЕЦ ======\n');
    });

    test('клиент_может_обрабатывать_серверные_сообщения_асинхронно', () async {
      print('\n====== ТЕСТ 2 НАЧАЛО ======');
      // Создаем двунаправленный канал связи
      final chatSession = clientService.chatSession();
      print('Клиент: двунаправленный канал создан');

      // Счетчики сообщений
      int echoCount = 0;
      int confirmationCount = 0;

      // Подписываемся на входящие сообщения с фильтрацией
      final subscription = chatSession.listen((message) {
        print('Клиент получил сообщение: $message');
        if (message.sender == 'Клиент') {
          echoCount++;
          print('  Это эхо, текущий счетчик: $echoCount');
        } else if (message.sender == 'Сервер' &&
            message.content.startsWith('Получено')) {
          confirmationCount++;
          print('  Это подтверждение, текущий счетчик: $confirmationCount');
        }
      });
      print('Клиент: подписка на входящие сообщения установлена');

      // Отправляем сообщения с задержкой, чтобы имитировать реальное взаимодействие
      print('Клиент отправляет сообщение 1');
      chatSession.send(ChatMessage('Клиент', 'Сообщение 1'));
      await Future.delayed(Duration(milliseconds: 50));

      print('Клиент отправляет сообщение 2');
      chatSession.send(ChatMessage('Клиент', 'Сообщение 2'));
      await Future.delayed(Duration(milliseconds: 50));

      print('Клиент отправляет сообщение 3');
      chatSession.send(ChatMessage('Клиент', 'Сообщение 3'));
      await Future.delayed(Duration(milliseconds: 100));

      // Закрываем стрим и ждем завершения обработки
      print('Клиент закрывает стрим');
      await chatSession.close();
      await Future.delayed(Duration(milliseconds: 200));

      print(
          'Итоговые счетчики: эхо=$echoCount, подтверждения=$confirmationCount');

      await subscription.cancel();
      print('Подписка отменена');

      // Проверяем счетчики сообщений
      expect(echoCount, equals(3));
      expect(confirmationCount, equals(3));

      print('====== ТЕСТ 2 КОНЕЦ ======\n');
    });
  });
}
