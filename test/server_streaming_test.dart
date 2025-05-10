import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Модели данных для тестов
class TestRequest implements IRpcSerializableMessage {
  final int count;
  final String requestId;

  TestRequest({required this.count, this.requestId = ''});

  factory TestRequest.fromJson(Map<String, dynamic> json) {
    return TestRequest(
      count: json['count'] as int? ?? 5,
      requestId: json['requestId'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'requestId': requestId,
    };
  }
}

class TestStreamResponse implements IRpcSerializableMessage {
  final int value;
  final String info;

  TestStreamResponse({required this.value, this.info = ''});

  factory TestStreamResponse.fromJson(Map<String, dynamic> json) {
    return TestStreamResponse(
      value: json['value'] as int,
      info: json['info'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'info': info,
    };
  }
}

// Результат выполнения серверного стриминга
class ServerStreamResult<T> {
  final Stream<T> stream;
  final Map<String, dynamic> response;

  ServerStreamResult({required this.stream, required this.response});
}

// Контракт для тестирования серверного стриминга
abstract base class TestServerStreamContract extends RpcServiceContract {
  @override
  final String serviceName = 'TestServerStreamService';

  static const String basicStreamMethod = 'basicStream';
  static const String multipleStreamsMethod = 'multipleStreams';
  static const String errorStreamMethod = 'errorStream';

  @override
  void setup() {
    // Регистрируем методы серверного стриминга
    addServerStreamingMethod<TestRequest, TestStreamResponse>(
      methodName: basicStreamMethod,
      handler: basicStream,
      argumentParser: TestRequest.fromJson,
      responseParser: TestStreamResponse.fromJson,
    );

    addServerStreamingMethod<TestRequest, TestStreamResponse>(
      methodName: multipleStreamsMethod,
      handler: multipleStreams,
      argumentParser: TestRequest.fromJson,
      responseParser: TestStreamResponse.fromJson,
    );

    addServerStreamingMethod<TestRequest, TestStreamResponse>(
      methodName: errorStreamMethod,
      handler: errorStream,
      argumentParser: TestRequest.fromJson,
      responseParser: TestStreamResponse.fromJson,
    );
  }

  // Абстрактные методы
  Stream<TestStreamResponse> basicStream(TestRequest request);
  Stream<TestStreamResponse> multipleStreams(TestRequest request);
  Stream<TestStreamResponse> errorStream(TestRequest request);
}

// Серверная реализация контракта
final class ServerTestStreamService extends TestServerStreamContract {
  @override
  Stream<TestStreamResponse> basicStream(TestRequest request) async* {
    // Создаем поток ответов
    for (int i = 1; i <= request.count; i++) {
      yield TestStreamResponse(value: i * 10);
      await Future.delayed(Duration(milliseconds: 10));
    }
  }

  @override
  Stream<TestStreamResponse> multipleStreams(TestRequest request) async* {
    final multiplier = request.count; // Используем count как множитель

    // Отправляем набор данных с множителем
    for (int i = 1; i <= 3; i++) {
      yield TestStreamResponse(
        value: i * multiplier,
        info: 'Multiplier stream: ${request.requestId}',
      );
      await Future.delayed(Duration(milliseconds: 10));
    }
  }

  @override
  Stream<TestStreamResponse> errorStream(TestRequest request) async* {
    final shouldError =
        request.count < 0; // Отрицательный count вызывает ошибку

    if (shouldError) {
      throw RpcInvalidArgumentException(
        'Ошибка в потоке: отрицательное значение count',
      );
    }

    // Отправляем одно сообщение и затем ошибку, если count == 0
    if (request.count == 0) {
      yield TestStreamResponse(value: 1);
      await Future.delayed(Duration(milliseconds: 10));
      throw Exception('Преднамеренная ошибка в потоке');
    }

    // Обычный поток для положительных значений
    for (int i = 1; i <= request.count; i++) {
      yield TestStreamResponse(value: i);
      await Future.delayed(Duration(milliseconds: 10));
    }
  }
}

// Клиентская реализация контракта
final class ClientTestStreamService extends TestServerStreamContract {
  final RpcEndpoint _endpoint;

  ClientTestStreamService(this._endpoint);

  @override
  Stream<TestStreamResponse> basicStream(TestRequest request) {
    return _endpoint
        .serverStreaming(
            serviceName, TestServerStreamContract.basicStreamMethod)
        .openStream<TestRequest, TestStreamResponse>(
          request: request,
          responseParser: TestStreamResponse.fromJson,
        );
  }

  @override
  Stream<TestStreamResponse> multipleStreams(TestRequest request) {
    return _endpoint
        .serverStreaming(
            serviceName, TestServerStreamContract.multipleStreamsMethod)
        .openStream<TestRequest, TestStreamResponse>(
          request: request,
          responseParser: TestStreamResponse.fromJson,
        );
  }

  @override
  Stream<TestStreamResponse> errorStream(TestRequest request) {
    return _endpoint
        .serverStreaming(
            serviceName, TestServerStreamContract.errorStreamMethod)
        .openStream<TestRequest, TestStreamResponse>(
          request: request,
          responseParser: TestStreamResponse.fromJson,
        );
  }

  // Вспомогательный метод для получения и стрима, и ответа
  Future<ServerStreamResult<TestStreamResponse>> getServerStreamResult(
    String methodName,
    TestRequest request,
  ) async {
    // Открываем соединение и получаем ответ API
    final response = await _endpoint.invoke(
      serviceName,
      methodName,
      request.toJson(),
    );

    // Открываем и слушаем стрим
    final stream = _endpoint
        .serverStreaming(serviceName, methodName)
        .openStream<TestRequest, TestStreamResponse>(
          request: request,
          responseParser: TestStreamResponse.fromJson,
        );

    return ServerStreamResult(stream: stream, response: response);
  }
}

void main() {
  group('Server Streaming Tests (with Contracts)', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ServerTestStreamService serverService;
    late ClientTestStreamService clientService;

    setUp(() {
      // Arrange - общий для всех тестов
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      final serializer = JsonSerializer();
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: serializer,
        debugLabel: 'client', // Метка для отладки
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: serializer,
        debugLabel: 'server', // Метка для отладки
      );

      // Добавляем middleware для улучшения диагностики
      clientEndpoint.addMiddleware(LoggingMiddleware(id: 'client'));
      serverEndpoint.addMiddleware(LoggingMiddleware(id: 'server'));

      // Регистрируем серверную реализацию
      serverService = ServerTestStreamService();
      serverEndpoint.registerServiceContract(serverService);

      // Создаем клиентскую реализацию
      clientService = ClientTestStreamService(clientEndpoint);
    });

    tearDown(() async {
      // Освобождаем ресурсы после каждого теста
      await clientEndpoint.close();
      await serverEndpoint.close();
    });

    test(
        'should receive stream of data from server in response to single request',
        () async {
      // Arrange
      final request = TestRequest(count: 5);
      final receivedValues = <int>[];
      final streamCompleter = Completer<void>();

      // Act
      final stream = clientService.basicStream(request);

      // Обрабатываем поток
      stream.listen(
        (data) {
          receivedValues.add(data.value);
          if (receivedValues.length == 5) {
            streamCompleter.complete();
          }
        },
        onDone: () {
          if (!streamCompleter.isCompleted) {
            streamCompleter.complete();
          }
        },
      );

      // Ожидаем завершения стрима
      await streamCompleter.future.timeout(
        Duration(seconds: 2),
        onTimeout: () => print('Таймаут ожидания стрима'),
      );

      // Assert
      expect(receivedValues.length, equals(5));
      expect(receivedValues, equals([10, 20, 30, 40, 50]));
    });

    test('should correctly handle multiple simultaneous server streams',
        () async {
      // Arrange
      final request1 = TestRequest(count: 10, requestId: 'stream-1');
      final request2 = TestRequest(count: 100, requestId: 'stream-2');

      final stream1Values = <int>[];
      final stream2Values = <int>[];

      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      // Act - первый стрим
      final stream1 = clientService.multipleStreams(request1);

      // Обрабатываем первый поток
      stream1.listen(
        (data) {
          stream1Values.add(data.value);
          if (stream1Values.length == 3) {
            completer1.complete();
          }
        },
        onDone: () {
          if (!completer1.isCompleted) {
            completer1.complete();
          }
        },
      );

      // Act - второй стрим
      final stream2 = clientService.multipleStreams(request2);

      // Обрабатываем второй поток
      stream2.listen(
        (data) {
          stream2Values.add(data.value);
          if (stream2Values.length == 3) {
            completer2.complete();
          }
        },
        onDone: () {
          if (!completer2.isCompleted) {
            completer2.complete();
          }
        },
      );

      // Ожидаем завершения обоих стримов
      await Future.wait([
        completer1.future,
        completer2.future,
      ]).timeout(
        Duration(seconds: 2),
        onTimeout: () {
          print('Таймаут ожидания стримов');
          return <void>[];
        },
      );

      // Assert
      expect(stream1Values.length, equals(3));
      expect(stream1Values, equals([10, 20, 30]));

      expect(stream2Values.length, equals(3));
      expect(stream2Values, equals([100, 200, 300]));
    });

    test('should handle errors in server streaming', () async {
      // Arrange
      final errorRequest = TestRequest(count: -1, requestId: 'error-stream');
      bool errorThrown = false;

      // Act & Assert
      try {
        await clientService.errorStream(errorRequest).first;
      } catch (e) {
        errorThrown = true;
        // Проверяем, что строка ошибки содержит правильное сообщение
        expect(e.toString(), contains('отрицательное значение count'),
            reason:
                'Ошибка должна содержать сообщение об отрицательном значении');
      }

      expect(errorThrown, isTrue,
          reason: 'Ожидалась ошибка для запроса с отрицательным count');
    });

    test('should handle errors in stream itself', () async {
      // Arrange
      final streamErrorRequest =
          TestRequest(count: 0, requestId: 'stream-error');
      final receivedValues = <int>[];
      var errorCaught = false;
      final completer = Completer<void>();

      // Act
      final stream = clientService.errorStream(streamErrorRequest);

      // Обрабатываем поток с ошибкой
      stream.listen(
        (data) {
          receivedValues.add(data.value);
        },
        onError: (error) {
          errorCaught = true;
          completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Ожидаем завершения стрима или ошибку
      await completer.future.timeout(
        Duration(seconds: 2),
        onTimeout: () => print('Таймаут ожидания ошибки в стриме'),
      );

      // Assert
      expect(errorCaught, isTrue,
          reason: 'Ошибка в стриме должна быть поймана');
      expect(receivedValues.length, equals(1),
          reason: 'Должно быть получено одно сообщение перед ошибкой');
    });
  });
}
