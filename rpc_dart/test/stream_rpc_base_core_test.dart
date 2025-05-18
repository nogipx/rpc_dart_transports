import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

/// Тестовое сообщение для проверки RPC потоков (аналогично основному тесту)
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

  /// Создает тестовый стрим с динамическими сообщениями
  static TestRpcStream withControlledMessages() {
    final controller = StreamController<TestMessage>();

    return TestRpcStream(
      responseStream: controller.stream,
      closeFunction: () async {
        await controller.close();
      },
    )..controller = controller;
  }

  // Добавляем доступ к контроллеру для тестирования
  late final StreamController<TestMessage> controller;
}

/// Для тестирования метода pipe
class TestStreamConsumer implements StreamConsumer<TestMessage> {
  final List<TestMessage> collectedEvents = [];
  bool isClosed = false;

  @override
  Future<void> addStream(Stream<TestMessage> stream) {
    return stream.forEach(collectedEvents.add);
  }

  @override
  Future<void> close() {
    isClosed = true;
    return Future.value();
  }
}

/// Для тестирования метода transform
class TestStreamTransformer implements StreamTransformer<TestMessage, String> {
  @override
  Stream<String> bind(Stream<TestMessage> stream) {
    return stream.map((event) => 'Transformed: ${event.text}');
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() {
    return StreamTransformer.castFrom<TestMessage, String, RS, RT>(this);
  }
}

void main() {
  group('RpcStream методы делегирования', () {
    // Тесты для методов, которые еще не покрыты

    group('asyncExpand() и asyncMap()', () {
      test('asyncExpand должен асинхронно разворачивать каждый элемент в поток',
          () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.simple(1),
          TestMessages.simple(2),
        ]);

        // Act
        final expandedStream = stream.asyncExpand((event) async* {
          // Генерируем два элемента для каждого входного
          yield TestMessage(
              text: 'Expanded 1: ${event.text}', value: event.value);
          // Добавляем немного асинхронности
          await Future.microtask(() {});
          yield TestMessage(
              text: 'Expanded 2: ${event.text}', value: event.value * 10);
        });

        // Assert
        final result = await expandedStream.toList();
        expect(result.length, equals(4));
        expect(result[0].text, equals('Expanded 1: Message 1'));
        expect(result[1].text, equals('Expanded 2: Message 1'));
        expect(result[2].text, equals('Expanded 1: Message 2'));
        expect(result[3].text, equals('Expanded 2: Message 2'));
      });
    });

    group('cast()', () {
      test('cast должен правильно приводить типы', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.simple(1),
          TestMessages.simple(2),
        ]);

        // Act: приводим TestMessage к IRpcSerializableMessage (что работает, т.к. это предок)
        final castStream = stream.cast<IRpcSerializableMessage>();

        // Assert
        expect(castStream, isA<Stream<IRpcSerializableMessage>>());
        final results = await castStream.toList();
        expect(results.length, equals(2));
        // Убеждаемся, что это действительно наши объекты
        expect(results[0], isA<TestMessage>());
        expect((results[0] as TestMessage).text, equals('Message 1'));
      });
    });

    group('contains() и any()', () {
      test('contains должен проверять наличие элемента', () async {
        // Arrange
        final targetMessage = TestMessages.simple(2);
        final stream = TestRpcStream.withMessages([
          TestMessages.simple(1),
          targetMessage,
          TestMessages.simple(3),
        ]);

        // Act & Assert
        expect(await stream.contains(targetMessage), isTrue);

        // Новый поток, т.к. предыдущий уже исчерпан
        final streamForNonExistent = TestRpcStream.withMessages([
          TestMessages.simple(1),
          TestMessages.simple(3),
        ]);
        expect(await streamForNonExistent.contains(TestMessages.simple(2)),
            isFalse);
      });

      test('any должен проверять условие для элементов', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.simple(1),
          TestMessages.simple(2),
          TestMessages.simple(3),
        ]);

        // Act & Assert
        expect(await stream.any((msg) => msg.value > 2), isTrue);

        // Новый поток
        final streamForFalse = TestRpcStream.withMessages([
          TestMessages.simple(1),
          TestMessages.simple(2),
        ]);
        expect(await streamForFalse.any((msg) => msg.value > 10), isFalse);
      });
    });

    group('distinct()', () {
      test('distinct должен удалять последовательные дубликаты', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withText('A'), // 1
          TestMessages.withText('A'), // повтор
          TestMessages.withText('B'), // 2
          TestMessages.withText('C'), // 3
          TestMessages.withText('C'), // повтор
          TestMessages.withText('C'), // повтор
          TestMessages.withText('B'), // 4
        ]);

        // Act
        final distinctStream = stream.distinct();

        // Assert
        final results = await distinctStream.toList();
        expect(results.length, equals(4));
        expect(results[0].text, equals('A'));
        expect(results[1].text, equals('B'));
        expect(results[2].text, equals('C'));
        expect(results[3].text, equals('B'));
      });

      test('distinct с кастомным компаратором', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(3), // нечетное
          TestMessages.withValue(5), // тоже нечетное, считаем как "то же самое"
          TestMessages.withValue(4),
          TestMessages.withValue(6), // четное, как и 4
        ]);

        // Act
        // Считаем "одинаковыми" элементы с одинаковой четностью
        final distinctStream =
            stream.distinct((a, b) => a.value % 2 == b.value % 2);

        // Assert
        final results = await distinctStream.toList();
        expect(results.length, equals(4));
        expect(results[0].value, equals(1)); // нечетное
        expect(results[1].value, equals(2)); // четное
        expect(results[2].value, equals(3)); // нечетное снова
        expect(results[3].value, equals(4)); // четное снова
      });
    });

    group('drain() и join()', () {
      test('drain должен игнорировать все элементы и возвращать значение',
          () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.simple(1),
          TestMessages.simple(2),
        ]);

        // Act
        final result = await stream.drain('done');

        // Assert
        expect(result, equals('done'));
      });

      test('join должен объединять строковые представления элементов',
          () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withText('A'),
          TestMessages.withText('B'),
          TestMessages.withText('C'),
        ]);

        // Act
        final result = await stream.join('-');

        // Assert
        // Обратите внимание на строковое представление объектов
        expect(
            result,
            equals(
                'TestMessage(text: A, value: 0)-TestMessage(text: B, value: 0)-TestMessage(text: C, value: 0)'));
      });
    });

    group('elementAt(), every(), fold() и forEach()', () {
      test('elementAt должен возвращать элемент по индексу', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.simple(1),
          TestMessages.simple(2),
          TestMessages.simple(3),
        ]);

        // Act & Assert
        final element = await stream.elementAt(1);
        expect(element.value, equals(2));

        // Проверка на исключение при выходе за границы
        final newStream = TestRpcStream.withMessages([TestMessages.simple(1)]);
        expect(() => newStream.elementAt(1), throwsA(isA<RangeError>()));
      });

      test('every должен проверять условие для всех элементов', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.even(1), // 2
          TestMessages.even(2), // 4
          TestMessages.even(3), // 6
        ]);

        // Act & Assert
        expect(await stream.every((msg) => msg.value % 2 == 0), isTrue);

        // Новый поток с "нарушителем"
        final streamWithOdd = TestRpcStream.withMessages([
          TestMessages.even(1), // 2
          TestMessages.odd(1), // 1 - нечетное!
          TestMessages.even(2), // 4
        ]);
        expect(await streamWithOdd.every((msg) => msg.value % 2 == 0), isFalse);
      });

      test('fold должен аккумулировать значение из потока', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(3),
        ]);

        // Act
        final sum = await stream.fold(0, (prev, msg) => prev + msg.value);

        // Assert
        expect(sum, equals(6)); // 1 + 2 + 3
      });

      test('forEach должен применять функцию к каждому элементу', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(3),
        ]);
        final results = <int>[];

        // Act
        await stream.forEach((msg) => results.add(msg.value * 2));

        // Assert
        expect(results, equals([2, 4, 6]));
      });
    });

    group('expand()', () {
      test('expand должен преобразовывать каждый элемент в несколько',
          () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
        ]);

        // Act
        // Превращаем каждое число в его множители
        final expandedStream = stream.expand((msg) {
          final values = <TestMessage>[];
          for (int i = 1; i <= msg.value; i++) {
            if (msg.value % i == 0) {
              values.add(TestMessages.withValue(i));
            }
          }
          return values;
        });

        // Assert
        final results = await expandedStream.toList();
        expect(results.length,
            equals(3)); // 1 имеет множитель 1, 2 имеет множители 1,2
        expect(results.map((e) => e.value).toList(), equals([1, 1, 2]));
      });
    });

    group('handleError()', () {
      test('handleError должен обрабатывать ошибки', () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        // Act
        final handledStream = stream.handleError(
          (error) {
            // Просто игнорируем ошибку
          },
          test: (error) => error == 'expected error',
        );

        // Будем собирать результаты и ошибки
        final results = <TestMessage>[];
        final errors = <Object>[];

        final subscription = handledStream.listen(
          results.add,
          onError: errors.add,
        );

        // Добавляем обычное сообщение
        controller.add(TestMessages.simple(1));

        // Добавляем обрабатываемую ошибку
        controller.addError('expected error');

        // Добавляем необрабатываемую ошибку
        controller.addError('unexpected error');

        // Ждем обработки
        await Future.microtask(() {});
        await Future.microtask(() {});
        await Future.microtask(() {});

        // Assert
        expect(results.length, equals(1));
        expect(errors.length, equals(1)); // Только необработанная ошибка
        expect(errors[0], equals('unexpected error'));

        await subscription.cancel();
        await controller.close();
      });
    });

    group('isBroadcast и isEmpty', () {
      test('isBroadcast должен отражать тип потока', () {
        // Arrange & Act & Assert
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );
        expect(stream.isBroadcast, isFalse);

        final broadcastController = StreamController<TestMessage>.broadcast();
        final broadcastStream = TestRpcStream(
          responseStream: broadcastController.stream,
          closeFunction: () => broadcastController.close(),
        );
        expect(broadcastStream.isBroadcast, isTrue);

        controller.close();
        broadcastController.close();
      });

      test('isEmpty должен проверять наличие элементов', () async {
        // Arrange
        final emptyStream = TestRpcStream.withMessages([]);
        final nonEmptyStream =
            TestRpcStream.withMessages([TestMessages.simple(1)]);

        // Act & Assert
        expect(await emptyStream.isEmpty, isTrue);
        expect(await nonEmptyStream.isEmpty, isFalse);
      });
    });

    group('lastWhere(), reduce(), singleWhere()', () {
      test('lastWhere должен находить последний элемент с условием', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(3),
          TestMessages.withValue(4),
        ]);

        // Act & Assert
        final last = await stream.lastWhere((msg) => msg.value % 2 == 0);
        expect(last.value, equals(4));

        // С orElse
        final newStream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(3),
        ]);
        final result = await newStream.lastWhere(
          (msg) => msg.value % 2 == 0,
          orElse: () => TestMessages.withValue(0),
        );
        expect(result.value, equals(0)); // Используется значение по умолчанию
      });

      test('reduce должен сворачивать элементы потока', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(3),
        ]);

        // Act
        final result = await stream.reduce((prev, element) => TestMessage(
            text: '${prev.text}+${element.text}',
            value: prev.value + element.value));

        expect(result.text, equals('Value+Value+Value'));
        expect(result.value, equals(6)); // 1 + 2 + 3
      });

      test('singleWhere должен находить единственный элемент с условием',
          () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(3),
        ]);

        // Act & Assert
        final result = await stream.singleWhere((msg) => msg.value == 2);
        expect(result.value, equals(2));

        // Случай, когда несколько совпадений
        final streamWithDups = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(2), // дубликат!
        ]);
        expect(
          () => streamWithDups.singleWhere((msg) => msg.value == 2),
          throwsA(isA<StateError>()),
        );

        // Случай, когда нет совпадений, но есть orElse
        final streamWithoutMatch = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(3),
        ]);
        final defaultResult = await streamWithoutMatch.singleWhere(
          (msg) => msg.value == 2,
          orElse: () => TestMessages.withValue(0),
        );
        expect(defaultResult.value,
            equals(0)); // Используется значение по умолчанию
      });
    });

    group('skipWhile(), takeWhile()', () {
      test('skipWhile должен пропускать элементы, пока выполняется условие',
          () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(5),
          TestMessages.withValue(3),
        ]);

        // Act
        final resultStream = stream.skipWhile((msg) => msg.value < 5);

        // Assert
        final results = await resultStream.toList();
        expect(results.length, equals(2));
        expect(results[0].value, equals(5)); // Первый непропускаемый
        expect(results[1].value, equals(3));
      });

      test('takeWhile должен брать элементы, пока выполняется условие',
          () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withValue(1),
          TestMessages.withValue(2),
          TestMessages.withValue(5),
          TestMessages.withValue(3),
        ]);

        // Act
        final resultStream = stream.takeWhile((msg) => msg.value < 5);

        // Assert
        final results = await resultStream.toList();
        expect(results.length, equals(2));
        expect(results[0].value, equals(1));
        expect(results[1].value, equals(2));
      });
    });

    group('timeout()', () {
      test('timeout должен вызывать onTimeout при таймауте', () async {
        // Arrange
        final controller = StreamController<TestMessage>();
        final stream = TestRpcStream(
          responseStream: controller.stream,
          closeFunction: () => controller.close(),
        );

        // Act
        final timeoutStream = stream.timeout(
          Duration(milliseconds: 50),
          onTimeout: (sink) {
            sink.add(TestMessages.withText('Timeout'));
            sink.close();
          },
        );

        // Запускаем сбор результатов
        final resultFuture = timeoutStream.toList();

        // Ничего не отправляем, просто ждем срабатывания таймаута
        final results = await resultFuture;

        // Assert
        expect(results.length, equals(1));
        expect(results[0].text, equals('Timeout'));

        await controller.close();
      });
    });

    group('toSet()', () {
      test('toSet должен создавать множество из уникальных элементов',
          () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.withText('A'),
          TestMessages.withText('B'),
          TestMessages.withText('A'), // дубликат!
          TestMessages.withText('C'),
        ]);

        // Act
        final resultSet = await stream.toSet();

        // Assert
        expect(resultSet.length, equals(3)); // Уникальные элементы A, B, C
        expect(resultSet.map((e) => e.text).toList()..sort(),
            equals(['A', 'B', 'C']));
      });
    });

    group('pipe() и transform()', () {
      test('pipe должен передавать данные потребителю', () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.simple(1),
          TestMessages.simple(2),
        ]);
        final consumer = TestStreamConsumer();

        // Act
        await stream.pipe(consumer);

        // Assert
        expect(consumer.collectedEvents.length, equals(2));
        expect(consumer.collectedEvents[0].value, equals(1));
        expect(consumer.collectedEvents[1].value, equals(2));
        expect(consumer.isClosed, isTrue);
      });

      test('transform должен преобразовывать поток с помощью трансформера',
          () async {
        // Arrange
        final stream = TestRpcStream.withMessages([
          TestMessages.simple(1),
          TestMessages.simple(2),
        ]);
        final transformer = TestStreamTransformer();

        // Act
        final transformedStream = stream.transform(transformer);

        // Assert
        final results = await transformedStream.toList();
        expect(results.length, equals(2));
        expect(results[0], equals('Transformed: Message 1'));
        expect(results[1], equals('Transformed: Message 2'));
      });
    });
  });
}
