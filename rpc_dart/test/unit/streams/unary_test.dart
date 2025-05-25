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

/// Создает тестовую установку для клиента унарного RPC
(UnaryCaller<String, String>, _UnaryClientTestSetup) _createUnaryClientSetup() {
  final testSetup = _UnaryClientTestSetup();
  final serializer = StringSerializer();

  final client = UnaryCaller<String, String>(
    transport: testSetup.clientTransport,
    serviceName: 'TestService',
    methodName: 'TestMethod',
    requestSerializer: serializer,
    responseSerializer: serializer,
    logger: RpcLogger('TestUnaryClient'),
  );

  return (client, testSetup);
}

/// Класс для настройки тестов унарного клиента
class _UnaryClientTestSetup {
  final (IRpcTransport, IRpcTransport) _transportPair;
  final IRpcTransport clientTransport;
  final IRpcTransport serverTransport;
  final List<String> receivedRequests = [];

  _UnaryClientTestSetup()
      : _transportPair = RpcInMemoryTransport.pair(),
        clientTransport = RpcInMemoryTransport.pair().$1,
        serverTransport = RpcInMemoryTransport.pair().$2 {
    _setupServer();
  }

  void _setupServer() {
    serverTransport.incomingMessages.listen((message) {
      if (message.payload != null) {
        final payload = message.payload!;
        final parser = RpcMessageParser();
        final parsedPayloads = parser(payload);

        if (parsedPayloads.isNotEmpty) {
          final requestData = parsedPayloads.first;
          final requestString = utf8.decode(requestData);
          receivedRequests.add(requestString);
        }
      }
    });
  }

  void mockResponse(String response) {
    serverTransport.incomingMessages.listen((message) {
      if (!message.isMetadataOnly) {
        final streamId = message.streamId;

        // Отправляем заголовки
        serverTransport.sendMetadata(
          streamId,
          RpcMetadata.forServerInitialResponse(),
        );

        // Отправляем ответ
        final responseData = RpcMessageFrame.encode(utf8.encode(response));
        serverTransport.sendMessage(
          streamId,
          responseData,
        );

        // Отправляем трейлеры
        serverTransport.sendMetadata(
          streamId,
          RpcMetadata.forTrailer(RpcStatus.OK),
          endStream: true,
        );
      }
    });
  }

  void mockError(int statusCode, String errorMessage) {
    serverTransport.incomingMessages.listen((message) {
      if (!message.isMetadataOnly) {
        final streamId = message.streamId;

        // Отправляем трейлеры с ошибкой
        serverTransport.sendMetadata(
          streamId,
          RpcMetadata.forTrailer(
            statusCode,
            message: errorMessage,
          ),
          endStream: true,
        );
      }
    });
  }

  void mockDelayedResponse(String response, Duration delay) {
    serverTransport.incomingMessages.listen((message) async {
      if (!message.isMetadataOnly) {
        final streamId = message.streamId;

        // Отправляем заголовки
        serverTransport.sendMetadata(
          streamId,
          RpcMetadata.forServerInitialResponse(),
        );

        // Делаем задержку
        await Future.delayed(delay);

        // Отправляем ответ
        final responseData = RpcMessageFrame.encode(utf8.encode(response));
        serverTransport.sendMessage(
          streamId,
          responseData,
        );

        // Отправляем трейлеры
        serverTransport.sendMetadata(
          streamId,
          RpcMetadata.forTrailer(RpcStatus.OK),
          endStream: true,
        );
      }
    });
  }
}

void main() {
  group('Unary RPC', () {
    final serializer = StringSerializer();

    group('UnaryClient', () {
      test('отправляет_запрос_и_получает_ответ', () async {
        // Arrange
        final (sut, setup) = _createUnaryClientSetup();
        final testRequest = 'test request';
        final testResponse = 'test response';

        // Настраиваем мок ответа
        setup.mockResponse(testResponse);

        // Act
        final response = await sut.call(testRequest);

        // Assert
        expect(response, equals(testResponse));
        expect(setup.receivedRequests.length, equals(1));
        expect(setup.receivedRequests.first, equals(testRequest));
      });

      test('выбрасывает_исключение_при_ошибке_сервера', () async {
        // Arrange
        final (sut, setup) = _createUnaryClientSetup();

        // Настраиваем мок ошибки
        setup.mockError(RpcStatus.INTERNAL, 'Internal server error');

        // Act & Assert
        expect(
          () => sut.call('test request'),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('gRPC error 13'),
          )),
        );
      });

      test('применяет_таймаут_к_запросу', () async {
        // Arrange
        final (sut, setup) = _createUnaryClientSetup();

        // Настраиваем задержку больше таймаута
        setup.mockDelayedResponse('delayed response', Duration(seconds: 2));

        // Act & Assert
        expect(
          () => sut.call(
            'test request',
            timeout: Duration(milliseconds: 100),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (sut, _) = _createUnaryClientSetup();

        // Act
        await sut.close();

        // Assert
        // Проверяем, что нет исключений при закрытии
        expect(true, isTrue);
      });

      test('создает_уникальные_stream_id_для_каждого_вызова', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
        final receivedStreamIds = <int>[];

        serverTransport.incomingMessages.listen((message) {
          if (message.isMetadataOnly) {
            receivedStreamIds.add(message.streamId);
          }
        });

        // Act
        for (int i = 0; i < 3; i++) {
          final client = UnaryCaller<String, String>(
            transport: clientTransport,
            serviceName: 'TestService',
            methodName: 'TestMethod',
            requestSerializer: serializer,
            responseSerializer: serializer,
          );

          // Просто создаем клиентов, не ждем ответов
          unawaited(client.call('request $i').catchError((e) => 'error'));
          await client.close();
        }

        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(receivedStreamIds.length, equals(3));
        expect(receivedStreamIds.toSet().length, equals(3)); // Все уникальные
      });
    });

    group('UnaryServer', () {
      test('обрабатывает_запрос_и_отправляет_ответ', () async {
        // Arrange
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

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
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

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
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

        var handlerCallCount = 0;

        final server = UnaryResponder<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) {
            handlerCallCount++;
            return 'response';
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

        final incorrectClient = UnaryCaller<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'DifferentMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        // Act
        unawaited(correctClient.call('correct request'));
        unawaited(incorrectClient
            .call('incorrect request')
            .catchError((e) => 'error'));

        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(handlerCallCount, equals(1)); // Только один вызов

        // Cleanup
        await correctClient.close();
        await incorrectClient.close();
        await server.close();
      });

      test('закрывается_корректно', () async {
        // Arrange
        final (_, serverTransport) = RpcInMemoryTransport.pair();

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
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

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
        final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

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
