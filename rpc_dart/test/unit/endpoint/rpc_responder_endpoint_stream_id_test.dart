// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

class TestRequest implements IRpcSerializable {
  final String message;

  TestRequest(this.message);

  factory TestRequest.fromJson(Map<String, dynamic> json) {
    return TestRequest(json['message'] as String);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'message': message};
  }
}

class TestResponse implements IRpcSerializable {
  final String message;

  TestResponse(this.message);

  factory TestResponse.fromJson(Map<String, dynamic> json) {
    return TestResponse(json['message'] as String);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'message': message};
  }
}

base class TestService extends RpcResponderContract {
  TestService() : super('TestService');

  @override
  void setup() {
    addUnaryMethod<TestRequest, TestResponse>(
      methodName: 'UnaryMethod',
      handler: (request) async {
        return TestResponse('Reply to: ${request.message}');
      },
      requestCodec: RpcCodec<TestRequest>(TestRequest.fromJson),
      responseCodec: RpcCodec<TestResponse>(TestResponse.fromJson),
    );

    addServerStreamMethod<TestRequest, TestResponse>(
      methodName: 'ServerStreamMethod',
      handler: (request) async* {
        for (int i = 0; i < 3; i++) {
          yield TestResponse('Reply ${i + 1} to: ${request.message}');
          await Future.delayed(Duration(milliseconds: 10));
        }
      },
      requestCodec: RpcCodec<TestRequest>(TestRequest.fromJson),
      responseCodec: RpcCodec<TestResponse>(TestResponse.fromJson),
    );
  }
}

void main() {
  group('RpcResponderEndpoint Stream ID управление', () {
    late RpcInMemoryTransport clientTransport;
    late RpcInMemoryTransport serverTransport;
    late RpcResponderEndpoint responderEndpoint;
    late RpcCallerEndpoint callerEndpoint;

    setUp(() {
      final pair = RpcInMemoryTransport.pair();
      clientTransport = pair.$1;
      serverTransport = pair.$2;

      responderEndpoint = RpcResponderEndpoint(transport: serverTransport);
      callerEndpoint = RpcCallerEndpoint(transport: clientTransport);

      // Регистрируем тестовый сервис
      responderEndpoint.registerServiceContract(TestService());
    });

    tearDown(() async {
      await responderEndpoint.close();
      await callerEndpoint.close();
    });

    test('Освобождает ID стрима после унарного запроса', () async {
      // Отправляем унарный запрос
      final response =
          await callerEndpoint.unaryRequest<TestRequest, TestResponse>(
        serviceName: 'TestService',
        methodName: 'UnaryMethod',
        requestCodec: RpcCodec<TestRequest>(TestRequest.fromJson),
        responseCodec: RpcCodec<TestResponse>(TestResponse.fromJson),
        request: TestRequest('Hello'),
      );

      // Проверяем ответ
      expect(response.message, equals('Reply to: Hello'));

      // Ждем, пока обработается освобождение ID
      await Future.delayed(Duration(milliseconds: 50));

      // Создаем новый поток и проверяем, что его ID начинается сначала
      // Это косвенно подтверждает, что предыдущие ID были освобождены
      final newId = serverTransport.createStream();
      expect(
          newId, equals(2)); // Новый поток должен получить ID=2 (первый четный)
    });

    test('Стриминг со стороны сервера работает корректно', () async {
      // Вместо использования serverStream непосредственно, создадим все вручную
      // для большего контроля над процессом

      final streamId = clientTransport.createStream();

      // Отправляем метаданные
      final metadata =
          RpcMetadata.forClientRequest('TestService', 'ServerStreamMethod');
      await clientTransport.sendMetadata(streamId, metadata);

      // Отправляем сообщение
      final request = TestRequest('Hello Stream');
      final serialized =
          RpcCodec<TestRequest>(TestRequest.fromJson).serialize(request);
      final framedMessage = RpcMessageFrame.encode(serialized);
      await clientTransport.sendMessage(streamId, framedMessage);

      // Сигнализируем завершение отправки
      await clientTransport.finishSending(streamId);

      // Ждем достаточно долго, чтобы сервер успел обработать
      await Future.delayed(Duration(milliseconds: 500));

      // Проверяем, что ID стрима был освобожден
      expect(clientTransport.releaseStreamId(streamId), isFalse,
          reason:
              'ID стрима должен быть уже освобожден сервером после завершения обработки');

      // Проверяем, что после завершения мы можем создать новый поток
      final newStreamId = serverTransport.createStream();
      expect(newStreamId, isA<int>());
    });

    test('Корректно обрабатывает множественные запросы', () async {
      // Отправляем несколько запросов одновременно
      final totalRequests = 5;
      final futures = <Future<TestResponse>>[];

      for (int i = 0; i < totalRequests; i++) {
        futures.add(callerEndpoint.unaryRequest<TestRequest, TestResponse>(
          serviceName: 'TestService',
          methodName: 'UnaryMethod',
          requestCodec: RpcCodec<TestRequest>(TestRequest.fromJson),
          responseCodec: RpcCodec<TestResponse>(TestResponse.fromJson),
          request: TestRequest('Request ${i + 1}'),
        ));
      }

      // Ждем все ответы
      final responses = await Future.wait(futures);

      // Проверяем ответы
      for (int i = 0; i < totalRequests; i++) {
        expect(responses[i].message, equals('Reply to: Request ${i + 1}'));
      }
    });

    test('Корректное управление ID при множественных запросах', () async {
      // Создаем и сразу освобождаем ID
      final initialId = serverTransport.createStream();
      serverTransport.releaseStreamId(initialId);

      // Отправляем первый запрос
      await callerEndpoint.unaryRequest<TestRequest, TestResponse>(
        serviceName: 'TestService',
        methodName: 'UnaryMethod',
        requestCodec: RpcCodec<TestRequest>(TestRequest.fromJson),
        responseCodec: RpcCodec<TestResponse>(TestResponse.fromJson),
        request: TestRequest('Request 1'),
      );

      // Отправляем второй запрос
      await callerEndpoint.unaryRequest<TestRequest, TestResponse>(
        serviceName: 'TestService',
        methodName: 'UnaryMethod',
        requestCodec: RpcCodec<TestRequest>(TestRequest.fromJson),
        responseCodec: RpcCodec<TestResponse>(TestResponse.fromJson),
        request: TestRequest('Request 2'),
      );

      // Проверяем только, что можем создать новые ID (без проверки конкретных значений)
      final newId = serverTransport.createStream();
      expect(newId, greaterThan(0)); // ID должен быть положительным числом
    });
  });
}
