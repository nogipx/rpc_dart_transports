// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';

import '../fixtures/test_contract.dart';

void main() {
  group('Тесты серверного стриминга с использованием фикстур', () {
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
      print('Тесты настроены успешно');
    });

    tearDown(() async {
      // Закрываем эндпоинты
      print('Закрываем эндпоинты');
      await clientEndpoint.close();
      await serverEndpoint.close();
      print('Эндпоинты закрыты');
    });

    test('Генерация элементов', () async {
      print('Начинаем тест генерации элементов');

      // Создаем запрос для получения 3 элементов
      final request = ServerStreamRequest('3');
      print('Создан запрос: $request');

      // Получаем стрим из контракта
      final stream = clientContract.serverStreamingTests.generateItems(request);
      print('Получен серверный стрим');

      // Сокращаем таймаут для теста
      const timeout = Duration(seconds: 2);

      // Получаем все элементы из стрима - ожидаем максимум 3 элемента
      final results = await stream.take(3).timeout(
        timeout,
        onTimeout: (sink) {
          print('Таймаут при ожидании элементов');
          sink.close();
        },
      ).toList();

      // Выводим полученные результаты
      print(
          'Получено ${results.length} элементов: ${results.map((r) => r.data).join(', ')}');

      // Проверяем результаты
      expect(results.length, equals(3));
      expect(results[0].data, equals('item-0'));
      expect(results[1].data, equals('item-1'));
      expect(results[2].data, equals('item-2'));
    });

    test('Эхо-сервис', () async {
      print('Начинаем тест эхо-сервиса');

      // Создаем запрос для эхо
      final request = ServerStreamRequest('hello_echo');
      print('Создан запрос: $request');

      // Получаем стрим из контракта
      final stream = clientContract.serverStreamingTests.echoStream(request);
      print('Получен серверный стрим для эхо');

      // Сокращаем таймаут для теста
      const timeout = Duration(seconds: 2);

      // Получаем первый элемент из стрима
      final result = await stream.first.timeout(
        timeout,
        onTimeout: () {
          print('Таймаут при ожидании эхо-ответа');
          throw TimeoutException('Не получен эхо-ответ от сервера');
        },
      );

      print('Получен эхо-ответ: ${result.data}');

      // Проверяем результат
      expect(result.data, equals('hello_echo'));
    });

    test('Обработка ошибок', () async {
      print('Начинаем тест обработки ошибок');

      // Создаем запрос, который вызовет ошибку
      final request = ServerStreamRequest('error');
      print('Создан запрос с ошибкой: $request');

      // Получаем стрим из контракта
      final stream = clientContract.serverStreamingTests.errorStream(request);
      print('Получен серверный стрим для теста ошибок');

      // Сокращаем таймаут для теста
      const timeout = Duration(seconds: 2);

      // Ожидаем ошибку при прослушивании стрима
      try {
        await stream.first.timeout(
          timeout,
          onTimeout: () {
            print('Таймаут при ожидании ошибки');
            throw TimeoutException('Не получена ошибка от сервера');
          },
        );

        // Если дошли сюда, что-то пошло не так
        fail('Ожидалась ошибка, но получен результат');
      } catch (e) {
        // Проверяем, что это не таймаут, а ожидаемая ошибка
        if (e is TimeoutException) {
          rethrow;
        }

        print('Получена ожидаемая ошибка: $e');
        expect(e.toString(), contains('ошибка'));
      }
    });
  });
}
