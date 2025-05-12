import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

/// Тестовое сообщение
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
}

void main() {
  group('BidiStream и его адаптеры', () {
    group('Базовый BidiStream', () {
      test('должен корректно отправлять и получать сообщения', () async {
        // Создаем контроллер для ручного управления потоком ответов
        final responseController = StreamController<TestMessage>();

        // Создаем BidiStream
        final bidiStream = BidiStream<TestMessage, TestMessage>(
          responseStream: responseController.stream,
          sendFunction: (request) {
            // Эмулируем обработку на сервере
            responseController.add(
              TestMessage(
                  text: 'Ответ на: ${request.text}', value: request.value * 2),
            );
          },
          closeFunction: () async {
            await responseController.close();
          },
        );

        // Список для сбора ответов
        final receivedResponses = <TestMessage>[];

        // Подписываемся на ответы
        final subscription = bidiStream.listen(
          receivedResponses.add,
          onDone: () {
            // Стрим завершен
          },
        );

        // Отправляем запросы
        bidiStream.send(TestMessage(text: 'Запрос 1', value: 10));
        bidiStream.send(TestMessage(text: 'Запрос 2', value: 20));

        // Ждем небольшую паузу для получения всех ответов
        await Future.delayed(Duration(milliseconds: 10));

        // Закрываем стрим
        await bidiStream.close();
        await subscription.cancel();

        // Проверки
        expect(receivedResponses.length, equals(2));
        expect(receivedResponses[0].text, equals('Ответ на: Запрос 1'));
        expect(receivedResponses[0].value, equals(20)); // value * 2
        expect(receivedResponses[1].text, equals('Ответ на: Запрос 2'));
        expect(receivedResponses[1].value, equals(40)); // value * 2
        expect(bidiStream.isClosed, isTrue);
      });

      test('BidiStreamGenerator должен создавать корректный BidiStream',
          () async {
        // Создаем генератор
        final generator = BidiStreamGenerator<TestMessage, TestMessage>(
          (requests) async* {
            int multiplier = 1;

            // Обрабатываем запросы по мере их поступления
            await for (final request in requests) {
              yield TestMessage(
                text: 'Ответ #$multiplier на: ${request.text}',
                value: request.value * multiplier,
              );
              multiplier++;
            }
          },
        );

        // Создаем BidiStream из генератора
        final bidiStream = generator.create();

        // Список для сбора ответов
        final responses = <TestMessage>[];

        // Подписываемся на ответы
        final subscription = bidiStream.listen(responses.add);

        // Отправляем запросы
        bidiStream.send(TestMessage(text: 'Тест 1', value: 100));
        bidiStream.send(TestMessage(text: 'Тест 2', value: 200));
        bidiStream.send(TestMessage(text: 'Тест 3', value: 300));

        // Ждем небольшую паузу
        await Future.delayed(Duration(milliseconds: 10));

        // Закрываем стрим
        await bidiStream.close();
        await subscription.cancel();

        // Проверки
        expect(responses.length, equals(3));
        expect(responses[0].text, equals('Ответ #1 на: Тест 1'));
        expect(responses[0].value, equals(100)); // 100 * 1
        expect(responses[1].text, equals('Ответ #2 на: Тест 2'));
        expect(responses[1].value, equals(400)); // 200 * 2
        expect(responses[2].text, equals('Ответ #3 на: Тест 3'));
        expect(responses[2].value, equals(900)); // 300 * 3
      });
    });

    group('ServerStreamingBidiStream (один запрос → много ответов)', () {
      test('должен отправлять только один запрос', () async {
        // Счетчик полученных запросов
        int requestsReceived = 0;

        // Создаем генератор
        final generator = BidiStreamGenerator<TestMessage, TestMessage>(
          (requests) async* {
            // Получаем только один запрос
            TestMessage? request;
            await for (final req in requests) {
              request = req;
              requestsReceived++;
              break;
            }

            if (request != null) {
              // Генерируем несколько ответов
              for (int i = 1; i <= 3; i++) {
                yield TestMessage(
                  text: 'Ответ #$i на: ${request.text}',
                  value: request.value * i,
                );
                await Future.delayed(Duration(milliseconds: 5));
              }
            }
          },
        );

        // Создаем ServerStreamingBidiStream с начальным запросом
        final serverStreamBidi = generator.createServerStreaming(
          initialRequest: TestMessage(text: 'Начальный запрос', value: 50),
        );

        // Список для сбора ответов
        final responses = <TestMessage>[];

        // Подписываемся на ответы
        final subscription = serverStreamBidi.listen(responses.add);

        // Попытка отправить второй запрос должна вызвать ошибку
        expect(
          () => serverStreamBidi
              .sendRequest(TestMessage(text: 'Второй запрос', value: 100)),
          throwsStateError,
        );

        // Ждем завершения потока
        await Future.delayed(Duration(milliseconds: 50));
        await subscription.cancel();

        // Проверки
        expect(requestsReceived, equals(1));
        expect(responses.length, equals(3));
        expect(responses[0].text, equals('Ответ #1 на: Начальный запрос'));
        expect(responses[0].value, equals(50)); // 50 * 1
        expect(responses[1].text, equals('Ответ #2 на: Начальный запрос'));
        expect(responses[1].value, equals(100)); // 50 * 2
        expect(responses[2].text, equals('Ответ #3 на: Начальный запрос'));
        expect(responses[2].value, equals(150)); // 50 * 3
      });

      test(
          'toServerStreaming должен преобразовывать BidiStream в ServerStreamingBidiStream',
          () async {
        // Создаем BidiStream
        final generator = BidiStreamGenerator<TestMessage, TestMessage>(
          (requests) async* {
            TestMessage? request;
            await for (final req in requests) {
              request = req;
              break;
            }

            if (request != null) {
              for (int i = 1; i <= 3; i++) {
                yield TestMessage(
                  text: 'Ответ $i',
                  value: request.value * i,
                );
              }
            }
          },
        );

        // Создаем BidiStream
        final bidiStream = generator.create();

        // Конвертируем в ServerStreamingBidiStream
        final serverStream = bidiStream.toServerStreaming(
          initialRequest: TestMessage(text: 'Запрос через адаптер', value: 30),
        );

        // Список для сбора ответов
        final responses = <TestMessage>[];

        // Подписываемся на ответы
        final subscription = serverStream.listen(responses.add);

        // Ждем завершения потока
        await Future.delayed(Duration(milliseconds: 50));
        await subscription.cancel();

        // Проверки
        expect(responses.length, equals(3));
        expect(responses[0].value, equals(30)); // 30 * 1
        expect(responses[1].value, equals(60)); // 30 * 2
        expect(responses[2].value, equals(90)); // 30 * 3
      });
    });

    group('ClientStreamingBidiStream (много запросов → один ответ)', () {
      test('должен обрабатывать множество запросов и возвращать один ответ',
          () async {
        // Создаем генератор
        final generator = BidiStreamGenerator<TestMessage, TestMessage>(
          (requests) async* {
            final receivedTexts = <String>[];
            int sum = 0;

            // Собираем все запросы
            await for (final request in requests) {
              receivedTexts.add(request.text);
              sum += request.value;
            }

            // Выдаем один финальный ответ
            yield TestMessage(
              text: 'Финальный ответ на запросы: ${receivedTexts.join(", ")}',
              value: sum,
            );
          },
        );

        // Создаем ClientStreamingBidiStream
        final clientStreamBidi = generator.createClientStreaming();

        // Отправляем запросы
        clientStreamBidi.send(TestMessage(text: 'Запрос 1', value: 10));
        await Future.delayed(Duration(milliseconds: 5));
        clientStreamBidi.send(TestMessage(text: 'Запрос 2', value: 20));
        await Future.delayed(Duration(milliseconds: 5));
        clientStreamBidi.send(TestMessage(text: 'Запрос 3', value: 30));

        // Завершаем передачу данных
        await clientStreamBidi.finishSending();

        // Закрываем поток запросов
        await clientStreamBidi.close();

        // Получаем финальный ответ
        final response = await clientStreamBidi.getResponse();

        // Проверки
        expect(response.text, contains('Финальный ответ на запросы:'));
        expect(response.text, contains('Запрос 1'));
        expect(response.text, contains('Запрос 2'));
        expect(response.text, contains('Запрос 3'));
        expect(response.value, equals(60)); // 10 + 20 + 30
      });

      test(
          'toClientStreaming должен преобразовывать BidiStream в ClientStreamingBidiStream',
          () async {
        // Создаем BidiStream
        final generator = BidiStreamGenerator<TestMessage, TestMessage>(
          (requests) async* {
            int sum = 0;
            await for (final request in requests) {
              sum += request.value;
            }
            yield TestMessage(text: 'Сумма всех значений', value: sum);
          },
        );

        // Создаем BidiStream
        final bidiStream = generator.create();

        // Конвертируем в ClientStreamingBidiStream
        final clientStream = bidiStream.toClientStreaming();

        // Отправляем запросы
        clientStream.send(TestMessage(text: 'A', value: 5));
        clientStream.send(TestMessage(text: 'B', value: 10));
        clientStream.send(TestMessage(text: 'C', value: 15));

        // Завершаем передачу данных
        await clientStream.finishSending();

        // Закрываем поток запросов
        await clientStream.close();

        // Получаем ответ
        final response = await clientStream.getResponse();

        // Проверки
        expect(response.text, equals('Сумма всех значений'));
        expect(response.value, equals(30)); // 5 + 10 + 15
      });
    });

    group('Взаимодействие и преобразования между типами стримов', () {
      test('BidiStream должен быть приводим к ServerStreamingBidiStream', () {
        // Создаем заглушку BidiStream для тестирования типов
        final dummyController = StreamController<TestMessage>();
        final dummyStream = BidiStream<TestMessage, TestMessage>(
          responseStream: dummyController.stream,
          sendFunction: (_) {}, // Ничего не делаем при отправке
          closeFunction: () async => dummyController.close(),
        );

        // Проверяем только типы без подписки на события
        final typedServerStream = dummyStream.toServerStreaming();

        // Проверяем, что объекты созданы и имеют правильные типы
        expect(typedServerStream,
            isA<ServerStreamingBidiStream<TestMessage, TestMessage>>());

        // Закрываем контроллер напрямую
        dummyController.close();
      });

      test('BidiStream должен быть приводим к ClientStreamingBidiStream', () {
        // Для ClientStreamingBidiStream нам нужно подготовить сразу ответ,
        // чтобы избежать ошибки "Поток завершился без ответа"
        final dummyController = StreamController<TestMessage>();

        // Добавляем ответ в поток сразу
        dummyController.add(TestMessage(text: 'Тестовый ответ', value: 42));

        final dummyStream = BidiStream<TestMessage, TestMessage>(
          responseStream: dummyController.stream,
          sendFunction: (_) {},
          closeFunction: () async => dummyController.close(),
        );

        // Проверяем тип
        final typedClientStream = dummyStream.toClientStreaming();
        expect(typedClientStream,
            isA<ClientStreamingBidiStream<TestMessage, TestMessage>>());

        // Не закрываем контроллер сразу, чтобы ClientStreamingBidiStream мог получить ответ
      });

      test('BidiStreamGenerator должен создавать любой тип стрима', () {
        // Создаем генератор
        final generator = BidiStreamGenerator<TestMessage, TestMessage>(
          (requests) async* {
            await for (final request in requests) {
              yield TestMessage(text: 'Ответ', value: request.value);
            }
          },
        );

        // Создаем разные типы стримов из одного генератора
        final bidiStream = generator.create();
        expect(bidiStream, isA<BidiStream<TestMessage, TestMessage>>());

        final serverStream = generator.createServerStreaming();
        expect(serverStream,
            isA<ServerStreamingBidiStream<TestMessage, TestMessage>>());

        final clientStream = generator.createClientStreaming();
        expect(clientStream,
            isA<ClientStreamingBidiStream<TestMessage, TestMessage>>());
      });
    });
  });
}
