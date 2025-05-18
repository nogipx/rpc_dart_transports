// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';

import '../fixtures/test_contract.dart';

void main() {
  group('Тесты клиентского стриминга с использованием фикстур', () {
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

    test('Сбор данных в одну строку', () async {
      print('Начинаем тест сбора данных');

      // Получаем стрим для отправки данных
      final clientStream = clientContract.clientStreamingTests.collectData();
      print('Получен клиентский стрим');

      // Отправляем сообщения
      print('Отправляем сообщения');
      clientStream.send(ClientStreamRequest('часть 1'));
      clientStream.send(ClientStreamRequest('часть 2'));
      clientStream.send(ClientStreamRequest('часть 3'));
      print('Сообщения отправлены');

      // Закрываем отправку
      print('Закрываем отправку');
      await clientStream.close();
      print('Отправка закрыта');

      // Получаем финальный ответ от сервера
      print('Ожидаем ответ от сервера');
      final response = await clientStream.getResponse().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Таймаут при ожидании ответа');
          throw TimeoutException('Не получен ответ от сервера');
        },
      );

      print('Получен ответ: ${response?.data}');

      // Проверяем, что ответ содержит все части
      expect(response, isNotNull);
      expect(response!.data, contains('часть 1'));
      expect(response.data, contains('часть 2'));
      expect(response.data, contains('часть 3'));
    });

    test('Подсчет элементов', () async {
      print('Начинаем тест подсчета элементов');

      // Получаем стрим для отправки данных
      final clientStream = clientContract.clientStreamingTests.countItems();
      print('Получен клиентский стрим');

      // Устанавливаем количество сообщений
      const messageCount = 5;

      // Отправляем сообщения
      print('Отправляем $messageCount сообщений');
      for (var i = 0; i < messageCount; i++) {
        clientStream.send(ClientStreamRequest('элемент $i'));
      }
      print('Сообщения отправлены');

      // Закрываем отправку
      print('Закрываем отправку');
      await clientStream.close();
      print('Отправка закрыта');

      // Получаем финальный ответ от сервера
      print('Ожидаем ответ от сервера');
      final response = await clientStream.getResponse().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Таймаут при ожидании ответа');
          throw TimeoutException('Не получен ответ от сервера');
        },
      );

      print('Получен ответ: ${response?.data}');

      // Проверяем, что ответ содержит правильное количество
      expect(response, isNotNull);
      expect(response!.data, equals('count:$messageCount'));
    });

    test('Обработка ошибок', () async {
      print('Начинаем тест обработки ошибок');

      // Получаем стрим
      final clientStream = clientContract.clientStreamingTests.errorStream();
      print('Получен клиентский стрим');

      // Отправляем сообщение, которое вызовет ошибку
      print('Отправляем сообщение, вызывающее ошибку');
      clientStream.send(ClientStreamRequest('error'));
      print('Сообщение отправлено');

      // Ожидаем ошибку при получении ответа
      print('Ожидаем ошибку от сервера');

      await expectLater(
        () => clientStream.getResponse().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('Таймаут при ожидании ошибки');
            throw TimeoutException('Не получена ошибка от сервера');
          },
        ),
        throwsA(anything),
        reason: 'Ожидалась ошибка от сервера',
      );
    });
  });
}
