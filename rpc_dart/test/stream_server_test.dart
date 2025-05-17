import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

/// Тестовое сообщение для проверки серверного стриминга
class TestMessage implements IRpcSerializableMessage {
  final String text;
  final int value;

  TestMessage({required this.text, this.value = 0});

  @override
  Map<String, dynamic> toJson() {
    return {'text': text, 'value': value};
  }

  factory TestMessage.fromJson(Map<String, dynamic> json) {
    return TestMessage(
      text: json['text'] as String,
      value: json['value'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'TestMessage(text: $text, value: $value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestMessage && other.text == text && other.value == value;
  }

  @override
  int get hashCode => text.hashCode ^ value.hashCode;
}

/// Object Mother для создания тестовых сообщений
class TestMessages {
  static TestMessage request(int id) =>
      TestMessage(text: 'Request $id', value: id);
  static TestMessage response(int id) =>
      TestMessage(text: 'Response $id', value: id * 10);
  static TestMessage error() => TestMessage(text: 'Error', value: -1);
}

/// Генераторы для создания тестовых потоков ServerStreamingBidiStream
class ServerStreamingGenerators {
  /// Создает ServerStreamingBidiStream, который генерирует несколько ответов на запрос
  static ServerStreamingBidiStream<TestMessage, TestMessage>
      createMultiResponseStream() {
    final requestController = StreamController<TestMessage>();
    final responseController = StreamController<TestMessage>();

    // Слушаем запросы и отправляем несколько ответов на один запрос
    requestController.stream.listen(
      (request) async {
        // Проверяем, не закрыт ли контроллер перед отправкой
        if (!responseController.isClosed) {
          // Отправляем серию ответов в ответ на один запрос
          for (int i = 1; i <= 3; i++) {
            if (!responseController.isClosed) {
              responseController.add(TestMessages.response(i));
              await Future.delayed(Duration(milliseconds: 5));
            } else {
              break;
            }
          }
        }
      },
      onDone: () {
        if (!responseController.isClosed) {
          responseController.close();
        }
      },
    );

    // Создаем базовый BidiStream
    final bidiStream = BidiStream<TestMessage, TestMessage>(
      responseStream: responseController.stream,
      sendFunction: (request) {
        if (!requestController.isClosed) {
          requestController.add(request);
        }
      },
      finishTransferFunction: () async {
        if (!requestController.isClosed) {
          await requestController.close();
        }
      },
      closeFunction: () async {
        if (!requestController.isClosed) await requestController.close();
        if (!responseController.isClosed) await responseController.close();
      },
    );

    // Оборачиваем в ServerStreamingBidiStream
    return ServerStreamingBidiStream<TestMessage, TestMessage>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );
  }

  /// Создает ServerStreamingBidiStream, который генерирует ответы с задержкой
  static ServerStreamingBidiStream<TestMessage, TestMessage>
      createDelayedResponseStream() {
    final requestController = StreamController<TestMessage>();
    final responseController = StreamController<TestMessage>();

    // Слушаем запросы и отправляем ответы с задержкой
    requestController.stream.listen(
      (request) async {
        // Имитируем задержку обработки
        await Future.delayed(Duration(milliseconds: 50));

        // Отправляем ответ, только если контроллер не закрыт
        if (!responseController.isClosed) {
          responseController.add(TestMessage(
            text: 'Delayed response to: ${request.text}',
            value: request.value * 10,
          ));
        }
      },
      onDone: () {
        if (!responseController.isClosed) {
          responseController.close();
        }
      },
    );

    // Создаем базовый BidiStream
    final bidiStream = BidiStream<TestMessage, TestMessage>(
      responseStream: responseController.stream,
      sendFunction: (request) {
        if (!requestController.isClosed) {
          requestController.add(request);
        }
      },
      finishTransferFunction: () async {
        if (!requestController.isClosed) {
          await requestController.close();
        }
      },
      closeFunction: () async {
        if (!requestController.isClosed) await requestController.close();
        if (!responseController.isClosed) await responseController.close();
      },
    );

    // Оборачиваем в ServerStreamingBidiStream
    return ServerStreamingBidiStream<TestMessage, TestMessage>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );
  }

  /// Создает ServerStreamingBidiStream, который генерирует ошибку
  static ServerStreamingBidiStream<TestMessage, TestMessage>
      createErrorStream() {
    final requestController = StreamController<TestMessage>();
    final responseController = StreamController<TestMessage>();

    // При получении запроса отправляем ошибку
    requestController.stream.listen(
      (request) {
        if (!responseController.isClosed) {
          // Даем немного времени для подписки на поток перед отправкой ошибки
          Future.microtask(() {
            if (!responseController.isClosed) {
              responseController.addError(Exception('Тестовая ошибка потока'));
            }
          });
        }
      },
      onDone: () {
        if (!responseController.isClosed) {
          responseController.close();
        }
      },
    );

    // Создаем базовый BidiStream
    final bidiStream = BidiStream<TestMessage, TestMessage>(
      responseStream: responseController.stream,
      sendFunction: (request) {
        if (!requestController.isClosed) {
          requestController.add(request);
        }
      },
      finishTransferFunction: () async {
        if (!requestController.isClosed) {
          await requestController.close();
        }
      },
      closeFunction: () async {
        if (!requestController.isClosed) await requestController.close();
        if (!responseController.isClosed) await responseController.close();
      },
    );

    // Оборачиваем в ServerStreamingBidiStream
    return ServerStreamingBidiStream<TestMessage, TestMessage>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );
  }
}

void main() {
  group('ServerStreamingBidiStream', () {
    test('должен получать несколько ответов на один запрос', () async {
      // Arrange
      final serverStream =
          ServerStreamingGenerators.createMultiResponseStream();

      // Список для сбора ответов
      final responses = <TestMessage>[];

      // Подписываемся на ответы
      final subscription = serverStream.listen(responses.add);

      // Act
      // Отправляем один запрос
      serverStream.sendRequest(TestMessages.request(5));

      // Ждем, пока все ответы поступят
      await Future.delayed(Duration(milliseconds: 50));
      await subscription.cancel();
      await serverStream.close();

      // Assert
      expect(responses.length, equals(3), reason: 'Должны получить 3 ответа');
      expect(responses[0].value, equals(10),
          reason: 'Первый ответ должен иметь значение 10');
      expect(responses[1].value, equals(20),
          reason: 'Второй ответ должен иметь значение 20');
      expect(responses[2].value, equals(30),
          reason: 'Третий ответ должен иметь значение 30');
    });

    test('должен корректно обрабатывать ошибки', () async {
      // Arrange
      final serverStream = ServerStreamingGenerators.createErrorStream();

      // Создаем комплитер для отслеживания ошибки
      final errorCompleter = Completer<Object>();

      // Подписываемся на поток с обработчиком ошибок
      final subscription = serverStream.listen(
        (_) {},
        onError: (error) {
          if (!errorCompleter.isCompleted) errorCompleter.complete(error);
        },
      );

      // Act
      // Отправляем запрос, который должен вызвать ошибку
      serverStream.sendRequest(TestMessages.request(1));

      // Ожидаем ошибку с таймаутом
      final error = await errorCompleter.future.timeout(
        Duration(milliseconds: 100),
        onTimeout: () => TimeoutException('Поток не выдал ошибку вовремя'),
      );

      // Очистка
      await subscription.cancel();
      await serverStream.close();

      // Assert
      expect(error.toString(), contains('Тестовая ошибка потока'));
    });

    test('не должен позволять отправлять более одного запроса', () async {
      // Arrange
      final serverStream =
          ServerStreamingGenerators.createMultiResponseStream();

      // Act & Assert
      // Первый запрос должен пройти нормально
      serverStream.sendRequest(TestMessages.request(1));

      // Второй запрос должен вызвать ошибку
      expect(
        () => serverStream.sendRequest(TestMessages.request(2)),
        throwsA(isA<RpcException>()),
      );

      // Закрываем стрим
      await serverStream.close();
    });

    test('должен корректно работать с трансформациями потока', () async {
      // Arrange
      final serverStream =
          ServerStreamingGenerators.createMultiResponseStream();
      final transformedStream = serverStream.map((response) => TestMessage(
          text: 'Transformed: ${response.text}', value: response.value * 2));

      // Список для сбора трансформированных ответов
      final responses = <TestMessage>[];

      // Подписываемся на трансформированный поток
      final subscription = transformedStream.listen(responses.add);

      // Act
      serverStream.sendRequest(TestMessages.request(1));

      // Ждем, пока все ответы поступят
      await Future.delayed(Duration(milliseconds: 50));
      await subscription.cancel();
      await serverStream.close();

      // Assert
      expect(responses.length, equals(3),
          reason: 'Должны получить 3 трансформированных ответа');
      expect(responses[0].text, contains('Transformed:'),
          reason: 'Текст должен быть трансформирован');
      expect(responses[0].value, equals(20),
          reason: 'Значение должно быть удвоено (10*2)');
      expect(responses[1].value, equals(40),
          reason: 'Значение должно быть удвоено (20*2)');
      expect(responses[2].value, equals(60),
          reason: 'Значение должно быть удвоено (30*2)');
    });

    test('должен корректно закрываться', () async {
      // Arrange
      final serverStream =
          ServerStreamingGenerators.createMultiResponseStream();
      final subscription = serverStream.listen((_) {});

      // Act
      // Отправляем запрос
      serverStream.sendRequest(TestMessages.request(1));

      // Ждем немного, чтобы быть уверенными, что обработка начнется
      await Future.delayed(Duration(milliseconds: 10));

      // Закрываем стрим
      await serverStream.close();
      await subscription.cancel();

      // Assert
      expect(serverStream.isClosed, isTrue, reason: 'Стрим должен быть закрыт');

      // Попытка отправить запрос в закрытый стрим должна вызвать ошибку
      expect(
        () => serverStream.sendRequest(TestMessages.request(2)),
        throwsA(isA<RpcException>()),
      );
    });

    test('должен обрабатывать запросы с задержкой', () async {
      // Arrange
      final serverStream =
          ServerStreamingGenerators.createDelayedResponseStream();

      // Completer для отслеживания получения ответа
      final responseCompleter = Completer<TestMessage>();

      // Подписываемся на ответы
      final subscription = serverStream.listen((response) {
        if (!responseCompleter.isCompleted) {
          responseCompleter.complete(response);
        }
      });

      // Act
      final testRequest = TestMessages.request(7);
      serverStream.sendRequest(testRequest);

      // Ждем получения ответа с таймаутом
      final response = await responseCompleter.future.timeout(
        Duration(milliseconds: 100),
        onTimeout: () => throw TimeoutException('Не получен ответ вовремя'),
      );

      // Отменяем подписку и закрываем стрим
      await subscription.cancel();
      await serverStream.close();

      // Assert
      expect(response.text, contains('Delayed response'),
          reason: 'Должен быть получен отложенный ответ');
      expect(response.value, equals(70),
          reason: 'Значение должно быть умножено на 10');
    });
  });
}
