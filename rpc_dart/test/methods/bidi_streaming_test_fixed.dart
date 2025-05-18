// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';

import '../fixtures/test_contract.dart';

void main() {
  group('Тесты двунаправленного стриминга с использованием фикстур', () {
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

    test('Простой эхо-стрим', () async {
      print('Начинаем тест простого эхо-стрима');
      // Получаем двунаправленный стрим из контракта
      final bidiStream = clientContract.bidirectionalTests.echoStream();
      print('Получен двунаправленный стрим');

      // Используем completer для синхронизации, когда получим ответ
      final receivedResponse = Completer<BidirectionalResponse>();

      // Подписываемся на ответы
      final subscription = bidiStream.listen(
        (response) {
          print('Получен ответ: ${response.data}');
          // Если еще не получили ответ, завершаем Future
          if (!receivedResponse.isCompleted) {
            receivedResponse.complete(response);
          }
        },
        onError: (error) {
          print('Получена ошибка: $error');
          if (!receivedResponse.isCompleted) {
            receivedResponse.completeError(error);
          }
        },
      );

      // Отправляем сообщение
      print('Отправляем сообщение');
      bidiStream.send(BidirectionalRequest('test_message'));
      print('Сообщение отправлено');

      // Ждем ответа с таймаутом 10 секунд
      final response = await receivedResponse.future
          .timeout(const Duration(seconds: 10), onTimeout: () {
        print('Таймаут при ожидании ответа');
        throw TimeoutException('Не получен ответ от эхо-сервера');
      });

      // Проверяем ответ
      print('Ответ получен: ${response.data}');
      expect(response.data, equals('echo:test_message'));

      // Закрываем стрим и очищаем ресурсы
      print('Закрываем стрим');
      await bidiStream.close();
      print('Стрим закрыт');
      await subscription.cancel();
      print('Подписка отменена');
    });

    test('Трансформация сообщения', () async {
      print('Начинаем тест трансформации сообщения');
      // Получаем двунаправленный стрим для трансформации
      final bidiStream = clientContract.bidirectionalTests.transformStream();
      print('Получен двунаправленный стрим для трансформации');

      // Используем completer для ожидания ответа
      final receivedResponse = Completer<BidirectionalResponse>();

      // Подписываемся на ответы
      final subscription = bidiStream.listen(
        (response) {
          print('Получен ответ: ${response.data}');
          if (!receivedResponse.isCompleted) {
            receivedResponse.complete(response);
          }
        },
        onError: (error) {
          print('Получена ошибка: $error');
          if (!receivedResponse.isCompleted) {
            receivedResponse.completeError(error);
          }
        },
      );

      // Отправляем сообщение для трансформации
      print('Отправляем сообщение для трансформации');
      bidiStream.send(BidirectionalRequest('transform_me'));
      print('Сообщение отправлено');

      // Ждем ответа с таймаутом 10 секунд
      final response = await receivedResponse.future
          .timeout(const Duration(seconds: 10), onTimeout: () {
        print('Таймаут при ожидании ответа');
        throw TimeoutException('Не получен ответ при трансформации');
      });

      // Проверяем, что сообщение трансформировано в верхний регистр
      print('Ответ получен: ${response.data}');
      expect(response.data, equals('TRANSFORM_ME'));

      // Закрываем стрим и очищаем ресурсы
      print('Закрываем стрим');
      await bidiStream.close();
      print('Стрим закрыт');
      await subscription.cancel();
      print('Подписка отменена');
    });

    test('Обработка ошибок', () async {
      print('Начинаем тест обработки ошибок');
      // Получаем двунаправленный стрим для тестирования ошибок
      final bidiStream = clientContract.bidirectionalTests.errorStream();
      print('Получен двунаправленный стрим для тестирования ошибок');

      // Используем completer для ожидания ошибки
      final receivedError = Completer<dynamic>();

      // Подписываемся на ответы и ошибки
      final subscription = bidiStream.listen(
        (response) {
          // Получаем успешный ответ
          print('Получен ответ: ${response.data}');
        },
        onError: (error) {
          // Ожидаем ошибку
          print('Получена ошибка: $error');
          if (!receivedError.isCompleted) {
            receivedError.complete(error);
          }
        },
      );

      // Отправляем сообщение, которое вызовет ошибку
      print('Отправляем сообщение, вызывающее ошибку');
      bidiStream.send(BidirectionalRequest('error'));
      print('Сообщение отправлено');

      // Ждем ошибки с таймаутом 10 секунд
      final error = await receivedError.future
          .timeout(const Duration(seconds: 10), onTimeout: () {
        print('Таймаут при ожидании ошибки');
        throw TimeoutException('Не получена ошибка от сервера');
      });

      // Проверяем, что получили ошибку
      print('Ошибка получена: $error');
      expect(error, isNotNull);
      expect(error.toString(), contains('ошибка'));

      // Закрываем стрим и очищаем ресурсы
      print('Закрываем стрим');
      await bidiStream.close();
      print('Стрим закрыт');
      await subscription.cancel();
      print('Подписка отменена');
    });
  });
}
