import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

/// Тестовое сообщение для проверки RPC потоков
class TestMessage extends IRpcSerializableMessage {
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
        final completer = Completer<void>();

        // Act
        final subscription = stream.listen((message) {
          receivedMessages.add(message);
          print('Получено сообщение: $message');
          if (receivedMessages.length >= 5) {
            completer.complete();
          }
        });

        // Отправляем первое сообщение
        controller.add(TestMessages.simple(1));
        // Ждем обработки сообщения
        await Future.microtask(() {});
        await Future.microtask(() {});

        // Проверяем количество полученных сообщений
        expect(receivedMessages.length, equals(1));

        // Приостанавливаем подписку
        subscription.pause();
        print('Подписка приостановлена');

        // Отправляем еще сообщения, которые должны буферизоваться
        controller.add(TestMessages.simple(2));
        controller.add(TestMessages.simple(3));
        controller.add(TestMessages.simple(4));
        controller.add(TestMessages.simple(5));

        // Даем время на обработку (но они не должны обрабатываться, т.к. подписка приостановлена)
        await Future.microtask(() {});
        await Future.microtask(() {});

        // Проверяем, что количество полученных сообщений не изменилось
        expect(receivedMessages.length, equals(1),
            reason:
                'Сообщения не должны обрабатываться при приостановленной подписке');

        // Возобновляем подписку
        print('Подписка возобновлена');
        subscription.resume();

        // Ждем получения всех сообщений
        await completer.future;

        // Assert
        expect(receivedMessages.length, equals(5));
        for (var i = 0; i < 5; i++) {
          expect(receivedMessages[i].value, equals(i + 1));
        }

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

    // Тесты для проверки timeout()
    group('timeout()', () {
      test(
          'должен выбрасывать TimeoutException при превышении времени ожидания',
          () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        // Act
        final timeoutStream = stream.timeout(Duration(milliseconds: 50));

        // Собираем ошибки
        final errors = <Object>[];
        final completer = Completer<void>();

        timeoutStream.listen(
          (_) {},
          onError: (e) {
            errors.add(e);
            completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

        // Ждем таймаут
        await completer.future;

        // Assert
        expect(errors.length, equals(1));
        expect(errors.first, isA<TimeoutException>());

        await controller.close();
      });

      test('должен использовать onTimeout для обработки таймаута', () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        final fallbackMessage = TestMessages.withText('Таймаут');
        final receivedMessages = <TestMessage>[];
        final completer = Completer<void>();

        // Act
        final timeoutStream = stream.timeout(
          Duration(milliseconds: 50),
          onTimeout: (sink) {
            sink.add(fallbackMessage);
            sink.close();
          },
        );

        timeoutStream.listen(
          (msg) {
            receivedMessages.add(msg);
            completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

        // Ждем сообщения о таймауте
        await completer.future;

        // Assert
        expect(receivedMessages.length, equals(1));
        expect(receivedMessages.first, equals(fallbackMessage));

        await controller.close();
      });
    });

    // Тесты для проверки обработки backpressure
    group('backpressure', () {
      test('должен корректно буферизовать события при паузе подписки',
          () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        final receivedMessages = <TestMessage>[];

        // Создаем подписку, которую будем тестировать
        final subscription = stream.listen((message) {
          receivedMessages.add(message);
          print('Получено сообщение: $message');
        });

        // Отправляем первое сообщение
        controller.add(TestMessages.simple(1));

        // Ждем обработки первого сообщения
        await Future.delayed(Duration(milliseconds: 50));

        // Проверяем, что первое сообщение получено
        expect(receivedMessages.length, equals(1));

        // Приостанавливаем подписку
        subscription.pause();
        print('Подписка приостановлена');

        // Отправляем еще сообщения во время паузы
        controller.add(TestMessages.simple(2));
        await Future.delayed(Duration(milliseconds: 20));
        controller.add(TestMessages.simple(3));
        await Future.delayed(Duration(milliseconds: 20));

        // Проверяем, что новых сообщений не получено
        expect(receivedMessages.length, equals(1),
            reason: 'Не должно быть получено новых сообщений во время паузы');

        // Возобновляем подписку
        print('Подписка возобновлена');
        subscription.resume();

        // Ждем обработки буферизованных сообщений
        await Future.delayed(Duration(milliseconds: 50));

        // Assert - должны получить все 3 сообщения
        expect(receivedMessages.length, equals(3));
        expect(receivedMessages[0].value, equals(1));
        expect(receivedMessages[1].value, equals(2));
        expect(receivedMessages[2].value, equals(3));

        await subscription.cancel();
        await controller.close();
      });

      test('должен обрабатывать большой объем данных без потери сообщений',
          () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        const messageCount = 1000;
        final receivedMessages = <TestMessage>[];
        final completer = Completer<void>();

        // Act - подписываемся на поток
        final subscription = stream.listen((message) {
          receivedMessages.add(message);
          if (receivedMessages.length == messageCount) {
            completer.complete();
          }
        });

        // Генерируем большое количество сообщений
        for (var i = 0; i < messageCount; i++) {
          controller.add(TestMessages.simple(i));

          // Периодически даем время обработать сообщения
          if (i % 100 == 0) {
            await Future.microtask(() {});
          }
        }

        // Ждем обработки всех сообщений
        await completer.future;

        // Assert
        expect(receivedMessages.length, equals(messageCount));

        // Проверяем, что все сообщения получены в правильном порядке
        for (var i = 0; i < messageCount; i++) {
          expect(receivedMessages[i].value, equals(i));
        }

        await subscription.cancel();
        await controller.close();
      });
    });

    // Тесты для проверки трансформеров потоков
    group('transform()', () {
      test('должен корректно применять StreamTransformer', () async {
        // Arrange
        final messages = [TestMessages.simple(1), TestMessages.simple(2)];
        final stream = TestRpcStream.withMessages(messages);

        // Создаем трансформер, который удваивает значение каждого сообщения
        final transformer =
            StreamTransformer<TestMessage, TestMessage>.fromHandlers(
          handleData: (data, sink) {
            sink.add(TestMessage(
              text: 'Transformed: ${data.text}',
              value: data.value * 2,
            ));
          },
        );

        // Act
        final transformedStream = stream.transform(transformer);

        // Assert
        final results = await transformedStream.toList();
        expect(results.length, equals(2));
        expect(results[0].text, equals('Transformed: Message 1'));
        expect(results[0].value, equals(2));
        expect(results[1].text, equals('Transformed: Message 2'));
        expect(results[1].value, equals(4));
      });

      test('должен корректно объединять несколько трансформеров в цепочку',
          () async {
        // Arrange
        final messages = [TestMessages.simple(1), TestMessages.simple(2)];
        final stream = TestRpcStream.withMessages(messages);

        // Создаем трансформер для удвоения значения
        final doubleTransformer =
            StreamTransformer<TestMessage, TestMessage>.fromHandlers(
          handleData: (data, sink) {
            sink.add(TestMessage(
              text: data.text,
              value: data.value * 2,
            ));
          },
        );

        // Создаем трансформер для префикса текста
        final prefixTransformer =
            StreamTransformer<TestMessage, TestMessage>.fromHandlers(
          handleData: (data, sink) {
            sink.add(TestMessage(
              text: 'Prefix: ${data.text}',
              value: data.value,
            ));
          },
        );

        // Создаем трансформер для фильтрации сообщений с четными значениями
        final filterTransformer =
            StreamTransformer<TestMessage, TestMessage>.fromHandlers(
          handleData: (data, sink) {
            if (data.value % 2 == 0) {
              sink.add(data);
            }
          },
        );

        // Act - применяем цепочку трансформеров
        final transformedStream = stream
            .transform(doubleTransformer)
            .transform(prefixTransformer)
            .transform(filterTransformer);

        // Assert
        final results = await transformedStream.toList();
        expect(results.length,
            equals(2)); // оба значения после удвоения становятся четными
        expect(results[0].text, equals('Prefix: Message 1'));
        expect(results[0].value, equals(2));
        expect(results[1].text, equals('Prefix: Message 2'));
        expect(results[1].value, equals(4));
      });

      test('должен передавать ошибки через цепочку трансформеров', () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        // Создаем трансформер, который просто пропускает данные и ошибки
        final passTransformer =
            StreamTransformer<TestMessage, TestMessage>.fromHandlers(
          handleData: (data, sink) => sink.add(data),
          handleError: (error, stackTrace, sink) =>
              sink.addError(error, stackTrace),
        );

        // Собираем ошибки
        final errors = <Object>[];
        final completer = Completer<void>();

        // Act
        final transformedStream = stream.transform(passTransformer);
        transformedStream.listen(
          (_) {},
          onError: (e) {
            errors.add(e);
            completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

        // Добавляем ошибку
        controller.addError('Тестовая ошибка в трансформере');

        // Ждем обработки ошибки
        await completer.future;

        // Assert
        expect(errors.length, equals(1));
        expect(errors.first, equals('Тестовая ошибка в трансформере'));

        await controller.close();
      });
    });

    // Тесты для методов агрегации данных
    group('методы агрегации', () {
      test('fold() должен корректно накапливать результаты', () async {
        // Arrange
        final messages = List.generate(5, (i) => TestMessages.simple(i + 1));
        final stream = TestRpcStream.withMessages(messages);

        // Act - используем fold для суммирования значений
        final sum = await stream.fold<int>(
          0,
          (previous, element) => previous + element.value,
        );

        // Assert
        // 1 + 2 + 3 + 4 + 5 = 15
        expect(sum, equals(15));
      });

      test('reduce() должен корректно объединять элементы', () async {
        // Arrange
        final messages = List.generate(5, (i) => TestMessages.simple(i + 1));
        final stream = TestRpcStream.withMessages(messages);

        // Act - используем reduce для нахождения сообщения с максимальным значением
        final maxMessage = await stream.reduce((previous, element) {
          return previous.value > element.value ? previous : element;
        });

        // Assert
        expect(maxMessage.value, equals(5));
        expect(maxMessage.text, equals('Message 5'));
      });

      test('join() должен корректно объединять строковые представления',
          () async {
        // Arrange
        final messages = List.generate(3, (i) => TestMessages.simple(i + 1));
        final stream = TestRpcStream.withMessages(messages);

        // Создаем поток строк из текстов сообщений
        final textStream = stream.map((msg) => msg.text);

        // Act - объединяем строки с разделителем
        final joined = await textStream.join(', ');

        // Assert
        expect(joined, equals('Message 1, Message 2, Message 3'));
      });

      test('every() должен проверять соответствие всех элементов условию',
          () async {
        // Arrange - все сообщения с положительными значениями
        final positiveMessages =
            List.generate(5, (i) => TestMessages.simple(i + 1));
        final positiveStream = TestRpcStream.withMessages(positiveMessages);

        // Смешанные положительные и отрицательные значения
        final mixedMessages = [
          TestMessages.withValue(1),
          TestMessages.withValue(-2),
          TestMessages.withValue(3),
        ];
        final mixedStream = TestRpcStream.withMessages(mixedMessages);

        // Act & Assert
        // Проверяем, что все значения > 0
        final allPositive1 = await positiveStream.every((msg) => msg.value > 0);
        expect(allPositive1, isTrue);

        final allPositive2 = await mixedStream.every((msg) => msg.value > 0);
        expect(allPositive2, isFalse);
      });

      test(
          'any() должен проверять наличие хотя бы одного элемента, соответствующего условию',
          () async {
        // Arrange
        final messages1 = [
          TestMessages.withValue(1),
          TestMessages.withValue(3),
          TestMessages.withValue(5),
        ];
        final stream1 = TestRpcStream.withMessages(messages1);

        final messages2 = [
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(4),
        ];
        final stream2 = TestRpcStream.withMessages(messages2);

        // Act & Assert
        // Проверяем наличие хотя бы одного четного значения
        final hasEven1 = await stream1.any((msg) => msg.value % 2 == 0);
        expect(hasEven1, isFalse);

        final hasEven2 = await stream2.any((msg) => msg.value % 2 == 0);
        expect(hasEven2, isTrue);
      });
    });
  });
}
