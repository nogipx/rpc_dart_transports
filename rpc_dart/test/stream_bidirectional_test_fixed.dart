// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';

import 'fixtures/test_contract.dart';

void main() {
  group('BidiStream с использованием фикстур', () {
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late TestFixtureClientContract clientContract;

    setUp(() {
      // Создаем эндпоинты
      final endpointPair = TestFixtureUtils.createEndpointPair(
        clientLabel: 'client',
        serverLabel: 'server',
      );

      clientEndpoint = endpointPair.client;
      serverEndpoint = endpointPair.server;

      // Создаем и регистрируем контракты
      final contracts = TestFixtureUtils.createTestContracts(
        clientEndpoint,
        serverEndpoint,
        registerClientContract: false,
      );

      clientContract = contracts.client;

      // Добавляем отладочный middleware для диагностики
      serverEndpoint.addMiddleware(DebugMiddleware(RpcLogger('debug')));
      clientEndpoint.addMiddleware(DebugMiddleware(RpcLogger('debug')));

      // Регистрируем клиентский контракт
      clientEndpoint.registerContract(clientContract);
    });

    tearDown(() async {
      // Закрываем эндпоинты
      await clientEndpoint.close();
      await serverEndpoint.close();
    });

    test('должен корректно отправлять и получать сообщения', () async {
      // Получаем двунаправленный стрим
      final bidiStream = clientContract.bidirectionalTests.echoStream();

      // Список для сбора ответов
      final receivedResponses = <BidirectionalResponse>[];

      // Подписываемся на ответы
      final subscription = bidiStream.listen(
        receivedResponses.add,
        onDone: () {
          // Стрим завершен
        },
      );

      // Отправляем запросы
      bidiStream.send(BidirectionalRequest('Запрос 1'));
      bidiStream.send(BidirectionalRequest('Запрос 2'));

      // Ждем небольшую паузу для получения всех ответов
      await Future.delayed(Duration(milliseconds: 50));

      // Закрываем стрим
      await bidiStream.close();
      await subscription.cancel();

      // Проверки
      expect(receivedResponses.length, equals(2));
      expect(receivedResponses[0].data, equals('echo:Запрос 1'));
      expect(receivedResponses[1].data, equals('echo:Запрос 2'));
      expect(bidiStream.isClosed, isTrue);
    });

    test('должен трансформировать сообщения', () async {
      // Получаем стрим для трансформаций
      final bidiStream = clientContract.bidirectionalTests.transformStream();

      // Список для сбора ответов
      final responses = <BidirectionalResponse>[];

      // Подписываемся на ответы
      final subscription = bidiStream.listen(responses.add);

      // Отправляем запросы
      bidiStream.send(BidirectionalRequest('тест 1'));
      bidiStream.send(BidirectionalRequest('тест 2'));
      bidiStream.send(BidirectionalRequest('тест 3'));

      // Ждем небольшую паузу
      await Future.delayed(Duration(milliseconds: 50));

      // Закрываем стрим
      await bidiStream.close();
      await subscription.cancel();

      // Проверки
      expect(responses.length, equals(3));
      expect(responses[0].data, equals('ТЕСТ 1'));
      expect(responses[1].data, equals('ТЕСТ 2'));
      expect(responses[2].data, equals('ТЕСТ 3'));
    });

    test('должен корректно обрабатывать ошибки', () async {
      // Получаем стрим для тестирования ошибок
      final bidiStream = clientContract.bidirectionalTests.errorStream();

      // Комплитер для отслеживания получения ошибки
      final errorCompleter = Completer<Object>();

      // Подписываемся с обработкой ошибок
      final subscription = bidiStream.listen(
        (_) {},
        onError: (error) {
          if (!errorCompleter.isCompleted) errorCompleter.complete(error);
        },
      );

      // Отправляем нормальное сообщение
      bidiStream.send(BidirectionalRequest('нормальное сообщение'));

      // Ждем небольшую паузу
      await Future.delayed(Duration(milliseconds: 10));

      // Отправляем сообщение, которое вызовет ошибку
      bidiStream.send(BidirectionalRequest('error'));

      // Ожидаем ошибку
      final error = await errorCompleter.future.timeout(
        Duration(milliseconds: 100),
        onTimeout: () => TimeoutException('Ошибка не получена'),
      );

      // Закрываем стрим
      await subscription.cancel();
      await bidiStream.close();

      // Проверяем ошибку
      expect(error.toString(), contains('ошибка'));
    });

    test('трансформация стрима', () async {
      // Получаем базовый стрим
      final bidiStream = clientContract.bidirectionalTests.echoStream();

      // Создаем трансформированный стрим
      final transformedStream = bidiStream.map(
          (response) => BidirectionalResponse('transformed-${response.data}'));

      // Список для сбора ответов
      final responses = <BidirectionalResponse>[];

      // Подписываемся на трансформированный стрим
      final subscription = transformedStream.listen(responses.add);

      // Отправляем запросы (через базовый стрим)
      bidiStream.send(BidirectionalRequest('test1'));
      bidiStream.send(BidirectionalRequest('test2'));

      // Ждем небольшую паузу
      await Future.delayed(Duration(milliseconds: 50));

      // Закрываем стрим
      await bidiStream.close();
      await subscription.cancel();

      // Проверки трансформированных ответов
      expect(responses.length, equals(2));
      expect(responses[0].data, equals('transformed-echo:test1'));
      expect(responses[1].data, equals('transformed-echo:test2'));
    });

    test('корректное закрытие потоков', () async {
      // Получаем двунаправленный стрим
      final bidiStream = clientContract.bidirectionalTests.echoStream();

      // Подписываемся на ответы
      final subscription = bidiStream.listen((_) {});

      // Отправляем запрос
      bidiStream.send(BidirectionalRequest('тест закрытия'));

      // Ждем небольшую паузу
      await Future.delayed(Duration(milliseconds: 10));

      // Закрываем стрим
      await bidiStream.close();

      // Проверяем, что стрим закрыт
      expect(bidiStream.isClosed, isTrue);

      // Попытка отправить после закрытия должна вызвать ошибку
      expect(
        () => bidiStream.send(BidirectionalRequest('после закрытия')),
        throwsA(isA<StateError>()),
      );

      // Отменяем подписку
      await subscription.cancel();
    });
  });
}
