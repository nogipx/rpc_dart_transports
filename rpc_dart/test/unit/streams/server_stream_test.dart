import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:rpc_dart/src_v2/rpc/_index.dart';

void main() {
  group('Server Stream', () {
    group('ServerStreamClient', () {
      test('отправляет_один_запрос_и_получает_множественные_ответы', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();
        final receivedRequests = <String>[];

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            receivedRequests.add(request);
            // Отправляем несколько ответов
            await responder.send('Response 1 for: $request');
            await responder.send('Response 2 for: $request');
            await responder.send('Response 3 for: $request');
            await responder.complete();
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedResponses = <String>[];
        final subscription = client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            receivedResponses.add(message.payload!);
          }
        });

        // Act
        await client.send('test request');

        // Ждем завершения потока
        await subscription.asFuture();

        // Assert
        expect(receivedResponses.length, equals(3));
        expect(receivedResponses[0], equals('Response 1 for: test request'));
        expect(receivedResponses[1], equals('Response 2 for: test request'));
        expect(receivedResponses[2], equals('Response 3 for: test request'));
        expect(receivedRequests.length, equals(1));
        expect(receivedRequests.first, equals('test request'));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_единственный_запрос_без_ответов', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            // Не отправляем ответов, только завершаем поток
            await responder.complete();
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        var streamCompleted = false;
        final completer = Completer<void>();
        final subscription = client.responses.listen(
          (message) {},
          onDone: () {
            streamCompleted = true;
            completer.complete();
          },
        );

        // Act
        await client.send('test request');

        // Ждем завершения потока с таймаутом
        await completer.future.timeout(Duration(milliseconds: 1000));

        // Assert
        expect(streamCompleted, isTrue);

        // Cleanup
        await subscription.cancel();
        await client.close();
        await server.close();
      });

      test('выбрасывает_исключение_при_ошибке_сервера', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            throw Exception('Server error');
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        var errorReceived = false;
        final completer = Completer<void>();
        final subscription = client.responses.listen(
          (message) {},
          onError: (error) {
            errorReceived = true;
            completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        // Act
        await client.send('test request');

        // Ждем ошибки или завершения с таймаутом
        await completer.future.timeout(Duration(milliseconds: 1000));

        // Assert
        expect(errorReceived, isTrue);

        // Cleanup
        await subscription.cancel();
        await client.close();
        await server.close();
      });

      test('завершает_поток_ответов_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            await responder.send('response1');
            await responder.send('response2');
            await responder.complete();
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        var streamCompleted = false;
        final completer = Completer<void>();
        final subscription = client.responses.listen(
          (message) {},
          onDone: () {
            streamCompleted = true;
            completer.complete();
          },
        );

        // Act
        await client.send('test request');

        // Ждем завершения потока с таймаутом
        await completer.future.timeout(Duration(milliseconds: 1000));

        // Assert
        expect(streamCompleted, isTrue);

        // Cleanup
        await subscription.cancel();
        await client.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            await responder.complete();
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act & Assert - должно закрыться без ошибок
        await client.close();
        await server.close();
      });
    });

    group('ServerStreamServer', () {
      test('получает_один_запрос_и_отправляет_множественные_ответы', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();
        final receivedRequests = <String>[];

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            receivedRequests.add(request);

            // Отправляем несколько ответов
            await responder.send('Response 1 for: $request');
            await responder.send('Response 2 for: $request');
            await responder.send('Response 3 for: $request');

            // Завершаем поток
            await responder.complete();
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedResponses = <String>[];
        final subscription = client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            receivedResponses.add(message.payload!);
          }
        });

        // Act
        await client.send('Hello Server');
        await subscription.asFuture();

        // Assert
        expect(receivedRequests.length, equals(1));
        expect(receivedRequests.first, equals('Hello Server'));
        expect(receivedResponses.length, equals(3));
        expect(receivedResponses[0], equals('Response 1 for: Hello Server'));
        expect(receivedResponses[1], equals('Response 2 for: Hello Server'));
        expect(receivedResponses[2], equals('Response 3 for: Hello Server'));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_исключение_в_обработчике', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            throw Exception('Handler error');
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        var errorReceived = false;
        final completer = Completer<void>();
        final subscription = client.responses.listen(
          (message) {},
          onError: (error) {
            errorReceived = true;
            completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        // Act
        await client.send('test request');

        // Ждем ошибки или завершения с таймаутом
        await completer.future.timeout(Duration(milliseconds: 1000));

        // Assert
        expect(errorReceived, isTrue);

        // Cleanup
        await subscription.cancel();
        await client.close();
        await server.close();
      });

      test('обрабатывает_только_запросы_своего_метода', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();
        var handlerCallCount = 0;

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            handlerCallCount++;
            await responder.complete();
          },
        );

        final correctClient = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final incorrectClient = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'DifferentMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        await correctClient.send('correct request');
        try {
          await incorrectClient.send('incorrect request');
        } catch (e) {
          // Может быть ошибка для неправильного метода
        }

        // Assert
        expect(handlerCallCount, equals(1));

        // Cleanup
        await correctClient.close();
        await incorrectClient.close();
        await server.close();
      });

      test('завершает_поток_с_ошибкой', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            await responder.send('First response');
            await responder.completeWithError(
                RpcStatus.INTERNAL, 'Test error message');
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        var errorReceived = false;
        final completer = Completer<void>();
        final subscription = client.responses.listen(
          (message) {},
          onError: (error) {
            errorReceived = true;
            completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        // Act
        await client.send('test request');

        // Ждем ошибки или завершения с таймаутом
        await completer.future.timeout(Duration(milliseconds: 1000));

        // Assert
        expect(errorReceived, isTrue);

        // Cleanup
        await subscription.cancel();
        await client.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final sut = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            await responder.complete();
          },
        );

        // Act & Assert - должно закрыться без ошибок
        await sut.close();
        await clientTransport.close();
      });
    });

    group('интеграционные тесты', () {
      test('полный_цикл_серверного_стриминга', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'NumberService',
          methodName: 'GenerateNumbers',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            final count = int.tryParse(request) ?? 3;
            for (int i = 1; i <= count; i++) {
              await responder.send('Number $i');
            }
            await responder.complete();
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'NumberService',
          methodName: 'GenerateNumbers',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedNumbers = <String>[];
        var streamCompleted = false;
        final completer = Completer<void>();

        final subscription = client.responses.listen(
          (message) {
            if (!message.isMetadataOnly && message.payload != null) {
              receivedNumbers.add(message.payload!);
            }
          },
          onDone: () {
            streamCompleted = true;
            completer.complete();
          },
        );

        // Act
        await client.send('5');

        // Ждем завершения потока с таймаутом
        await completer.future.timeout(Duration(milliseconds: 1000));

        // Assert
        expect(receivedNumbers.length, equals(5));
        expect(receivedNumbers[0], equals('Number 1'));
        expect(receivedNumbers[4], equals('Number 5'));
        expect(streamCompleted, isTrue);

        // Cleanup
        await subscription.cancel();
        await client.close();
        await server.close();
      });

      test('большое_количество_ответов', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ServerStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'StreamService',
          methodName: 'LargeStream',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            const responseCount = 50;
            for (int i = 0; i < responseCount; i++) {
              await responder.send('Response $i');
            }
            await responder.complete();
          },
        );

        final client = ServerStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'StreamService',
          methodName: 'LargeStream',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedResponses = <String>[];
        final subscription = client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            receivedResponses.add(message.payload!);
          }
        });

        // Act
        await client.send('start stream');
        await subscription.asFuture();

        // Assert
        expect(receivedResponses.length, equals(50));
        expect(receivedResponses.first, equals('Response 0'));
        expect(receivedResponses.last, equals('Response 49'));

        // Cleanup
        await client.close();
        await server.close();
      });
    });
  });
}

/// Простой сериализатор строк для тестов
class _TestStringSerializer implements IRpcSerializer<String> {
  @override
  String deserialize(Uint8List bytes) {
    return String.fromCharCodes(bytes);
  }

  @override
  Uint8List serialize(String message) {
    return Uint8List.fromList(message.codeUnits);
  }
}
