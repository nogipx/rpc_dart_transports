// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('ProxyTransport Tests', () {
    late StreamController<dynamic> incomingController;
    late List<Uint8List> sentMessages;
    late ProxyTransport transport;
    const String transportId = 'test-proxy-transport';

    setUp(() {
      incomingController = StreamController<dynamic>.broadcast();
      sentMessages = [];

      // Функция для отправки данных, которая складывает сообщения в список
      Future<void> sendFunction(Uint8List data) async {
        sentMessages.add(data);
      }

      // Создаем экземпляр транспорта
      transport = ProxyTransport(
        id: transportId,
        incomingStream: incomingController.stream,
        sendFunction: sendFunction,
      );
    });

    tearDown(() async {
      await transport.close();
      await incomingController.close();
    });

    test('should have the correct id', () {
      expect(transport.id, equals(transportId));
    });

    test('should be available after creation', () {
      expect(transport.isAvailable, isTrue);
    });

    test('should send data through send function', () async {
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final status = await transport.send(testData);

      expect(status, equals(RpcTransportActionStatus.success));
      expect(sentMessages.length, equals(1));
      expect(sentMessages.first, equals(testData));
    });

    test('should receive data from the incoming stream (Uint8List)', () async {
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Ожидаем получения данных
      final receiveFuture = transport.receive().first;

      // Отправляем данные в поток
      incomingController.add(testData);

      // Проверяем, что данные были получены
      final receivedData = await receiveFuture;
      expect(receivedData, equals(testData));
    });

    test('should receive data from the incoming stream (List<int>)', () async {
      final testData = [1, 2, 3, 4, 5];

      // Ожидаем получения данных
      final receiveFuture = transport.receive().first;

      // Отправляем данные в поток
      incomingController.add(testData);

      // Проверяем, что данные были получены
      final receivedData = await receiveFuture;
      expect(receivedData, equals(Uint8List.fromList(testData)));
    });

    test('should receive data from the incoming stream (String)', () async {
      final testString = 'test message';
      final testDataBytes = Uint8List.fromList(utf8.encode(testString));

      // Ожидаем получения данных
      final receiveFuture = transport.receive().first;

      // Отправляем данные в поток
      incomingController.add(testString);

      // Проверяем, что данные были получены
      final receivedData = await receiveFuture;
      expect(receivedData, equals(testDataBytes));
    });

    test('should not be available after closing', () async {
      expect(transport.isAvailable, isTrue);

      final status = await transport.close();

      expect(status, equals(RpcTransportActionStatus.success));
      expect(transport.isAvailable, isFalse);
    });

    test('should handle send errors', () async {
      // Создаем транспорт с функцией, которая выбрасывает исключение
      final errorTransport = ProxyTransport(
        id: 'error-transport',
        incomingStream: incomingController.stream,
        sendFunction: (data) => throw Exception('Send error'),
      );

      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Вызываем метод send, который должен вызвать handleUncaughtError
      final status = await errorTransport.send(testData);

      expect(status, equals(RpcTransportActionStatus.unknownError));

      await errorTransport.close();

      expect(errorTransport.isAvailable, isFalse);
    });

    test('should handle timeout errors', () async {
      // Создаем транспорт с очень коротким таймаутом
      final timeoutTransport = ProxyTransport(
        id: 'timeout-transport',
        incomingStream: incomingController.stream,
        sendFunction: (data) async {
          // Имитируем долгую операцию
          await Future.delayed(const Duration(milliseconds: 100));
          sentMessages.add(data);
        },
        timeout: const Duration(milliseconds: 10),
      );

      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final status = await timeoutTransport.send(testData);

      expect(status, equals(RpcTransportActionStatus.timeoutError));

      await timeoutTransport.close();
    });

    test('should propagate errors from incoming stream', () async {
      final testError = Exception('Test error');

      // Ожидаем ошибку в потоке
      expect(
        transport.receive(),
        emitsError(
            predicate((e) => e.toString().contains(testError.toString()))),
      );

      // Отправляем ошибку в поток
      incomingController.addError(testError);
    });

    test('should return transportUnavailable when transport is closed',
        () async {
      await transport.close();

      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final status = await transport.send(testData);

      expect(status, equals(RpcTransportActionStatus.transportUnavailable));
    });
  });
}
