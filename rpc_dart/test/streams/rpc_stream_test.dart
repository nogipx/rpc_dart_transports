import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

/// Тестовое сообщение для проверки RPC потоков
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
  static TestMessage simple(int id) =>
      TestMessage(text: 'Message $id', value: id);
  static TestMessage withText(String text) => TestMessage(text: text, value: 0);
  static TestMessage withValue(int value) =>
      TestMessage(text: 'Value', value: value);
  static TestMessage even(int id) =>
      TestMessage(text: 'Even $id', value: id * 2);
  static TestMessage odd(int id) =>
      TestMessage(text: 'Odd $id', value: id * 2 - 1);
}

/// Конкретная реализация RpcStream для тестирования
class TestRpcStream extends RpcStream<TestMessage, TestMessage> {
  final bool trackCloses;
  int closeCalls = 0;

  TestRpcStream({
    required Stream<TestMessage> responseStream,
    required Future<void> Function() closeFunction,
    this.trackCloses = false,
  }) : super(
          responseStream: responseStream,
          closeFunction: trackCloses
              ? () async {
                  await closeFunction();
                }
              : closeFunction,
        );

  /// Создает тестовый стрим с готовыми сообщениями
  static TestRpcStream withMessages(List<TestMessage> messages) {
    final controller = StreamController<TestMessage>();
    messages.forEach(controller.add);
    // Закрываем контроллер после добавления всех сообщений
    controller.close();

    return TestRpcStream(
      responseStream: controller.stream,
      closeFunction: () async {
        // Контроллер уже закрыт
      },
    );
  }

  /// Создает тестовый стрим с пустым потоком
  static TestRpcStream empty() {
    final controller = StreamController<TestMessage>();
    // Сразу закрываем контроллер, чтобы поток был завершен
    controller.close();

    return TestRpcStream(
      responseStream: controller.stream,
      closeFunction: () async {
        // Контроллер уже закрыт
      },
    );
  }

  /// Создает тестовый стрим с отслеживанием закрытий
  static TestRpcStream withCloseTracking() {
    final controller = StreamController<TestMessage>();

    final stream = TestRpcStream(
      responseStream: controller.stream,
      closeFunction: () async {
        await controller.close();
      },
      trackCloses: true,
    );

    return stream;
  }
}

/// Расширение для упрощения тестирования Stream с fluent API
extension StreamTestingExtensions<T> on Stream<T> {
  /// Выполняет действия над каждым элементом потока
  Future<void> forEachElement(void Function(T element) action) async {
    await for (final element in this) {
      action(element);
    }
  }

  /// Собирает первые N элементов потока
  Future<List<T>> collectFirst(int count) async {
    final result = <T>[];
    final completer = Completer<List<T>>();

    final subscription = listen((element) {
      if (result.length < count) {
        result.add(element);
        if (result.length == count) {
          completer.complete(result);
        }
      }
    }, onDone: () {
      // Если поток завершился до того, как получили нужное число элементов
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }, onError: (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
    });

    final collected = await completer.future;
    await subscription.cancel();
    return collected;
  }

  /// Проверяет, что поток содержит указанное количество элементов
  Future<void> expectLength(int expectedLength) async {
    final items = await toList();
    expect(items.length, equals(expectedLength));
  }

  /// Проверяет, что поток содержит элементы, удовлетворяющие предикату
  Future<void> expectAll(bool Function(T element) predicate) async {
    final items = await toList();
    for (final item in items) {
      expect(predicate(item), isTrue);
    }
  }
}

/// Fluent-интерфейс для асинхронного ожидания результатов
class AsyncExpect<T> {
  final Future<T> _future;

  AsyncExpect(this._future);

  Future<void> equals(T expected) async {
    final actual = await _future;
    expect(actual, equals(expected));
  }

  Future<void> isTrue() async {
    final actual = await _future;
    expect(actual, isTrue);
  }

  Future<void> isFalse() async {
    final actual = await _future;
    expect(actual, isFalse);
  }

  Future<void> hasLength(int length) async {
    final actual = await _future;
    expect(actual, hasLength(length));
  }

  Future<void> verify(void Function(T actual) verification) async {
    final actual = await _future;
    verification(actual);
  }
}

void main() {
  group('RpcStream', () {
    // Тесты базовой функциональности
    group('базовая функциональность', () {
      test('close() должен вызывать переданную closeFunction только один раз',
          () async {
        // Arrange - подготовка
        var closeCount = 0;
        // Используем простой счетчик вместо StreamController для избежания проблем с таймаутами
        final stream = TestRpcStream(
          responseStream: Stream<TestMessage>.empty(),
          closeFunction: () async {
            closeCount++;
            // Возвращаем завершенный Future без дополнительных вызовов
            return;
          },
        );

        // Act & Assert
        expect(stream.isClosed, isFalse);
        await stream.close();
        expect(stream.isClosed, isTrue);
        expect(closeCount, equals(1));

        // Повторный вызов close() не должен вызывать closeFunction снова
        await stream.close();
        expect(closeCount, equals(1));
      });
    });

    // Тесты прослушивания потока
    group('listen()', () {
      test('должен корректно передавать события от внутреннего потока',
          () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        final receivedMessages = <TestMessage>[];
        final completer = Completer<void>();

        // Act
        final subscription = stream.listen((message) {
          receivedMessages.add(message);
          if (receivedMessages.length == 2) {
            completer.complete();
          }
        });

        controller.add(TestMessages.simple(1));
        controller.add(TestMessages.simple(2));

        // Ждем получения всех сообщений
        await completer.future;

        // Assert
        expect(receivedMessages.length, equals(2));
        expect(receivedMessages[0].text, equals('Message 1'));
        expect(receivedMessages[1].text, equals('Message 2'));

        await subscription.cancel();
        await controller.close();
      });
    });

    // Тесты функциональности трансформации потока
    group('трансформации потока', () {
      test('map() должен преобразовывать элементы', () async {
        // Arrange
        final messages = [TestMessages.simple(1), TestMessages.simple(2)];
        final stream = TestRpcStream.withMessages(messages);

        // Act
        final mappedStream = stream.map((msg) =>
            TestMessage(text: 'Mapped: ${msg.text}', value: msg.value * 2));

        // Assert
        final mappedMessages = await mappedStream.toList();
        expect(mappedMessages.length, equals(2));
        expect(mappedMessages[0].text, equals('Mapped: Message 1'));
        expect(mappedMessages[0].value, equals(2));
        expect(mappedMessages[1].text, equals('Mapped: Message 2'));
        expect(mappedMessages[1].value, equals(4));
      });

      test('where() должен фильтровать элементы', () async {
        // Arrange
        final messages = [
          TestMessages.odd(1), // value = 1
          TestMessages.even(1), // value = 2
          TestMessages.odd(2), // value = 3
          TestMessages.even(2), // value = 4
        ];
        final stream = TestRpcStream.withMessages(messages);

        // Act
        final filteredStream = stream.where((msg) => msg.value % 2 == 0);

        // Assert
        final filteredMessages = await filteredStream.toList();
        expect(filteredMessages.length, equals(2));
        expect(filteredMessages[0].text, equals('Even 1'));
        expect(filteredMessages[1].text, equals('Even 2'));
      });

      test('take() должен ограничивать количество элементов', () async {
        // Arrange
        final messages = [
          TestMessages.simple(1),
          TestMessages.simple(2),
          TestMessages.simple(3),
        ];
        final stream = TestRpcStream.withMessages(messages);

        // Act
        final limitedStream = stream.take(2);

        // Assert
        final limitedMessages = await limitedStream.toList();
        expect(limitedMessages.length, equals(2));
        expect(limitedMessages[0].text, equals('Message 1'));
        expect(limitedMessages[1].text, equals('Message 2'));
      });

      test('asyncMap() должен асинхронно преобразовывать элементы', () async {
        // Arrange
        final messages = [TestMessages.simple(5)];
        final stream = TestRpcStream.withMessages(messages);

        // Act
        final mappedStream = stream.asyncMap((msg) async {
          // Используем микрозадачу вместо длительного ожидания
          await Future.microtask(() {});
          return TestMessage(text: 'Async: ${msg.text}', value: msg.value * 3);
        });

        // Assert
        final mappedMessages = await mappedStream.toList();
        expect(mappedMessages.length, equals(1));
        expect(mappedMessages[0].text, equals('Async: Message 5'));
        expect(mappedMessages[0].value, equals(15)); // 5 * 3
      });
    });

    // Тесты сбора элементов
    group('методы сбора', () {
      test('toList() должен собирать все элементы', () async {
        // Arrange
        final messages = [
          TestMessages.simple(1),
          TestMessages.simple(2),
        ];
        final stream = TestRpcStream.withMessages(messages);

        // Act & Assert
        final list = await stream.toList();
        expect(list.length, equals(2));
        expect(list[0], equals(messages[0]));
        expect(list[1], equals(messages[1]));
      });

      test('first должен возвращать первый элемент', () async {
        // Arrange
        final messages = [
          TestMessages.withText('First'),
          TestMessages.withText('Second'),
        ];
        final stream = TestRpcStream.withMessages(messages);

        // Act & Assert
        final first = await stream.first;
        expect(first.text, equals('First'));
      });
    });

    // Тест для широковещания
    test('asBroadcastStream() должен создавать широковещательный поток',
        () async {
      // Arrange
      final controller = StreamController<TestMessage>();
      final stream = TestRpcStream(
        responseStream: controller.stream,
        closeFunction: () => controller.close(),
      );

      // Act
      final broadcastStream = stream.asBroadcastStream();

      // Assert - используем fluent API для проверок
      expect(broadcastStream.isBroadcast, isTrue);

      // Подписываемся несколько раз на broadcast поток
      final results1 = <TestMessage>[];
      final results2 = <TestMessage>[];

      final subscription1 = broadcastStream.listen(results1.add);
      final subscription2 = broadcastStream.listen(results2.add);

      // Отправляем события
      controller.add(TestMessages.simple(1));
      controller.add(TestMessages.simple(2));

      // Ждем обработки событий, используя микрозадачи
      await Future.microtask(() {});
      await Future.microtask(() {});

      // Проверяем, что оба подписчика получили все сообщения
      expect(results1.length, equals(2));
      expect(results2.length, equals(2));

      await subscription1.cancel();
      await subscription2.cancel();
      await controller.close();
    });

    // Тесты для крайних случаев
    group('крайние случаи', () {
      test('должен корректно обрабатывать ошибки в потоке', () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        // Act - запускаем поток с ошибкой
        final receivedErrors = <Object>[];
        final subscription = stream.listen(
          (_) {},
          onError: receivedErrors.add,
        );

        // Добавляем ошибку в поток
        controller.addError('Тестовая ошибка');
        await Future.microtask(() {});

        // Assert
        expect(receivedErrors.length, equals(1));
        expect(receivedErrors.first, equals('Тестовая ошибка'));

        await subscription.cancel();
        await controller.close();
      });

      test('должен корректно обрабатывать завершение потока', () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        // Добавляем слушателя и флаг завершения
        var isDone = false;
        final subscription = stream.listen(
          (_) {},
          onDone: () => isDone = true,
        );

        // Act - закрываем контроллер
        await controller.close();
        await Future.microtask(() {});

        // Assert
        expect(isDone, isTrue);
        await subscription.cancel();
      });

      test('должен корректно работать с пустым потоком', () async {
        // Arrange
        final stream = TestRpcStream.empty();

        // Act & Assert
        final messages = await stream.toList();
        expect(messages, isEmpty);

        // Проверяем, что first выбрасывает ошибку на пустом потоке
        expect(
          () => stream.first,
          throwsStateError,
        );
      });

      test('close() должен быть безопасен при многократном вызове', () async {
        // Arrange
        var closeCalls = 0;
        final stream = TestRpcStream(
          responseStream: Stream<TestMessage>.empty(),
          closeFunction: () async {
            closeCalls++;
          },
        );

        // Act - вызываем close несколько раз параллельно
        await Future.wait([
          stream.close(),
          stream.close(),
          stream.close(),
        ]);

        // Assert
        expect(closeCalls, equals(1));
        expect(stream.isClosed, isTrue);
      });

      test('должен корректно работать с отменой подписки', () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        final receivedMessages = <TestMessage>[];

        // Act
        final subscription = stream.listen(receivedMessages.add);

        // Отправляем сообщение
        controller.add(TestMessages.simple(1));
        await Future.microtask(() {});

        // Отменяем подписку
        await subscription.cancel();

        // Отправляем еще одно сообщение (не должно быть получено)
        controller.add(TestMessages.simple(2));
        await Future.microtask(() {});

        // Assert
        expect(receivedMessages.length, equals(1));
        expect(receivedMessages[0].text, equals('Message 1'));

        await controller.close();
      });

      test('должен корректно работать с паузой и возобновлением', () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        final receivedMessages = <TestMessage>[];

        // Act
        final subscription = stream.listen(receivedMessages.add);

        // Отправляем первое сообщение
        controller.add(TestMessages.simple(1));
        await Future.microtask(() {});

        // Приостанавливаем подписку
        subscription.pause();

        // Отправляем второе сообщение (должно буферизоваться)
        controller.add(TestMessages.simple(2));
        await Future.microtask(() {});

        // Проверяем, что получено только первое сообщение
        expect(receivedMessages.length, equals(1));

        // Возобновляем подписку
        subscription.resume();
        await Future.microtask(() {});

        // Assert
        expect(receivedMessages.length, equals(2));
        expect(receivedMessages[0].text, equals('Message 1'));
        expect(receivedMessages[1].text, equals('Message 2'));

        await subscription.cancel();
        await controller.close();
      });

      test('должен корректно обрабатывать исключения внутри трансформаций',
          () async {
        // Arrange
        final messages = [TestMessages.simple(1), TestMessages.simple(2)];
        final stream = TestRpcStream.withMessages(messages);

        // Act - создаем трансформацию, которая выбрасывает исключение
        final transformedStream = stream.map((msg) {
          if (msg.value == 2) {
            throw Exception('Ошибка при обработке Message 2');
          }
          return TestMessage(
              text: 'Transformed: ${msg.text}', value: msg.value);
        });

        // Собираем результаты и ошибки
        final results = <TestMessage>[];
        final errors = <Object>[];
        final completer = Completer<void>();

        // Assert
        final subscription = transformedStream.listen(
          (message) {
            results.add(message);
            print('Получено сообщение: $message');
          },
          onError: (error) {
            errors.add(error);
            print('Получена ошибка: $error');
            completer.complete(); // Завершаем тест при получении ошибки
          },
          onDone: () {
            print('Поток завершен');
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        // Ждем завершения потока или получения ошибки
        await completer.future;

        // Дополнительная синхронизация для уверенности
        await Future.microtask(() {});

        // Проверяем результаты
        expect(results.length, equals(1),
            reason: 'Должно быть получено ровно 1 сообщение');
        expect(results[0].text, equals('Transformed: Message 1'));

        // Проверяем ошибки
        expect(errors.length, equals(1),
            reason: 'Должна быть получена ровно 1 ошибка: $errors');
        expect(errors[0], isA<Exception>());
        expect((errors[0] as Exception).toString(),
            contains('Ошибка при обработке Message 2'));

        await subscription.cancel();
      });
    });
  });
}
