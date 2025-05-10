import 'dart:async';
import 'dart:math';

import 'package:rpc_dart/rpc_dart.dart';

import 'bidirectional.dart';
import 'bidirectional_models.dart';

/// Абстрактный контракт чат-сервиса
abstract base class ChatServiceContract extends RpcServiceContract {
  @override
  String get serviceName => 'ChatService';

  @override
  void setup() {
    // Регистрируем метод для чата
    addBidirectionalStreamingMethod<ChatMessage, ChatMessage>(
      methodName: chatMethod,
      handler: chatHandler,
      argumentParser: ChatMessage.fromJson,
      responseParser: ChatMessage.fromJson,
    );
  }

  /// Обработчик сообщений чата
  Stream<ChatMessage> chatHandler(
    Stream<ChatMessage> requests,
    String messageId,
  );
}

/// Серверная реализация ChatService
final class ServerChatService extends ChatServiceContract {
  @override
  Stream<ChatMessage> chatHandler(
    Stream<ChatMessage> requests,
    String messageId,
  ) {
    // Реализация метода для чата с обработкой сообщений и автоматическими ответами
    final controller = StreamController<ChatMessage>();

    // Имитируем присоединение пользователя к чату
    controller.add(
      ChatMessage(
        sender: 'Система',
        text: 'Подключение установлено, добро пожаловать в чат!',
        type: MessageType.system,
        timestamp: DateTime.now().toIso8601String(),
      ),
    );

    // Список имен для чат-бота
    final List<String> botNames = ['Алиса', 'Бот', 'Консультант', 'Помощник'];
    final Random random = Random();
    final botName = botNames[random.nextInt(botNames.length)];

    // Добавляем сообщение о подключении бота
    controller.add(
      ChatMessage(
        sender: 'Система',
        text: '$botName присоединился к чату',
        type: MessageType.info,
        timestamp: DateTime.now().toIso8601String(),
      ),
    );

    // Базовые ответы для чат-бота
    final responses = {
      'привет': ['Привет!', 'Здравствуйте!', 'Добрый день!'],
      'как дела': ['Отлично, спасибо!', 'Всё хорошо, а у вас?', 'Прекрасно!'],
      'пока': ['До свидания!', 'Пока!', 'До встречи!'],
      'помощь': ['Чем могу помочь?', 'Я к вашим услугам', 'Задайте ваш вопрос'],
      'время': [
        'Сейчас ${DateTime.now().hour}:${DateTime.now().minute}',
        'Текущее время: ${DateTime.now().toIso8601String().substring(11, 16)}',
      ],
    };

    // Задержка печати
    final typingDelay = Duration(milliseconds: 500);

    // Подписываемся на входящие сообщения от клиента
    requests.listen(
      (message) async {
        // Получено новое сообщение
        final text = message.text.toLowerCase();

        if (text.isEmpty) return;

        // Имитация задержки печати
        controller.add(
          ChatMessage(
            sender: botName,
            text: '...',
            type: MessageType.action,
            timestamp: DateTime.now().toIso8601String(),
          ),
        );

        // Задержка перед ответом
        await Future.delayed(typingDelay);

        // Поиск подходящего ответа
        String response = 'Извините, не понимаю вас.';

        for (final key in responses.keys) {
          if (text.contains(key)) {
            final options = responses[key]!;
            response = options[random.nextInt(options.length)];
            break;
          }
        }

        // Отправляем ответ
        controller.add(
          ChatMessage(
            sender: botName,
            text: response,
            type: MessageType.text,
            timestamp: DateTime.now().toIso8601String(),
          ),
        );
      },
      onError: (e) {
        print('Ошибка в обработчике чата: $e');
        controller.addError(e);
      },
      onDone: () {
        // Пользователь покинул чат
        controller.add(
          ChatMessage(
            sender: 'Система',
            text: 'Соединение закрыто',
            type: MessageType.info,
            timestamp: DateTime.now().toIso8601String(),
          ),
        );

        controller.close();
      },
    );

    return controller.stream;
  }
}

/// Клиентская реализация ChatService
final class ClientChatService extends ChatServiceContract {
  final RpcEndpoint _endpoint;

  ClientChatService(this._endpoint);

  @override
  Stream<ChatMessage> chatHandler(
    Stream<ChatMessage> requests,
    String messageId,
  ) {
    throw UnimplementedError('Клиентской реализации не требуется обработчик');
  }

  /// Открывает двунаправленный канал связи для чата
  Future<BidirectionalChannel<ChatMessage, ChatMessage>> chat() async {
    return _endpoint
        .bidirectional(serviceName, chatMethod)
        .createChannel<ChatMessage, ChatMessage>(
          responseParser: ChatMessage.fromJson,
        );
  }
}
