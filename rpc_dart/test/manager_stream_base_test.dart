import 'dart:async';

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';

// Тестовое сообщение
class SimpleMessage extends IRpcSerializableMessage {
  final String text;

  SimpleMessage(this.text);

  @override
  Map<String, dynamic> toJson() => {'text': text};

  static SimpleMessage fromJson(Map<String, dynamic> json) =>
      SimpleMessage(json['text'] as String);
}

void main() {
  group('Базовые тесты стрим-менеджеров', () {
    test('BidirectionalStreamsManager: базовый тест без стримов', () async {
      // Самый простой тест - просто создаем и уничтожаем менеджер
      final manager =
          BidirectionalStreamsManager<SimpleMessage, SimpleMessage>();
      expect(manager, isNotNull);
      expect(manager.activeClientCount, equals(0));

      await manager.dispose();
    });

    test('ServerStreamsManager: базовый тест без стримов', () async {
      // Самый простой тест - просто создаем и уничтожаем менеджер
      final manager = ServerStreamsManager<SimpleMessage>();
      expect(manager, isNotNull);
      expect(manager.activeClientCount, equals(0));

      await manager.dispose();
    });

    test('BidirectionalStreamsManager: простая публикация и получение',
        () async {
      final manager =
          BidirectionalStreamsManager<SimpleMessage, SimpleMessage>();

      try {
        // Создаем стрим
        final stream = manager.createClientBidiStream();

        // Подписываемся на получение сообщений
        final messages = <SimpleMessage>[];
        final completer = Completer<void>();

        final subscription = stream.listen((message) {
          messages.add(message);
          if (!completer.isCompleted) {
            completer.complete();
          }
        });

        // Отправляем сообщение
        manager.publishResponse(SimpleMessage('Тестовое сообщение'));

        // Ждем получения сообщения с таймаутом
        await completer.future.timeout(
          Duration(milliseconds: 500),
          onTimeout: () {
            print('Таймаут ожидания сообщения');
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        // Проверяем, что сообщение было получено
        expect(messages.length, equals(1));
        expect(messages.first.text, equals('Тестовое сообщение'));

        // Очищаем ресурсы
        await subscription.cancel();
        await Future.delayed(
            Duration(milliseconds: 10)); // Даем время на завершение
      } finally {
        // Закрываем менеджер в любом случае
        await manager.dispose();
        await Future.delayed(
            Duration(milliseconds: 10)); // Даем время на завершение
      }
    });

    test('ServerStreamsManager: простая публикация и получение', () async {
      final manager = ServerStreamsManager<SimpleMessage>();

      try {
        // Создаем стрим
        final stream = manager.createClientStream<SimpleMessage>();

        // Подписываемся на получение сообщений
        final messages = <SimpleMessage>[];
        final completer = Completer<void>();

        final subscription = stream.listen((message) {
          messages.add(message);
          if (!completer.isCompleted) {
            completer.complete();
          }
        });

        // Отправляем сообщение
        manager.publish(SimpleMessage('Тестовое сообщение'));

        // Ждем получения сообщения с таймаутом
        await completer.future.timeout(
          Duration(milliseconds: 500),
          onTimeout: () {
            print('Таймаут ожидания сообщения');
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        // Проверяем, что сообщение было получено
        expect(messages.length, equals(1));
        expect(messages.first.text, equals('Тестовое сообщение'));

        // Очищаем ресурсы
        await subscription.cancel();
        await Future.delayed(
            Duration(milliseconds: 10)); // Даем время на завершение
      } finally {
        // Закрываем менеджер в любом случае
        await manager.dispose();
        await Future.delayed(
            Duration(milliseconds: 10)); // Даем время на завершение
      }
    });
  });
}
