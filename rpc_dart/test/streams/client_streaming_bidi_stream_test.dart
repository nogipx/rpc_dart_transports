import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

/// Тестовое сообщение для проверки клиентского стриминга
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
      TestMessage(text: 'Response $id', value: id);
  static TestMessage sumResponse(List<int> values) =>
      TestMessage(text: 'Sum Response', value: values.fold(0, (a, b) => a + b));
  static TestMessage error() => TestMessage(text: 'Error', value: -1);
}

/// Генераторы для создания тестовых BidiStream
class StreamGenerators {
  /// Создает BidiStream, который отвечает суммой всех полученных запросов
  static BidiStream<TestMessage, TestMessage> createSumStream() {
    // Используем контроллеры для большего контроля над потоком
    final requestController = StreamController<TestMessage>();
    final responseController = StreamController<TestMessage>();

    // Собираем запросы для суммирования
    final receivedValues = <int>[];

    // Подписываемся на запросы
    requestController.stream.listen(
      (request) {
        receivedValues.add(request.value);

        // Если накопилось 3 запроса, отправляем ответ с суммой
        if (receivedValues.length >= 3) {
          responseController.add(TestMessages.sumResponse(receivedValues));
        }
      },
      onDone: () {
        // Если запросы закончились, а их было меньше 3, все равно отправляем ответ
        if (receivedValues.isNotEmpty && receivedValues.length < 3) {
          responseController.add(TestMessages.sumResponse(receivedValues));
        }
        // Закрываем поток ответов
        responseController.close();
      },
    );

    // Создаем BidiStream с контроллерами
    return BidiStream<TestMessage, TestMessage>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      finishTransferFunction: () => requestController.close(),
      closeFunction: () async {
        if (!requestController.isClosed) await requestController.close();
        if (!responseController.isClosed) await responseController.close();
      },
    );
  }

  /// Создает BidiStream, который отвечает с ошибкой
  static BidiStream<TestMessage, TestMessage> createErrorStream() {
    final requestController = StreamController<TestMessage>();
    final responseController = StreamController<TestMessage>();

    // При получении первого запроса отправляем ошибку
    requestController.stream.listen(
      (request) {
        responseController.addError(Exception('Тестовая ошибка потока'));
      },
      onDone: () {
        if (!responseController.isClosed) {
          responseController.close();
        }
      },
    );

    return BidiStream<TestMessage, TestMessage>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      finishTransferFunction: () => requestController.close(),
      closeFunction: () async {
        if (!requestController.isClosed) await requestController.close();
        if (!responseController.isClosed) await responseController.close();
      },
    );
  }

  /// Создает BidiStream, который не отвечает (пустой поток)
  static BidiStream<TestMessage, TestMessage> createEmptyStream() {
    final requestController = StreamController<TestMessage>();
    final responseController = StreamController<TestMessage>();

    // Просто слушаем запросы, но не отправляем ответы
    requestController.stream.listen(
      (_) {},
      onDone: () => responseController.close(),
    );

    return BidiStream<TestMessage, TestMessage>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      finishTransferFunction: () => requestController.close(),
      closeFunction: () async {
        if (!requestController.isClosed) await requestController.close();
        if (!responseController.isClosed) await responseController.close();
      },
    );
  }

  /// Создает BidiStream с задержкой ответа
  static BidiStream<TestMessage, TestMessage> createDelayedStream() {
    final requestController = StreamController<TestMessage>();
    final responseController = StreamController<TestMessage>();

    // Собираем значения для суммирования
    final values = <int>[];

    // При получении запросов накапливаем значения
    requestController.stream.listen(
      (request) {
        values.add(request.value);
      },
      onDone: () async {
        // Небольшая задержка перед отправкой ответа
        await Future.delayed(Duration(milliseconds: 10));
        if (!responseController.isClosed) {
          responseController.add(TestMessage(
            text: 'Delayed Response',
            value: values.fold(0, (a, b) => a + b),
          ));
          responseController.close();
        }
      },
    );

    return BidiStream<TestMessage, TestMessage>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      finishTransferFunction: () => requestController.close(),
      closeFunction: () async {
        if (!requestController.isClosed) await requestController.close();
        if (!responseController.isClosed) await responseController.close();
      },
    );
  }

  /// Создает BidiStream, который отправляет несколько ответов
  static BidiStream<TestMessage, TestMessage> createMultiResponseStream() {
    final requestController = StreamController<TestMessage>();
    final responseController = StreamController<TestMessage>();

    // При получении запроса отправляем несколько ответов
    requestController.stream.listen(
      (request) async {
        // Отправляем несколько ответов сразу
        responseController.add(TestMessages.response(1));
        await Future.microtask(() {});
        responseController.add(TestMessages.response(2));
        await Future.microtask(() {});
        responseController.add(TestMessages.response(3));
      },
      onDone: () {
        responseController.close();
      },
    );

    return BidiStream<TestMessage, TestMessage>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      finishTransferFunction: () => requestController.close(),
      closeFunction: () async {
        if (!requestController.isClosed) await requestController.close();
        if (!responseController.isClosed) await responseController.close();
      },
    );
  }
}

void main() {
  group('ClientStreamingBidiStream', () {
    test('должен корректно отправлять запросы и получать один ответ', () async {
      // Arrange - создаем BidiStream с функцией-генератором для суммирования
      final bidiStream = StreamGenerators.createSumStream();

      // Создаем ClientStreamingBidiStream на основе BidiStream
      final clientStream = bidiStream.toClientStreaming();

      // Act - отправляем несколько запросов
      clientStream.send(TestMessages.request(1));
      clientStream.send(TestMessages.request(2));
      clientStream.send(TestMessages.request(3));

      // Завершаем отправку
      await clientStream.finishSending();

      // Ожидаем ответ
      final response = await clientStream.getResponse();

      // Assert
      expect(response.text, equals('Sum Response'));
      expect(response.value, equals(6)); // 1 + 2 + 3

      // Закрываем стрим
      await clientStream.close();
    });

    test('должен корректно обрабатывать ошибки в потоке', () async {
      // Arrange
      final bidiStream = StreamGenerators.createErrorStream();
      final clientStream = bidiStream.toClientStreaming();

      // Act
      clientStream.send(TestMessages.request(1));

      // Assert - проверяем, что getResponse() выбрасывает ошибку
      await expectLater(
        clientStream.getResponse(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'error message',
          contains('Тестовая ошибка потока'),
        )),
      );

      await clientStream.close();
    });

    test('должен выбрасывать исключение, если поток завершился без ответа',
        () async {
      // Arrange
      final bidiStream = StreamGenerators.createEmptyStream();
      final clientStream = bidiStream.toClientStreaming();

      // Act
      clientStream.send(TestMessages.request(1));
      clientStream.send(TestMessages.request(2));
      await clientStream.finishSending();

      // Закрываем базовый поток
      await bidiStream.close();

      // Assert
      await expectLater(
        clientStream.getResponse(),
        throwsA(isA<RpcUnsupportedOperationException>().having(
          (e) => e.details!['message'],
          'error message',
          'Поток завершился без ответа',
        )),
      );
    });

    test('должен обрабатывать задержки в ответах', () async {
      // Arrange
      final bidiStream = StreamGenerators.createDelayedStream();
      final clientStream = bidiStream.toClientStreaming();

      // Act
      clientStream.send(TestMessages.request(5));
      clientStream.send(TestMessages.request(10));

      // Завершаем отправку
      await clientStream.finishSending();

      // Ожидаем ответ с небольшим таймаутом
      final response = await clientStream
          .getResponse()
          .timeout(Duration(seconds: 1), onTimeout: () {
        return TestMessage(text: 'Timeout', value: -1);
      });

      // Assert
      expect(response.text, equals('Delayed Response'));
      expect(response.value, equals(15)); // 5 + 10

      await clientStream.close();
    });

    test('должен игнорировать повторные ответы', () async {
      // Arrange
      final bidiStream = StreamGenerators.createMultiResponseStream();
      final clientStream = bidiStream.toClientStreaming();

      // Act
      clientStream.send(TestMessages.request(1));

      // Ждем первый ответ
      final response = await clientStream.getResponse();

      // Assert - должен быть только первый ответ
      expect(response.text, equals('Response 1'));
      expect(response.value, equals(1));

      // Даем время обработать остальные ответы
      await Future.delayed(Duration(milliseconds: 10));

      await clientStream.close();
    });

    test('метод close() должен корректно закрывать поток', () async {
      // Arrange
      final bidiStream = StreamGenerators.createSumStream();
      final clientStream = bidiStream.toClientStreaming();

      // Отправляем сообщение, чтобы поток был "живым"
      clientStream.send(TestMessages.request(1));

      // Act
      await clientStream.close();

      // Assert - проверяем, что поток закрыт
      expect(clientStream.isClosed, isTrue);
    });
  });
}
