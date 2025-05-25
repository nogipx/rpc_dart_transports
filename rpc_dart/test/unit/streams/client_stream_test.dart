import 'dart:async';
import 'dart:typed_data';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/src/contracts/_index.dart';
import 'package:test/test.dart';
import 'package:rpc_dart/src/rpc/_index.dart';

void main() {
  group('Client Stream', () {
    group('ClientStreamClient', () {
      test('отправляет_несколько_запросов_и_получает_один_ответ', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final receivedRequests = <RpcString>[];

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async {
            await for (final request in requests) {
              receivedRequests.add(request);
            }
            return 'Processed ${receivedRequests.length} requests: ${receivedRequests.join(", ")}'
                .rpc;
          },
        );

        final client = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        final testRequests = ['request1'.rpc, 'request2'.rpc, 'request3'.rpc];

        // Act
        for (final request in testRequests) {
          await client.send(request);
        }
        final response = await client.finishSending();

        // Assert
        expect(response,
            equals('Processed 3 requests: request1, request2, request3'.rpc));
        expect(receivedRequests, equals(testRequests));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_пустой_поток_запросов', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async {
            var count = 0;
            await for (final _ in requests) {
              count++;
            }
            return 'Processed $count requests'.rpc;
          },
        );

        final client = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        // Act
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Processed 0 requests'.rpc));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('выбрасывает_исключение_при_ошибке_сервера', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async {
            // Сразу выбрасываем исключение без обработки stream
            throw Exception('Server processing error');
          },
        );

        final client = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        // Act & Assert
        await client.send('test request'.rpc);

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
        final receivedRequests = <RpcString>[];

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async {
            await for (final request in requests) {
              receivedRequests.add(request);
            }
            return 'Ordered: ${receivedRequests.join(", ")}'.rpc;
          },
        );

        final client = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        final orderedRequests = ['first'.rpc, 'second'.rpc, 'third'.rpc];

        // Act
        for (final request in orderedRequests) {
          await client.send(request);
        }
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Ordered: first, second, third'.rpc));
        expect(receivedRequests, equals(orderedRequests));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async => 'test'.rpc,
        );

        final client = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
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
        final receivedRequests = <RpcString>[];

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async {
            await for (final request in requests) {
              receivedRequests.add(request);
            }
            return 'Processed ${receivedRequests.length} requests'.rpc;
          },
        );

        final client = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        // Act
        await client.send('Hello'.rpc);
        await client.send('World'.rpc);
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Processed 2 requests'.rpc));
        expect(receivedRequests, equals(['Hello'.rpc, 'World'.rpc]));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_исключение_в_обработчике', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async {
            throw Exception('Handler error');
          },
        );

        final client = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        // Act & Assert
        await client.send('test'.rpc);
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
        var handlerCallCount = 0;

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async {
            handlerCallCount++;
            await for (final _ in requests) {}
            return 'response'.rpc;
          },
        );

        final correctClient = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        final incorrectClient = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'DifferentMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        // Act
        await correctClient.send('correct'.rpc);
        final correctResponse = await correctClient.finishSending();

        await incorrectClient.send('incorrect'.rpc);
        try {
          await incorrectClient.finishSending().timeout(Duration(seconds: 2));
        } catch (e) {
          // Ожидаем ошибку для неправильного метода
        }

        // Assert
        expect(handlerCallCount, equals(1));
        expect(correctResponse, equals('response'.rpc));

        // Cleanup
        await correctClient.close();
        await incorrectClient.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        final sut = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async => 'response'.rpc,
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

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'AggregatorService',
          methodName: 'Aggregate',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async {
            final allRequests = <RpcString>[];
            await for (final request in requests) {
              allRequests.add(request);
            }
            return 'Aggregated: ${allRequests.join(', ')}'.rpc;
          },
        );

        final client = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'AggregatorService',
          methodName: 'Aggregate',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        // Act
        final requests = ['Part1'.rpc, 'Part2'.rpc, 'Part3'.rpc];
        for (final request in requests) {
          await client.send(request);
        }
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Aggregated: Part1, Part2, Part3'.rpc));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('большое_количество_запросов', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        final server = ClientStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'CounterService',
          methodName: 'Count',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
          handler: (Stream<RpcString> requests) async {
            var count = 0;
            await for (final _ in requests) {
              count++;
            }
            return 'Total count: $count'.rpc;
          },
        );

        final client = ClientStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'CounterService',
          methodName: 'Count',
          requestSerializer: binaryStringSerializer,
          responseSerializer: binaryStringSerializer,
        );

        // Act
        const requestCount = 100;
        for (int i = 0; i < requestCount; i++) {
          await client.send('request_$i'.rpc);
        }
        final response = await client.finishSending();

        // Assert
        expect(response, equals('Total count: $requestCount'.rpc));

        // Cleanup
        await client.close();
        await server.close();
      });
    });
  });
}
