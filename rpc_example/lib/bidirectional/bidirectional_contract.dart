import 'dart:async';
import 'dart:math';

import 'package:rpc_dart/rpc_dart.dart';

import 'bidirectional.dart';
import 'bidirectional_models.dart';

/// Абстрактный контракт чат-сервиса
abstract base class ChatServiceContract extends RpcServiceContract {
  ChatServiceContract() : super('ChatService');

  @override
  void setup() {
    // Использую метод из контракта напрямую
    addBidirectionalStreamingMethod<ChatMessage, ChatMessage>(
      methodName: chatMethod,
      // Обертываем метод, чтобы он не принимал никаких параметров
      handler: chatHandler,
      argumentParser: ChatMessage.fromJson,
      responseParser: ChatMessage.fromJson,
    );

    super.setup();
  }

  /// Обработчик сообщений чата - не принимает никаких параметров,
  /// так как двунаправленный стрим начинается без начального сообщения
  BidiStream<ChatMessage, ChatMessage> chatHandler();
}

/// Серверная реализация ChatService
final class ServerChatService extends ChatServiceContract {
  @override
  BidiStream<ChatMessage, ChatMessage> chatHandler() =>
      BidiStreamGenerator<ChatMessage, ChatMessage>((incomingRequests) async* {
        // Имитируем присоединение пользователя к чату
        yield ChatMessage(
          sender: 'Система',
          text: 'Подключение установлено, добро пожаловать в чат!',
          type: MessageType.system,
          timestamp: DateTime.now().toIso8601String(),
        );

        // Список имен для чат-бота
        final List<String> botNames = [
          'Алиса',
          'Бот',
          'Консультант',
          'Помощник',
        ];
        final Random random = Random();
        final botName = botNames[random.nextInt(botNames.length)];

        // Добавляем сообщение о подключении бота
        yield ChatMessage(
          sender: 'Система',
          text: '$botName присоединился к чату',
          type: MessageType.info,
          timestamp: DateTime.now().toIso8601String(),
        );

        // Базовые ответы для чат-бота
        final responses = {
          'привет': ['Привет!', 'Здравствуйте!', 'Добрый день!'],
          'как дела': [
            'Отлично, спасибо!',
            'Всё хорошо, а у вас?',
            'Прекрасно!',
          ],
          'пока': ['До свидания!', 'Пока!', 'До встречи!'],
          'помощь': [
            'Чем могу помочь?',
            'Я к вашим услугам',
            'Задайте ваш вопрос',
          ],
          'время': [
            'Сейчас ${DateTime.now().hour}:${DateTime.now().minute}',
            'Текущее время: ${DateTime.now().toIso8601String().substring(11, 16)}',
          ],
        };

        // Задержка печати
        final typingDelay = Duration(milliseconds: 500);

        // Обрабатываем входящие сообщения
        await for (final message in incomingRequests) {
          final text = message.text.toLowerCase();
          if (text.isEmpty) continue;

          // Имитация задержки печати
          yield ChatMessage(
            sender: botName,
            text: '...',
            type: MessageType.action,
            timestamp: DateTime.now().toIso8601String(),
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
          yield ChatMessage(
            sender: botName,
            text: response,
            type: MessageType.text,
            timestamp: DateTime.now().toIso8601String(),
          );
        }
      }).create();
}

/// Клиентская реализация ChatService
final class ClientChatService extends ChatServiceContract {
  final RpcEndpoint _endpoint;

  ClientChatService(this._endpoint);

  @override
  BidiStream<ChatMessage, ChatMessage> chatHandler() {
    return _endpoint
        .bidirectionalStreaming(
          serviceName: serviceName,
          methodName: chatMethod,
        )
        .call<ChatMessage, ChatMessage>(responseParser: ChatMessage.fromJson);
  }
}
