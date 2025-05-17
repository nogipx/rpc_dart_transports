import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';
import 'fixtures/test_contract.dart';
import 'fixtures/test_factory.dart';

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
abstract class ChatServiceContract extends IExtensionTestContract {
  // Константы для имен методов
  static const String chatSessionMethod = 'chatSession';

  ChatServiceContract() : super('ChatService');

  @override
  void setup() {
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
class ServerChatService extends ChatServiceContract {
  final List<ChatMessage> messageHistory = [];

  @override
  BidiStream<ChatMessage, ChatMessage> chatSession() {
    return BidiStreamGenerator<ChatMessage, ChatMessage>(
      (Stream<ChatMessage> incomingStream) {
        final controller = StreamController<ChatMessage>();

        // Обрабатываем входящие сообщения
        incomingStream.listen((message) {
          // Добавляем сообщение в историю
          messageHistory.add(message);

          // Отправляем эхо и подтверждение
          controller.add(message); // Эхо исходного сообщения

          final confirmationMsg = ChatMessage(
            'Сервер',
            'Получено сообщение от ${message.sender}: "${message.content}"',
          );
          controller.add(confirmationMsg);
        }, onDone: () {
          // Отправляем прощальное сообщение
          final byeMsg = ChatMessage('Сервер', 'Сессия чата завершена');
          controller.add(byeMsg);
          controller.close();
        }, onError: (error) {
          controller.add(ChatMessage('Сервер', 'Ошибка: $error'));
          controller.close();
        });

        return controller.stream;
      },
    ).create();
  }
}

// Клиентская реализация
class ClientChatService extends ChatServiceContract {
  final RpcEndpoint _endpoint;

  ClientChatService(this._endpoint);

  @override
  BidiStream<ChatMessage, ChatMessage> chatSession() {
    return _endpoint
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
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientChatService clientService;
    late ServerChatService serverService;

    setUp(() {
      // Используем фабрику для создания тестового окружения
      final testEnv = TestContractFactory.setupTestEnvironment(
        extensionFactories: [
          (
            type: ChatServiceContract,
            clientFactory: (endpoint) => ClientChatService(endpoint),
            serverFactory: () => ServerChatService(),
          ),
        ],
      );

      clientEndpoint = testEnv.clientEndpoint;
      serverEndpoint = testEnv.serverEndpoint;

      // Получаем конкретные реализации из мапы расширений
      clientService = testEnv.clientExtensions.get<ChatServiceContract>()
          as ClientChatService;
      serverService = testEnv.serverExtensions.get<ChatServiceContract>()
          as ServerChatService;
    });

    tearDown(() async {
      await TestFixtureUtils.tearDown(clientEndpoint, serverEndpoint);
    });

    test('двунаправленный_стриминг_обеспечивает_полноценный_обмен_сообщениями',
        () async {
      // Создаем двунаправленный канал связи
      final chatSession = clientService.chatSession();

      // Создаем список для сбора всех полученных сообщений
      final receivedMessages = <ChatMessage>[];

      // Подписываемся на входящие сообщения
      final subscription = chatSession.listen((message) {
        receivedMessages.add(message);
      });

      // Отправляем несколько сообщений
      chatSession.send(ChatMessage('Клиент', 'Привет!'));
      chatSession.send(ChatMessage('Клиент', 'Как дела?'));
      chatSession.send(ChatMessage('Клиент', 'Что нового?'));

      // Даем некоторое время на обработку
      await Future.delayed(Duration(milliseconds: 50));

      // Закрываем канал отправки
      await chatSession.close();

      // Ждем завершения получения всех сообщений
      await subscription.asFuture();
      await subscription.cancel();

      // Проверяем, что все отправленные сообщения отразились в истории сервера
      expect(serverService.messageHistory.length, equals(3));
      expect(serverService.messageHistory[0].content, equals('Привет!'));
      expect(serverService.messageHistory[1].content, equals('Как дела?'));
      expect(serverService.messageHistory[2].content, equals('Что нового?'));

      // Проверяем, что мы получили все ответы: для каждого сообщения должно быть эхо + подтверждение
      expect(receivedMessages.length, equals(6));
      expect(receivedMessages[0].sender, equals('Клиент')); // Эхо
      expect(receivedMessages[1].sender, equals('Сервер')); // Подтверждение
      expect(receivedMessages[2].sender, equals('Клиент')); // Эхо
      expect(receivedMessages[3].sender, equals('Сервер')); // Подтверждение
      expect(receivedMessages[4].sender, equals('Клиент')); // Эхо
      expect(receivedMessages[5].sender, equals('Сервер')); // Подтверждение
    });

    test('отправка_и_получение_многих_сообщений', () async {
      // Создаем двунаправленный канал связи
      final chatSession = clientService.chatSession();

      // Счетчики для проверки
      int messagesReceived = 0;

      // Подписываемся на входящие сообщения
      final subscription = chatSession.listen((_) {
        messagesReceived++;
      });

      // Отправляем много сообщений
      const totalMessages = 20;
      for (int i = 0; i < totalMessages; i++) {
        chatSession.send(
          ChatMessage('Клиент', 'Сообщение #$i'),
        );
      }

      // Даем время на обработку
      await Future.delayed(Duration(milliseconds: 100));

      // Закрываем канал отправки
      await chatSession.close();

      // Ждем завершения получения всех сообщений
      await subscription.asFuture();
      await subscription.cancel();

      // Проверяем, что сервер получил все сообщения
      expect(serverService.messageHistory.length, equals(totalMessages));

      // Проверяем, что клиент получил все ответы (эхо + подтверждение для каждого)
      expect(messagesReceived, equals(totalMessages * 2));
    });

    test('параллельная_отправка_и_получение', () async {
      // Создаем двунаправленный канал связи
      final chatSession = clientService.chatSession();

      // Отслеживаем прогресс
      final receivedMessages = <ChatMessage>[];
      final sentMessages = <ChatMessage>[];

      // Подписываемся на входящие сообщения
      final subscription = chatSession.listen((message) {
        receivedMessages.add(message);
      });

      // Функция для отправки сообщения через промежуток времени
      Future<void> sendDelayed(int index) async {
        await Future.delayed(Duration(milliseconds: 5 * index));
        final message = ChatMessage('Клиент', 'Сообщение с задержкой #$index');
        sentMessages.add(message);
        chatSession.send(message);
      }

      // Запускаем несколько параллельных отправок
      final tasks = <Future>[];
      for (int i = 0; i < 10; i++) {
        tasks.add(sendDelayed(i));
      }

      // Ждем, когда все задачи отправки будут выполнены
      await Future.wait(tasks);

      // Даем время на получение всех ответов
      await Future.delayed(Duration(milliseconds: 100));

      // Закрываем канал отправки
      await chatSession.close();

      // Ждем завершения получения всех сообщений
      await subscription.asFuture();
      await subscription.cancel();

      // Проверяем, что все отправленные сообщения дошли до сервера
      expect(serverService.messageHistory.length, equals(sentMessages.length));

      // Проверяем, что клиент получил все ответы
      expect(receivedMessages.length, equals(sentMessages.length * 2));
    });
  });
}
