import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';
import 'package:rpc_dart/src/rpc/_index.dart';

/// Сериализатор строк для тестирования
class StringSerializer implements IRpcSerializer<String> {
  const StringSerializer();

  @override
  Uint8List serialize(String message) =>
      Uint8List.fromList(utf8.encode(message));

  @override
  String deserialize(Uint8List bytes) => utf8.decode(bytes);

  @override
  RpcSerializationFormat get format => RpcSerializationFormat.binary;
}

/// Создает транспортную пару для тестирования
(IRpcTransport, IRpcTransport) createTransportPair() =>
    RpcInMemoryTransport.pair();

void main() {
  group('Unary RPC', () {
    final serializer = StringSerializer();

    group('UnaryClient', () {
      test('отправляет_запрос_и_получает_ответ', () async {
        // Arrange
        final (clientTransport, serverTransport) = createTransportPair();
        final receivedRequests = <String>[];

        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) {
            receivedRequests.add(request);
            return 'Echo: $request';
          },
        );

        final client = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          logger: RpcLogger('TestUnaryClient'),
        );

        // Act
        final response = await client.call('test request');

        // Assert
        expect(response, equals('Echo: test request'));
        expect(receivedRequests.length, equals(1));
        expect(receivedRequests.first, equals('test request'));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('выбрасывает_исключение_при_ошибке_сервера', () async {
        // Arrange
        final (clientTransport, serverTransport) = createTransportPair();

        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) {
            throw Exception('Internal server error');
          },
        );

        final client = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          logger: RpcLogger('TestUnaryClient'),
        );

        // Act & Assert
        await expectLater(
          client.call('test request'),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('gRPC error'),
          )),
        );

        // Cleanup
        await client.close();
        await server.close();
      });

      test('применяет_таймаут_к_запросу', () async {
        // Arrange
        final (clientTransport, serverTransport) = createTransportPair();

        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) async {
            // Задержка больше таймаута
            await Future.delayed(Duration(seconds: 1));
            return 'Delayed response';
          },
        );

        final client = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          logger: RpcLogger('TestUnaryClient'),
        );

        // Act & Assert
        expect(
          () => client.call(
            'test request',
            timeout: Duration(milliseconds: 100),
          ),
          throwsA(isA<TimeoutException>()),
        );

        // Cleanup
        await client.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (clientTransport, _) = createTransportPair();

        final client = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          logger: RpcLogger('TestUnaryClient'),
        );

        // Act & Assert
        await client.close();
        expect(true, isTrue); // No exceptions
      });

      test('создает_уникальные_stream_id_для_каждого_вызова', () async {
        // Arrange
        final (clientTransport, serverTransport) = createTransportPair();
        final receivedStreamIds = <int>[];

        // Отслеживаем входящие stream IDs
        serverTransport.incomingMessages.listen((message) {
          if (message.isMetadataOnly) {
            receivedStreamIds.add(message.streamId);
          }
        });

        // Создаем простой сервер
        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) => 'Echo: $request',
        );

        // Act - делаем несколько вызовов
        final client = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Делаем три последовательных вызова
        await client.call('request 1');
        await client.call('request 2');
        await client.call('request 3');

        // Assert
        expect(receivedStreamIds.length, equals(3));
        expect(receivedStreamIds.toSet().length, equals(3)); // Все уникальные

        // Cleanup
        await client.close();
        await server.close();
      });
    });

    group('UnaryServer', () {
      test('обрабатывает_запрос_и_отправляет_ответ', () async {
        // Arrange
        final (clientTransport, serverTransport) = createTransportPair();

        final receivedRequests = <String>[];

        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) {
            receivedRequests.add(request);
            return 'Echo: $request';
          },
        );

        final client = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        final response = await client.call('Hello Server');

        // Assert
        expect(response, equals('Echo: Hello Server'));
        expect(receivedRequests.length, equals(1));
        expect(receivedRequests.first, equals('Hello Server'));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('отправляет_ошибку_при_исключении_в_обработчике', () async {
        // Arrange
        final (clientTransport, serverTransport) = createTransportPair();

        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) {
            throw Exception('Handler error');
          },
        );

        final client = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act & Assert
        await expectLater(
          client.call('test request'),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('gRPC error'),
          )),
        );

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_только_запросы_своего_метода', () async {
        // Arrange
        final (clientTransport, serverTransport) = createTransportPair();

        var handlerCallCount = 0;
        final receivedRequests = <String>[];

        // Сервер для конкретного метода
        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) {
            handlerCallCount++;
            receivedRequests.add(request);
            return 'response from SpecificMethod';
          },
        );

        // Второй сервер для другого метода
        final otherServer = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'DifferentMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) {
            return 'response from DifferentMethod';
          },
        );

        // Создаем клиентов для разных методов
        final correctClient = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final otherClient = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'DifferentMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        final response1 = await correctClient.call('correct request');
        final response2 = await otherClient.call('other request');

        // Assert
        expect(handlerCallCount,
            equals(1)); // Только один вызов конкретного обработчика
        expect(receivedRequests, equals(['correct request']));
        expect(response1, equals('response from SpecificMethod'));
        expect(response2, equals('response from DifferentMethod'));

        // Cleanup
        await correctClient.close();
        await otherClient.close();
        await server.close();
        await otherServer.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (_, serverTransport) = createTransportPair();

        final sut = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) => 'response',
        );

        // Act
        await sut.close();

        // Assert
        // Проверяем, что нет исключений при закрытии
        expect(true, isTrue);
      });
    });

    group('интеграционные тесты', () {
      test('полный_цикл_запрос_ответ_работает_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = createTransportPair();

        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'EchoService',
          methodName: 'Echo',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) => 'Echo: $request',
        );

        final client = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'EchoService',
          methodName: 'Echo',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        final response1 = await client.call('Hello');
        final response2 = await client.call('World');

        // Assert
        expect(response1, equals('Echo: Hello'));
        expect(response2, equals('Echo: World'));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('несколько_клиентов_могут_использовать_один_сервер', () async {
        // Arrange
        final (clientTransport, serverTransport) = createTransportPair();

        var requestCount = 0;

        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'CounterService',
          methodName: 'Increment',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) {
            requestCount++;
            return 'Count: $requestCount';
          },
        );

        // Act - создаем несколько клиентов
        final responses = <String>[];
        for (int i = 0; i < 3; i++) {
          final client = UnaryCaller<String, String>(
            transport: clientTransport,
            serviceName: 'CounterService',
            methodName: 'Increment',
            requestSerializer: serializer,
            responseSerializer: serializer,
          );

          responses.add(await client.call('increment'));
          await client.close();
        }

        // Assert
        expect(responses.length, equals(3));
        expect(responses[0], equals('Count: 1'));
        expect(responses[1], equals('Count: 2'));
        expect(responses[2], equals('Count: 3'));

        // Cleanup
        await server.close();
      });
    });
  });
}
