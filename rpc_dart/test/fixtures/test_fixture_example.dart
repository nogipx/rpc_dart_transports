// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';
import 'test_contract.dart';

/// Пример использования тестовой фикстуры в unit-тестах
void main() {
  late RpcEndpoint clientEndpoint;
  late RpcEndpoint serverEndpoint;
  late TestFixtureClientContract clientContract;
  late TestFixtureServerContract serverContract;

  // Настраиваем окружение перед каждым тестом
  setUp(() {
    final env = TestFixtureUtils.setupTestEnvironment();
    clientEndpoint = env.$1;
    serverEndpoint = env.$2;
    clientContract = env.$3;
    serverContract = env.$4;
  });

  // Очищаем ресурсы после каждого теста
  tearDown(() async {
    await TestFixtureUtils.tearDown(clientEndpoint, serverEndpoint);
  });

  group('Тесты унарных методов', () {
    test('Простой унарный метод должен возвращать ответ с префиксом', () async {
      final response = await clientContract.unaryTests.simpleUnary(
        UnaryRequest('тестовое сообщение'),
      );

      expect(response.data, equals('unary:тестовое сообщение'));
    });

    test('Эхо-метод должен возвращать тот же текст, что в запросе', () async {
      final response = await clientContract.unaryTests.echoUnary(
        UnaryRequest('hello world'),
      );

      expect(response.data, equals('hello world'));
    });

    test('Метод с задержкой должен работать корректно', () async {
      final response = await clientContract.unaryTests.delayedUnary(
        UnaryRequest('200'),
      );

      expect(response.data, equals('delayed:200'));
    });

    test('Метод с ошибкой должен генерировать ошибку', () async {
      expect(
        () => clientContract.unaryTests.errorUnary(
          UnaryRequest('тестовая ошибка'),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Тесты клиентского стриминга', () {
    test('Метод сбора данных должен объединять все полученные сообщения',
        () async {
      final stream = clientContract.clientStreamingTests.collectData();

      // Отправляем сообщения
      stream.send(ClientStreamRequest('сообщение 1'));
      stream.send(ClientStreamRequest('сообщение 2'));
      stream.send(ClientStreamRequest('сообщение 3'));

      // Завершаем отправку и получаем ответ
      await stream.finishSending();
      final response = await stream.getResponse();

      expect(response?.data, contains('сообщение 1'));
      expect(response?.data, contains('сообщение 2'));
      expect(response?.data, contains('сообщение 3'));
    });

    test('Метод подсчета должен подсчитывать количество отправленных элементов',
        () async {
      final stream = clientContract.clientStreamingTests.countItems();

      // Отправляем несколько сообщений
      for (var i = 0; i < 5; i++) {
        stream.send(ClientStreamRequest('сообщение $i'));
      }

      // Завершаем отправку и получаем ответ
      await stream.finishSending();
      final response = await stream.getResponse();

      expect(response?.data, equals('count:5'));
    });
  });

  group('Тесты серверного стриминга', () {
    test('Метод генерации должен выдавать указанное количество элементов',
        () async {
      // Запрашиваем 3 элемента
      final stream = clientContract.serverStreamingTests.generateItems(
        ServerStreamRequest('3'),
      );

      final responses = await stream.toList();

      expect(responses.length, equals(3));
      expect(responses[0].data, equals('item-0'));
      expect(responses[1].data, equals('item-1'));
      expect(responses[2].data, equals('item-2'));
    });

    test('Эхо-стрим должен возвращать одно сообщение с тем же содержимым',
        () async {
      final stream = clientContract.serverStreamingTests.echoStream(
        ServerStreamRequest('тестовое сообщение'),
      );

      final responses = await stream.toList();

      expect(responses.length, equals(1));
      expect(responses[0].data, equals('тестовое сообщение'));
    });
  });

  group('Тесты двунаправленного стриминга', () {
    test('Эхо-стрим должен возвращать сообщения с префиксом', () async {
      final stream = clientContract.bidirectionalTests.echoStream();

      // Создаем коллектор ответов
      final responses = <BidirectionalResponse>[];
      final subscription = stream.listen(
        (response) => responses.add(response),
      );

      // Отправляем сообщения
      stream.send(BidirectionalRequest('сообщение 1'));
      stream.send(BidirectionalRequest('сообщение 2'));

      // Даем время на обработку
      await Future.delayed(Duration(milliseconds: 50));

      // Закрываем стрим и ждем завершения
      await stream.close();
      await subscription.asFuture();

      expect(responses.length, equals(2));
      expect(responses[0].data, equals('echo:сообщение 1'));
      expect(responses[1].data, equals('echo:сообщение 2'));
    });

    test('Трансформационный стрим должен преобразовывать сообщения', () async {
      final stream = clientContract.bidirectionalTests.transformStream();

      // Создаем коллектор ответов
      final responses = <BidirectionalResponse>[];
      final subscription = stream.listen(
        (response) => responses.add(response),
      );

      // Отправляем сообщения
      stream.send(BidirectionalRequest('привет'));
      stream.send(BidirectionalRequest('мир'));

      // Даем время на обработку
      await Future.delayed(Duration(milliseconds: 50));

      // Закрываем стрим и ждем завершения
      await stream.close();
      await subscription.asFuture();

      expect(responses.length, equals(2));
      expect(responses[0].data, equals('ПРИВЕТ'));
      expect(responses[1].data, equals('МИР'));
    });
  });

  group('Тесты транспортов', () {
    test('Транспорт через память должен работать корректно', () async {
      final response = await clientContract.transportTests.memoryTransport(
        TestMessage('тестовое сообщение'),
      );

      expect(response.data, equals('memory_transport:тестовое сообщение'));
    });

    test('JSON-RPC транспорт должен работать корректно', () async {
      final response = await clientContract.transportTests.jsonRpcTransport(
        TestMessage('тестовое сообщение'),
      );

      expect(response.data, equals('json_rpc_transport:тестовое сообщение'));
    });
  });

  group('Тесты сериализации', () {
    test('JSON сериализация должна работать корректно', () async {
      final response =
          await clientContract.serializationTests.jsonSerialization(
        TestMessage('тестовое сообщение'),
      );

      expect(response.data, equals('json_serialization:тестовое сообщение'));
    });

    test('MsgPack сериализация должна работать корректно', () async {
      final response =
          await clientContract.serializationTests.msgPackSerialization(
        TestMessage('тестовое сообщение'),
      );

      expect(response.data, equals('msgpack_serialization:тестовое сообщение'));
    });
  });
}
