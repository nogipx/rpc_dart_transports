import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Server Stream', () {
    final serializer = binaryStringSerializer;

    group('ServerStreamClient', () {
      test('отправляет_один_запрос_и_получает_множественные_ответы', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final receivedRequests = <RpcString>[];

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            receivedRequests.add(request);
            // Отправляем несколько ответов
            await responder.send('Response 1 for: $request'.rpc);
            await responder.send('Response 2 for: $request'.rpc);
            await responder.send('Response 3 for: $request'.rpc);
            await responder.complete();
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedResponses = <RpcString>[];
        final subscription = client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            receivedResponses.add(message.payload!);
          }
        });

        // Act
        await client.send('test request'.rpc);

        // Ждем завершения потока
        await subscription.asFuture();

        // Assert
        expect(receivedResponses.length, equals(3));
        expect(
            receivedResponses[0], equals('Response 1 for: test request'.rpc));
        expect(
            receivedResponses[1], equals('Response 2 for: test request'.rpc));
        expect(
            receivedResponses[2], equals('Response 3 for: test request'.rpc));
        expect(receivedRequests.length, equals(1));
        expect(receivedRequests.first, equals('test request'.rpc));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_единственный_запрос_без_ответов', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        final server = ServerStreamResponder<RpcString, RpcString>(
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

        final client = ServerStreamCaller<RpcString, RpcString>(
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
        await client.send('test request'.rpc);

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

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            throw Exception('Server error');
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
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
        await client.send('test request'.rpc);

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

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            await responder.send('response1'.rpc);
            await responder.send('response2'.rpc);
            await responder.complete();
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
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
        await client.send('test request'.rpc);

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

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            await responder.complete();
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
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
        final receivedRequests = <RpcString>[];

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            receivedRequests.add(request);

            // Отправляем несколько ответов
            await responder.send('Response 1 for: $request'.rpc);
            await responder.send('Response 2 for: $request'.rpc);
            await responder.send('Response 3 for: $request'.rpc);

            // Завершаем поток
            await responder.complete();
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedResponses = <RpcString>[];
        final subscription = client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            receivedResponses.add(message.payload!);
          }
        });

        // Act
        await client.send('Hello Server'.rpc);
        await subscription.asFuture();

        // Assert
        expect(receivedRequests.length, equals(1));
        expect(receivedRequests.first, equals('Hello Server'.rpc));
        expect(receivedResponses.length, equals(3));
        expect(
            receivedResponses[0], equals('Response 1 for: Hello Server'.rpc));
        expect(
            receivedResponses[1], equals('Response 2 for: Hello Server'.rpc));
        expect(
            receivedResponses[2], equals('Response 3 for: Hello Server'.rpc));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_исключение_в_обработчике', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            throw Exception('Handler error');
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
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
        await client.send('test request'.rpc);

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
        var handlerCallCount = 0;

        final server = ServerStreamResponder<RpcString, RpcString>(
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

        final correctClient = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final incorrectClient = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'DifferentMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        await correctClient.send('correct request'.rpc);
        try {
          await incorrectClient.send('incorrect request'.rpc);
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

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            await responder.send('First response'.rpc);
            await responder.completeWithError(
                RpcStatus.INTERNAL, 'Test error message');
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
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
        await client.send('test request'.rpc);

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

        final sut = ServerStreamResponder<RpcString, RpcString>(
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

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'NumberService',
          methodName: 'GenerateNumbers',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            final count = int.tryParse(request.value) ?? 3;
            for (int i = 1; i <= count; i++) {
              await responder.send('Number $i'.rpc);
            }
            await responder.complete();
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'NumberService',
          methodName: 'GenerateNumbers',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedNumbers = <RpcString>[];
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
        await client.send('5'.rpc);

        // Ждем завершения потока с таймаутом
        await completer.future.timeout(Duration(milliseconds: 1000));

        // Assert
        expect(receivedNumbers.length, equals(5));
        expect(receivedNumbers[0], equals('Number 1'.rpc));
        expect(receivedNumbers[4], equals('Number 5'.rpc));
        expect(streamCompleted, isTrue);

        // Cleanup
        await subscription.cancel();
        await client.close();
        await server.close();
      });

      test('большое_количество_ответов', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'StreamService',
          methodName: 'LargeStream',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request, responder) async {
            const responseCount = 50;
            for (int i = 0; i < responseCount; i++) {
              await responder.send('Response $i'.rpc);
            }
            await responder.complete();
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'StreamService',
          methodName: 'LargeStream',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedResponses = <RpcString>[];
        final subscription = client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            receivedResponses.add(message.payload!);
          }
        });

        // Act
        await client.send('start stream'.rpc);
        await subscription.asFuture();

        // Assert
        expect(receivedResponses.length, equals(50));
        expect(receivedResponses.first, equals('Response 0'.rpc));
        expect(receivedResponses.last, equals('Response 49'.rpc));

        // Cleanup
        await client.close();
        await server.close();
      });
    });
  });
}
