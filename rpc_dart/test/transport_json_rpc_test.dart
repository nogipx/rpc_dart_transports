// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('JsonRpcTransport', () {
    late MemoryTransport baseTransport1;
    late MemoryTransport baseTransport2;
    late JsonRpcTransport jsonRpcTransport1;
    late JsonRpcTransport jsonRpcTransport2;

    setUp(() {
      baseTransport1 = MemoryTransport('base1');
      baseTransport2 = MemoryTransport('base2');

      // Соединяем базовые транспорты между собой
      baseTransport1.connect(baseTransport2);
      baseTransport2.connect(baseTransport1);

      // Создаем транспорты JSON-RPC поверх базовых
      jsonRpcTransport1 = JsonRpcTransport('json1', baseTransport1);
      jsonRpcTransport2 = JsonRpcTransport('json2', baseTransport2);
    });

    tearDown(() async {
      await jsonRpcTransport1.close();
      await jsonRpcTransport2.close();
    });

    test('Должен конвертировать внутренние сообщения в формат JSON-RPC',
        () async {
      // Arrange
      final completer = Completer<Map<String, dynamic>>();

      // Подписываемся на базовый транспорт, чтобы получить сырое сообщение
      baseTransport2.receive().listen((data) {
        final jsonString = utf8.decode(data);
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        if (jsonData['method'] == 'example.test') {
          completer.complete(jsonData);
        }
      });

      // Act: отправляем внутреннее сообщение через JSON-RPC транспорт
      final message = RpcMessage(
        type: RpcMessageType.request,
        messageId: '123',
        serviceName: 'example',
        methodName: 'test',
        payload: {'a': 1, 'b': 2},
      );

      final jsonString = json.encode(message.toJson());
      await jsonRpcTransport1.send(utf8.encode(jsonString));

      // Assert: проверяем, что сообщение было преобразовано в формат JSON-RPC
      final receivedJson = await completer.future;

      expect(receivedJson['jsonrpc'], equals('2.0'));
      expect(receivedJson['method'], equals('example.test'));
      expect(receivedJson['params'], equals({'a': 1, 'b': 2}));
      expect(receivedJson['id'], equals('123'));
    });

    test('Должен конвертировать сообщения JSON-RPC во внутренний формат',
        () async {
      // Arrange
      final completer = Completer<RpcMessage>();

      // Подписываемся на JSON-RPC транспорт
      jsonRpcTransport2.receive().listen((data) {
        final jsonString = utf8.decode(data);
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        final message = RpcMessage.fromJson(jsonData);
        if (message.methodName == 'test' && message.serviceName == 'example') {
          completer.complete(message);
        }
      });

      // Act: отправляем сообщение JSON-RPC через базовый транспорт
      final jsonRpcMessage = {
        'jsonrpc': '2.0',
        'method': 'example.test',
        'params': {'a': 1, 'b': 2},
        'id': '123',
      };

      final jsonString = json.encode(jsonRpcMessage);
      await baseTransport1.send(utf8.encode(jsonString));

      // Assert: проверяем, что сообщение было преобразовано во внутренний формат
      final receivedMessage = await completer.future;

      expect(receivedMessage.type, equals(RpcMessageType.request));
      expect(receivedMessage.serviceName, equals('example'));
      expect(receivedMessage.methodName, equals('test'));
      expect(receivedMessage.payload, equals({'a': 1, 'b': 2}));
      expect(receivedMessage.messageId, equals('123'));
    });

    test('Должен обрабатывать ошибки в формате JSON-RPC', () async {
      // Arrange
      final completer = Completer<Map<String, dynamic>>();

      // Подписываемся на базовый транспорт
      baseTransport2.receive().listen((data) {
        final jsonString = utf8.decode(data);
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        if (jsonData.containsKey('error')) {
          completer.complete(jsonData);
        }
      });

      // Act: отправляем сообщение с ошибкой через JSON-RPC транспорт
      final message = RpcMessage(
        type: RpcMessageType.error,
        messageId: '123',
        payload: {
          'code': 'invalidArgument',
          'message': 'Неверные аргументы',
          'details': {'param': 'a', 'expected': 'number'},
        },
      );

      final jsonString = json.encode(message.toJson());
      await jsonRpcTransport1.send(utf8.encode(jsonString));

      // Assert: проверяем, что ошибка была преобразована в формат JSON-RPC
      final receivedJson = await completer.future;

      expect(receivedJson['jsonrpc'], equals('2.0'));
      expect(receivedJson['id'], equals('123'));
      expect(receivedJson['error'], isA<Map<String, dynamic>>());
      expect(receivedJson['error']['code'],
          equals(JsonRpcErrorCode.invalidParams));
      expect(receivedJson['error']['message'], equals('Неверные аргументы'));
      expect(receivedJson['error']['data'], isA<Map<String, dynamic>>());
    });

    /// Интеграционный тест для проверки полного цикла запрос-ответ
    test('Должен успешно выполнять полный цикл запрос-ответ с RpcEndpoint',
        () async {
      // Создаем клиент и сервер с JSON сериализатором
      final client = RpcEndpoint(
        serializer: const JsonSerializer(),
        transport: jsonRpcTransport1,
        debugLabel: 'test-client',
      );

      final server = RpcEndpoint(
        serializer: const JsonSerializer(),
        transport: jsonRpcTransport2,
        debugLabel: 'test-server',
      );

      // Регистрируем метод на сервере
      server.registerMethod(
        serviceName: 'math',
        methodName: 'add',
        handler: (context) async {
          if (context.payload is! Map<String, dynamic>) {
            throw RpcInvalidArgumentException(
              'Invalid arguments',
              details: {'expected': 'Map with a and b fields'},
            );
          }

          final data = context.payload as Map<String, dynamic>;
          if (data['a'] is! num || data['b'] is! num) {
            throw RpcInvalidArgumentException(
              'Invalid arguments',
              details: {'expected': 'a and b must be numbers'},
            );
          }

          final a = data['a'] as num;
          final b = data['b'] as num;

          // Возвращаем правильный тип (RpcMessage)
          return RpcMessage(
            type: RpcMessageType.response,
            messageId: context.messageId,
            serviceName: 'math',
            methodName: 'add',
            payload: {'result': a + b},
          );
        },
        methodType: RpcMethodType.unary,
        argumentParser: (Map<String, dynamic> data) => RpcMessage(
          type: RpcMessageType.request,
          messageId: 'test',
          payload: data,
        ),
        responseParser: (Map<String, dynamic> data) => RpcMessage(
          type: RpcMessageType.response,
          messageId: 'test',
          payload: data,
        ),
      );

      try {
        // Вызываем метод и ожидаем результат
        final result = await client.invoke(
          serviceName: 'math',
          methodName: 'add',
          request: {'a': 10, 'b': 20},
        );

        // Проверяем, что результат был получен правильно
        expect(result, isA<Map<String, dynamic>>());
        // Результат теперь находится внутри fields[payload][result]
        if (result is Map && result['payload'] is Map) {
          final payload = result['payload'] as Map<String, dynamic>;
          expect(payload['result'], equals(30));
        } else {
          fail('Ожидался структурированный ответ с payload');
        }

        // Проверяем обработку ошибки
        try {
          await client.invoke(
            serviceName: 'math',
            methodName: 'add',
            request: {'a': 'not a number', 'b': 20},
          );
          fail('Должно было выбросить исключение');
        } catch (e) {
          // Ожидаем ошибку с неверными аргументами
          expect(e, isA<Exception>());
          final errorString = e.toString();
          expect(errorString, contains('Invalid arguments'));
        }
      } finally {
        // Освобождаем ресурсы
        await client.close();
        await server.close();
      }
    });
  });
}
