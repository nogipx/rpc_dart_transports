// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';

import 'fixtures/test_contract.dart';

void main() {
  group('ClientStreamingBidiStream с использованием фикстур', () {
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

    test('должен корректно отправлять запросы и получать один ответ', () async {
      // Получаем клиентский стрим
      final clientStream = clientContract.clientStreamingTests.collectData();

      // Отправляем несколько запросов
      clientStream.send(ClientStreamRequest('Запрос 1'));
      clientStream.send(ClientStreamRequest('Запрос 2'));
      clientStream.send(ClientStreamRequest('Запрос 3'));

      // Завершаем отправку
      await clientStream.finishSending();

      // Получаем ответ от сервера
      final response = await clientStream.getResponse().timeout(
            Duration(milliseconds: 100),
            onTimeout: () =>
                throw TimeoutException('Не получен ответ от сервера'),
          );

      // Проверяем, что получен правильный ответ
      expect(response, isNotNull);
      expect(response!.data, contains('Запрос 1'));
      expect(response.data, contains('Запрос 2'));
      expect(response.data, contains('Запрос 3'));

      // Закрываем стрим
      await clientStream.close();

      // Проверяем, что стрим закрыт
      expect(clientStream.isClosed, isTrue);
    });

    test('должен корректно обрабатывать ошибки в потоке', () async {
      // Получаем клиентский стрим
      final clientStream = clientContract.clientStreamingTests.errorStream();

      // Отправляем запрос, который вызовет ошибку
      clientStream.send(ClientStreamRequest('error'));

      // Завершаем отправку и ожидаем ошибку
      await clientStream.finishSending();

      // Ожидаем ошибку при получении ответа
      await expectLater(
        () => clientStream.getResponse().timeout(
              Duration(milliseconds: 100),
              onTimeout: () =>
                  throw TimeoutException('Не получена ошибка от сервера'),
            ),
        throwsA(isA<Exception>()),
      );

      // Закрываем стрим
      await clientStream.close();

      // Проверяем, что стрим закрыт
      expect(clientStream.isClosed, isTrue);
    });

    test('должен обрабатывать задержки в ответах', () async {
      // В данном случае используем сбор данных как метод с задержкой
      final clientStream = clientContract.clientStreamingTests.collectData();

      // Отправляем запросы с интервалом
      clientStream.send(ClientStreamRequest('Запрос с задержкой 1'));
      await Future.delayed(Duration(milliseconds: 10));
      clientStream.send(ClientStreamRequest('Запрос с задержкой 2'));

      // Завершаем отправку
      await clientStream.finishSending();

      // Ждем ответ с таймаутом
      final response = await clientStream.getResponse().timeout(
            Duration(milliseconds: 100),
            onTimeout: () =>
                throw TimeoutException('Не получен ответ от сервера'),
          );

      // Проверяем, что получен правильный ответ
      expect(response, isNotNull);
      expect(response!.data, contains('Запрос с задержкой 1'));
      expect(response.data, contains('Запрос с задержкой 2'));

      // Проверяем, что поток не закрыт автоматически
      expect(clientStream.isClosed, isFalse);

      await clientStream.close();

      // Проверяем, что поток закрыт после явного закрытия
      expect(clientStream.isClosed, isTrue);
    });

    test('метод close() должен корректно закрывать поток', () async {
      // Получаем клиентский стрим
      final clientStream = clientContract.clientStreamingTests.collectData();

      // Отправляем сообщение, чтобы поток был "живым"
      clientStream.send(ClientStreamRequest('Тестовое сообщение'));

      // Закрываем поток
      await clientStream.close();

      // Проверяем, что поток закрыт
      expect(clientStream.isClosed, isTrue);
    });
  });
}
