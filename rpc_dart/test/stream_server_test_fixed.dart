// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';

import 'fixtures/test_contract.dart';

void main() {
  group('ServerStreamingBidiStream с использованием фикстур', () {
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late TestFixtureClientContract clientContract;

    setUp(() async {
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

    // Упрощенный тест: проверяем получение одного ответа
    test('должен получать эхо-ответ', () async {
      // Создаем запрос
      final request = ServerStreamRequest('test_echo');

      // Получаем серверный стрим
      final serverStream =
          clientContract.serverStreamingTests.echoStream(request);

      try {
        // Собираем только один ответ с таймаутом
        final response = await serverStream.first.timeout(
          Duration(milliseconds: 500),
          onTimeout: () => throw TimeoutException('Не получен ответ вовремя'),
        );

        // Проверяем ответ
        expect(response.data, equals('test_echo'),
            reason: 'Эхо должно вернуть исходное сообщение');
      } finally {
        // Всегда закрываем стрим
        await serverStream.close();
      }
    });

    // Упрощенный тест ошибок
    test('должен корректно обрабатывать ошибки', () async {
      // Создаем запрос, который вызовет ошибку
      final request = ServerStreamRequest('error');

      // Получаем серверный стрим
      final serverStream =
          clientContract.serverStreamingTests.errorStream(request);

      // Проверяем, что стрим выдаст ошибку
      await expectLater(
        serverStream.first,
        throwsA(isA<Exception>()),
      );

      // Закрываем стрим
      await serverStream.close();
    });

    // Упрощенный тест закрытия стрима
    test('должен корректно закрываться', () async {
      // Создаем запрос
      final request = ServerStreamRequest('тест');

      // Получаем серверный стрим
      final serverStream =
          clientContract.serverStreamingTests.echoStream(request);

      // Ждем короткое время для получения ответа
      await serverStream.first.timeout(
        Duration(milliseconds: 500),
        onTimeout: () => throw TimeoutException('Не получен ответ вовремя'),
      );

      // Закрываем стрим
      await serverStream.close();

      // Проверяем, что стрим закрыт
      expect(serverStream.isClosed, isTrue);
    });

    // Упрощенный тест для проверки нескольких ответов
    test('должен получать несколько элементов', () async {
      // Создаем запрос на 2 элемента (для скорости)
      final request = ServerStreamRequest('2');

      // Получаем серверный стрим
      final serverStream =
          clientContract.serverStreamingTests.generateItems(request);

      try {
        // Собираем ответы с коротким таймаутом
        final responses = await serverStream.take(2).timeout(
          Duration(seconds: 1),
          onTimeout: (sink) {
            sink.close();
          },
        ).toList();

        // Проверяем результаты
        expect(responses.length, equals(2),
            reason: 'Должны получить 2 элемента');
        expect(responses[0].data, equals('item-0'));
        expect(responses[1].data, equals('item-1'));
      } finally {
        // Всегда закрываем стрим
        await serverStream.close();
      }
    });
  });
}
