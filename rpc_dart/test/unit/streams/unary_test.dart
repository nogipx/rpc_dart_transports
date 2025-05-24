import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:rpc_dart/src_v2/rpc/_index.dart';

void main() {
  group('Unary RPC', () {
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

        final serializer = _TestStringSerializer();

        // Act
        for (int i = 0; i < 3; i++) {
          final client = UnaryClient<String, String>(
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
        final serializer = _TestStringSerializer();
        final receivedRequests = <String>[];

        final server = UnaryServer<String, String>(
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

        final client = UnaryClient<String, String>(
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
        final serializer = _TestStringSerializer();

        final server = UnaryServer<String, String>(
          transport: serverTransport,
          serviceName: 'TestService',
          methodName: 'TestMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) {
            throw Exception('Handler error');
          },
        );

        final client = UnaryClient<String, String>(
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
        final serializer = _TestStringSerializer();
        var handlerCallCount = 0;

        final server = UnaryServer<String, String>(
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
        final correctClient = UnaryClient<String, String>(
          transport: clientTransport,
          serviceName: 'TestService',
          methodName: 'SpecificMethod',
          requestSerializer: serializer,
          responseSerializer: serializer,
        );

        final incorrectClient = UnaryClient<String, String>(
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
        final serializer = _TestStringSerializer();

        final sut = UnaryServer<String, String>(
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
        final serializer = _TestStringSerializer();

        final server = UnaryServer<String, String>(
          transport: serverTransport,
          serviceName: 'EchoService',
          methodName: 'Echo',
          requestSerializer: serializer,
          responseSerializer: serializer,
          handler: (request) => 'Echo: $request',
        );

        final client = UnaryClient<String, String>(
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
        final serializer = _TestStringSerializer();
        var requestCount = 0;

        final server = UnaryServer<String, String>(
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
          final client = UnaryClient<String, String>(
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

/// Настройка для тестирования UnaryClient
class _UnaryClientTestSetup {
  final IRpcTransport clientTransport;
  final IRpcTransport serverTransport;
  final List<String> receivedRequests = [];
  final StreamController<String?> responseController =
      StreamController<String?>();
  late final StreamSubscription _subscription;

  _UnaryClientTestSetup(this.clientTransport, this.serverTransport) {
    // Подписываемся на входящие запросы и обрабатываем их
    _subscription = serverTransport.incomingMessages.listen((message) async {
      if (!message.isMetadataOnly && message.payload != null) {
        // Десериализуем запрос
        final serializer = _TestStringSerializer();
        final request = serializer.deserialize(
          message.payload!.sublist(5), // Убираем 5-байтный префикс
        );
        receivedRequests.add(request);

        // Ждем ответа от контроллера
        final response = await responseController.stream.first;

        if (response != null) {
          // Отправляем ответ
          final serializedResponse = serializer.serialize(response);
          final framedResponse = RpcMessageFrame.encode(serializedResponse);
          await serverTransport.sendMessage(message.streamId, framedResponse);

          // Отправляем трейлер с успешным статусом
          final trailer = RpcMetadata.forTrailer(RpcStatus.OK);
          await serverTransport.sendMetadata(message.streamId, trailer,
              endStream: true);
        }
      } else if (message.isMetadataOnly && !message.isEndOfStream) {
        // Отправляем начальные заголовки
        final initialHeaders = RpcMetadata.forServerInitialResponse();
        await serverTransport.sendMetadata(message.streamId, initialHeaders);
      }
    });
  }

  void mockResponse(String response) {
    responseController.add(response);
  }

  void mockError(int statusCode, String message) {
    Timer(Duration(milliseconds: 10), () async {
      if (receivedRequests.isNotEmpty) {
        final streamId = 1; // Предполагаем первый stream
        final trailer = RpcMetadata.forTrailer(statusCode, message: message);
        await serverTransport.sendMetadata(streamId, trailer, endStream: true);
      }
    });
    responseController.add(null);
  }

  void mockDelayedResponse(String response, Duration delay) {
    Timer(delay, () => responseController.add(response));
  }

  void dispose() {
    _subscription.cancel();
    responseController.close();
  }
}

/// Фабричный метод для создания UnaryClient с тестовой настройкой
(UnaryClient<String, String>, _UnaryClientTestSetup) _createUnaryClientSetup() {
  final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();
  final serializer = _TestStringSerializer();

  final client = UnaryClient<String, String>(
    transport: clientTransport,
    serviceName: 'TestService',
    methodName: 'TestMethod',
    requestSerializer: serializer,
    responseSerializer: serializer,
  );

  final setup = _UnaryClientTestSetup(clientTransport, serverTransport);

  return (client, setup);
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
