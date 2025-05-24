import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:rpc_dart/src_v2/rpc/_index.dart';

void main() {
  group('Client Stream', () {
    group('ClientStreamClient', () {
      test('отправляет_несколько_запросов_и_получает_один_ответ', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();
        final receivedRequests = <String>[];

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async {
            await for (final request in requests) {
              receivedRequests.add(request);
            }
            return 'Processed ${receivedRequests.length} requests: ${receivedRequests.join(", ")}';
          },
        );

        final client = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final testRequests = ['request1', 'request2', 'request3'];

        // Act
        for (final request in testRequests) {
          await client.send(request);
        }
        final response = await client.finishSending();

        // Assert
        expect(response,
            equals('Processed 3 requests: request1, request2, request3'));
        expect(receivedRequests, equals(testRequests));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_пустой_поток_запросов', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async {
            var count = 0;
            await for (final _ in requests) {
              count++;
            }
            return 'Processed $count requests';
          },
        );

        final client = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Processed 0 requests'));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('выбрасывает_исключение_при_ошибке_сервера', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async {
            // Сразу выбрасываем исключение без обработки stream
            throw Exception('Server processing error');
          },
        );

        final client = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act & Assert
        await client.send('test request');

        // Используем expectLater с коротким таймаутом
        await expectLater(
          client.finishSending().timeout(Duration(seconds: 2)),
          throwsA(isA<Exception>()),
        );

        // Cleanup
        await client.close();
        await server.close();
      });

      test('отправляет_запросы_в_правильном_порядке', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();
        final receivedRequests = <String>[];

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async {
            await for (final request in requests) {
              receivedRequests.add(request);
            }
            return 'Ordered: ${receivedRequests.join(", ")}';
          },
        );

        final client = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final orderedRequests = ['first', 'second', 'third'];

        // Act
        for (final request in orderedRequests) {
          await client.send(request);
        }
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Ordered: first, second, third'));
        expect(receivedRequests, equals(orderedRequests));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async => 'test',
        );

        final client = ClientStreamClient<String, String>(
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

    group('ClientStreamServer', () {
      test('получает_поток_запросов_и_отправляет_один_ответ', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();
        final receivedRequests = <String>[];

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async {
            await for (final request in requests) {
              receivedRequests.add(request);
            }
            return 'Processed ${receivedRequests.length} requests';
          },
        );

        final client = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        await client.send('Hello');
        await client.send('World');
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Processed 2 requests'));
        expect(receivedRequests, equals(['Hello', 'World']));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_исключение_в_обработчике', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async {
            throw Exception('Handler error');
          },
        );

        final client = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act & Assert
        await client.send('test');
        await expectLater(
          client.finishSending().timeout(Duration(seconds: 2)),
          throwsA(isA<Exception>()),
        );

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_только_запросы_своего_метода', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();
        var handlerCallCount = 0;

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async {
            handlerCallCount++;
            await for (final _ in requests) {}
            return 'response';
          },
        );

        final correctClient = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final incorrectClient = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'DifferentMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        await correctClient.send('correct');
        final correctResponse = await correctClient.finishSending();

        await incorrectClient.send('incorrect');
        try {
          await incorrectClient.finishSending().timeout(Duration(seconds: 2));
        } catch (e) {
          // Ожидаем ошибку для неправильного метода
        }

        // Assert
        expect(handlerCallCount, equals(1));
        expect(correctResponse, equals('response'));

        // Cleanup
        await correctClient.close();
        await incorrectClient.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final sut = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async => 'response',
        );

        // Act & Assert - должно закрыться без ошибок
        await sut.close();
        await clientTransport.close();
      });
    });

    group('интеграционные тесты', () {
      test('полный_цикл_клиентского_стриминга', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'AggregatorService',
          methodName: 'Aggregate',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async {
            final allRequests = <String>[];
            await for (final request in requests) {
              allRequests.add(request);
            }
            return 'Aggregated: ${allRequests.join(', ')}';
          },
        );

        final client = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'AggregatorService',
          methodName: 'Aggregate',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        final requests = ['Part1', 'Part2', 'Part3'];
        for (final request in requests) {
          await client.send(request);
        }
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Aggregated: Part1, Part2, Part3'));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('большое_количество_запросов', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = ClientStreamServer<String, String>(
          transport: serverTransport,
          serviceName: 'CounterService',
          methodName: 'Count',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (Stream<String> requests) async {
            var count = 0;
            await for (final _ in requests) {
              count++;
            }
            return 'Total count: $count';
          },
        );

        final client = ClientStreamClient<String, String>(
          transport: clientTransport,
          serviceName: 'CounterService',
          methodName: 'Count',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        const requestCount = 100;
        for (int i = 0; i < requestCount; i++) {
          await client.send('request_$i');
        }
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Total count: $requestCount'));

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
