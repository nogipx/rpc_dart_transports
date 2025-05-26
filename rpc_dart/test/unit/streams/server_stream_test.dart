import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Server Stream', () {
    final serializer = RpcCodec(RpcString.fromJson);

    group('ServerStreamClient', () {
      test('отправляет_один_запрос_и_получает_множественные_ответы', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final receivedRequests = <RpcString>[];

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) async* {
            receivedRequests.add(request);
            // Отправляем несколько ответов
            yield 'Response 1 for: $request'.rpc;
            yield 'Response 2 for: $request'.rpc;
            yield 'Response 3 for: $request'.rpc;
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) {
            return Stream.empty();
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) {
            // Выбрасываем синхронное исключение
            throw Exception('Server error');
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) async* {
            yield 'response1'.rpc;
            yield 'response2'.rpc;
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) async* {
            // Пустой стрим
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) async* {
            receivedRequests.add(request);

            // Отправляем несколько ответов
            yield 'Response 1 for: $request'.rpc;
            yield 'Response 2 for: $request'.rpc;
            yield 'Response 3 for: $request'.rpc;
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) {
            // Выбрасываем синхронное исключение
            throw Exception('Handler error');
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) async* {
            handlerCallCount++;
          },
        );

        final correctClient = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestCodec: serializer,
          responseCodec: serializer,
        );

        final incorrectClient = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'DifferentMethod',
          requestCodec: serializer,
          responseCodec: serializer,
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

        // Создаем контроллер для управления стримом
        final controller = StreamController<RpcString>();

        final server = ServerStreamResponder<RpcString, RpcString>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) {
            // Асинхронно имитируем отправку одного ответа, а затем ошибку в стриме
            Future.microtask(() {
              controller.add('First response'.rpc);
              controller.addError(Exception('Test error message'));
              controller.close();
            });
            return controller.stream;
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestCodec: serializer,
          responseCodec: serializer,
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) async* {
            // Пустой стрим
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) async* {
            final count = int.tryParse(request.value) ?? 3;
            for (int i = 1; i <= count; i++) {
              yield 'Number $i'.rpc;
            }
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'NumberService',
          methodName: 'GenerateNumbers',
          requestCodec: serializer,
          responseCodec: serializer,
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
          requestCodec: serializer,
          responseCodec: serializer,
          handler: (request) async* {
            const responseCount = 50;
            for (int i = 0; i < responseCount; i++) {
              yield 'Response $i'.rpc;
            }
          },
        );

        final client = ServerStreamCaller<RpcString, RpcString>(
          transport: clientTransport,
          serviceName: 'StreamService',
          methodName: 'LargeStream',
          requestCodec: serializer,
          responseCodec: serializer,
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
