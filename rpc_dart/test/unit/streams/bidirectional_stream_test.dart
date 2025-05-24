import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:rpc_dart/src_v2/rpc/_index.dart';

void main() {
  group('Bidirectional Stream', () {
    group('BidirectionalStreamClient', () {
      test('отправляет_и_получает_сообщения_двунаправленно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = BidirectionalStreamResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final client = BidirectionalStreamCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedRequests = <String>[];
        final receivedResponses = <String>[];

        // Настраиваем серверную обработку
        server.requests.listen((request) async {
          receivedRequests.add(request);
          await server.send('Echo: $request');
        });

        // Настраиваем клиентскую обработку
        client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            receivedResponses.add(message.payload!);
          }
        });

        // Act
        await client.send('Hello');
        await client.send('World');

        // Ждем обработки сообщений
        while (receivedResponses.length < 2) {
          await Future.delayed(Duration(milliseconds: 1));
        }

        // Assert
        expect(receivedRequests.length, equals(2));
        expect(receivedRequests, equals(['Hello', 'World']));
        expect(receivedResponses.length, equals(2));
        expect(receivedResponses, equals(['Echo: Hello', 'Echo: World']));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_метаданные_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = BidirectionalStreamResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final client = BidirectionalStreamCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        var metadataReceived = false;

        client.responses.listen((message) {
          if (message.isMetadataOnly && message.metadata != null) {
            metadataReceived = true;
          }
        });

        // Act
        await client.send('test message');

        // Ждем обработки метаданных
        while (!metadataReceived) {
          await Future.delayed(Duration(milliseconds: 1));
        }

        // Assert
        expect(metadataReceived, isTrue);

        // Cleanup
        await client.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = BidirectionalStreamResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final client = BidirectionalStreamCaller<String, String>(
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

    group('BidirectionalStreamServer', () {
      test('получает_и_отправляет_сообщения_двунаправленно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = BidirectionalStreamResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final client = BidirectionalStreamCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final serverReceivedRequests = <String>[];
        final clientReceivedResponses = <String>[];

        // Настраиваем серверную логику
        server.requests.listen((request) async {
          serverReceivedRequests.add(request);
          await server.send('Server processed: $request');
        });

        // Настраиваем клиентскую логику
        client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            clientReceivedResponses.add(message.payload!);
          }
        });

        // Act
        await client.send('Request 1');
        await client.send('Request 2');

        // Ждем обработки
        while (clientReceivedResponses.length < 2) {
          await Future.delayed(Duration(milliseconds: 1));
        }

        // Assert
        expect(serverReceivedRequests.length, equals(2));
        expect(serverReceivedRequests, equals(['Request 1', 'Request 2']));
        expect(clientReceivedResponses.length, equals(2));
        expect(
            clientReceivedResponses, contains('Server processed: Request 1'));
        expect(
            clientReceivedResponses, contains('Server processed: Request 2'));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обрабатывает_только_запросы_своего_метода', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();
        var handlerCallCount = 0;

        final server = BidirectionalStreamResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        server.requests.listen((request) {
          handlerCallCount++;
        });

        final correctClient = BidirectionalStreamCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final incorrectClient = BidirectionalStreamCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'DifferentMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        await correctClient.send('correct request');
        await incorrectClient.send('incorrect request');

        // Ждем обработки
        await Future.delayed(Duration(milliseconds: 10));

        // Assert
        expect(handlerCallCount, equals(1));

        // Cleanup
        await correctClient.close();
        await incorrectClient.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final sut = BidirectionalStreamResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act & Assert - должно закрыться без ошибок
        await sut.close();
        await clientTransport.close();
      });
    });

    group('интеграционные тесты', () {
      test('полный_цикл_двунаправленного_стриминга', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = BidirectionalStreamResponder<String, String>(
          transport: serverTransport,
          serviceName: 'ChatService',
          methodName: 'Chat',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final client = BidirectionalStreamCaller<String, String>(
          transport: clientTransport,
          serviceName: 'ChatService',
          methodName: 'Chat',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final serverMessages = <String>[];
        final clientMessages = <String>[];

        // Настраиваем сервер
        server.requests.listen((request) async {
          serverMessages.add(request);

          if (request.startsWith('ping')) {
            await server.send('pong');
          } else {
            await server.send('echo: $request');
          }
        });

        // Настраиваем клиент
        client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            clientMessages.add(message.payload!);
          }
        });

        // Act
        await client.send('ping 1');
        await client.send('hello world');
        await client.send('ping 2');

        // Ждем обработки всех сообщений
        while (clientMessages.length < 3) {
          await Future.delayed(Duration(milliseconds: 1));
        }

        // Assert
        expect(serverMessages.length, equals(3));
        expect(serverMessages, equals(['ping 1', 'hello world', 'ping 2']));

        expect(clientMessages.length, equals(3));
        expect(clientMessages, contains('pong'));
        expect(clientMessages, contains('echo: hello world'));

        // Cleanup
        await client.close();
        await server.close();
      });

      test('обработка_большого_количества_сообщений', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final serializer = _TestStringSerializer();

        final server = BidirectionalStreamResponder<String, String>(
          transport: serverTransport,
          serviceName: 'HighVolumeService',
          methodName: 'Process',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final client = BidirectionalStreamCaller<String, String>(
          transport: clientTransport,
          serviceName: 'HighVolumeService',
          methodName: 'Process',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final receivedResponses = <String>[];

        server.requests.listen((request) async {
          await server.send('processed: $request');
        });

        client.responses.listen((message) {
          if (!message.isMetadataOnly && message.payload != null) {
            receivedResponses.add(message.payload!);
          }
        });

        // Act
        const messageCount = 50;
        for (int i = 0; i < messageCount; i++) {
          await client.send('message_$i');
        }

        // Ждем обработки всех сообщений
        while (receivedResponses.length < messageCount) {
          await Future.delayed(Duration(milliseconds: 1));
        }

        // Assert
        expect(receivedResponses.length, equals(messageCount));
        expect(receivedResponses.first, equals('processed: message_0'));
        expect(receivedResponses.last,
            equals('processed: message_${messageCount - 1}'));

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
