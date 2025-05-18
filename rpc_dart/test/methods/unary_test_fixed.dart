// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';

import '../fixtures/test_contract.dart';

void main() {
  group('Тесты унарных методов с использованием фикстур', () {
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

    test('Эхо-запрос', () async {
      print('Начинаем тест эхо-запроса');

      // Отправляем запрос
      print('Отправляем запрос');
      final response = await clientContract.unaryTests
          .echoUnary(UnaryRequest('hello_world'));

      print('Получен ответ: ${response.data}');

      // Проверяем, что получили эхо
      expect(response.data, equals('hello_world'));
    });

    test('Простой унарный запрос', () async {
      print('Начинаем тест простого унарного запроса');

      // Отправляем запрос
      print('Отправляем запрос');
      final response = await clientContract.unaryTests
          .simpleUnary(UnaryRequest('test_data'));

      print('Получен ответ: ${response.data}');

      // Проверяем результат
      expect(response.data, equals('unary:test_data'));
    });

    test('Запрос с задержкой', () async {
      print('Начинаем тест запроса с задержкой');

      // Отправляем запрос с задержкой 100мс
      print('Отправляем запрос с задержкой');
      final response =
          await clientContract.unaryTests.delayedUnary(UnaryRequest('100'));

      print('Получен ответ: ${response.data}');

      // Проверяем результат
      expect(response.data, contains('delayed:100'));
    });

    test('Обработка ошибки', () async {
      print('Начинаем тест обработки ошибки');

      // Отправляем запрос, который должен вызвать ошибку
      print('Отправляем запрос с ошибкой');

      // Ожидаем исключение
      try {
        await clientContract.unaryTests.errorUnary(UnaryRequest('test_error'));

        // Если дошли сюда, тест должен провалиться
        fail('Ожидалась ошибка, но метод выполнился успешно');
      } catch (error) {
        print('Получена ожидаемая ошибка: $error');

        // Проверяем, что ошибка содержит ожидаемое сообщение
        expect(error.toString(), contains('ошибка'));
      }
    });
  });
}
