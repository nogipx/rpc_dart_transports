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
          serviceName,
          TestServerStreamContract.basicStreamMethod,
        )
        .openStream<TestRequest, TestStreamResponse>(
          request: request,
          responseParser: TestStreamResponse.fromJson,
        );
  }

  @override
  Stream<TestStreamResponse> multipleStreams(TestRequest request) {
    return _endpoint
        .serverStreaming(
          serviceName,
          TestServerStreamContract.multipleStreamsMethod,
        )
        .openStream<TestRequest, TestStreamResponse>(
          request: request,
          responseParser: TestStreamResponse.fromJson,
        );
  }

  @override
  Stream<TestStreamResponse> errorStream(TestRequest request) {
    return _endpoint
        .serverStreaming(
          serviceName,
          TestServerStreamContract.errorStreamMethod,
        )
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

    // Получаем информацию о стриме
    final streamId = response['streamId'] as String;

    // Открываем стрим и возвращаем его вместе с ответом API
    final stream = _endpoint
        .openStream(serviceName, methodName, streamId: streamId)
        .map((event) =>
            TestStreamResponse.fromJson(event as Map<String, dynamic>));

    return ServerStreamResult(stream: stream, response: response);
  }
}

void main() {
  group('MsgPack - Server Streaming Tests (with Contracts)', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientTestStreamService clientService;
    late ServerTestStreamService serverService;

    setUp(() {
      // Создаем пару связанных транспортов для памяти
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем эндпоинты с MsgPackSerializer
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: const MsgPackSerializer(), // Используем MsgPack
        debugLabel: 'CLIENT',
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: const MsgPackSerializer(), // Используем MsgPack
        debugLabel: 'SERVER',
      );

      // Создаем сервисы
      clientService = ClientTestStreamService(clientEndpoint);
      serverService = ServerTestStreamService();

      // Регистрируем сервис на сервере и на клиенте
      serverEndpoint.registerServiceContract(serverService);
      clientEndpoint.registerServiceContract(clientService);

      // Гарантируем очистку ресурсов после каждого теста
      addTearDown(() async {
        await clientEndpoint.close();
        await serverEndpoint.close();
      });
    });

    test(
        'should receive stream of data from server in response to single request',
        () async {
      // Создаем запрос
      final request = TestRequest(count: 5);

      // Открываем стрим для получения данных
      final stream = clientService.basicStream(request);

      // Проверяем, что все сообщения получены
      final responses = await stream.toList();
      expect(responses.length, 5);

      // Проверяем значения
      for (int i = 0; i < 5; i++) {
        expect(responses[i].value, (i + 1) * 10);
      }
    });

    test('should correctly handle multiple simultaneous server streams',
        () async {
      // Создаем несколько запросов с разными множителями
      final requestA = TestRequest(count: 5, requestId: 'A');
      final requestB = TestRequest(count: 10, requestId: 'B');
      final requestC = TestRequest(count: 15, requestId: 'C');

      print('Тестируем потоки последовательно');

      // Тестируем первый поток
      print('Открываем поток A');
      final streamA = clientService.multipleStreams(requestA);
      final responsesA = await streamA.toList();
      print('Получено из потока A: ${responsesA.length}');

      // Тестируем второй поток
      print('Открываем поток B');
      final streamB = clientService.multipleStreams(requestB);
      final responsesB = await streamB.toList();
      print('Получено из потока B: ${responsesB.length}');

      // Тестируем третий поток
      print('Открываем поток C');
      final streamC = clientService.multipleStreams(requestC);
      final responsesC = await streamC.toList();
      print('Получено из потока C: ${responsesC.length}');

      // Проверяем количество сообщений
      expect(responsesA.length, 3);
      expect(responsesB.length, 3);
      expect(responsesC.length, 3);

      // Проверяем, что значения правильно умножены
      if (responsesA.isNotEmpty) {
        print('Значение A[0]: ${responsesA[0].value}');
        expect(responsesA[0].value, 5); // 1 * 5
      }

      if (responsesB.isNotEmpty) {
        print('Значение B[0]: ${responsesB[0].value}');
        expect(responsesB[0].value, 10); // 1 * 10
      }

      if (responsesC.isNotEmpty) {
        print('Значение C[0]: ${responsesC[0].value}');
        expect(responsesC[0].value, 15); // 1 * 15
      }
    });

    test('should handle errors in server streaming', () async {
      // Создаем запрос, который вызовет ошибку
      final errorRequest = TestRequest(count: -1);

      try {
        // Пытаемся открыть стрим, который вызовет ошибку
        final stream = clientService.errorStream(errorRequest);
        await stream.first; // Попытка получить первое сообщение
        fail('Должно быть выброшено исключение');
      } catch (e) {
        // Проверяем, что исключение содержит ожидаемое сообщение
        expect(e.toString(), contains('отрицательное значение count'));
      }
    });

    test('should handle errors in stream itself', () async {
      // Создаем запрос, который будет работать, но потом выбросит ошибку
      final errorRequest = TestRequest(count: 0);

      // Открываем стрим
      final stream = clientService.errorStream(errorRequest);

      // Читаем все данные
      int receivedCount = 0;
      try {
        // ignore: unused_local_variable
        await for (final response in stream) {
          receivedCount++;
        }
        fail('Стрим должен выбросить ошибку');
      } catch (e) {
        // Проверяем, что получили одно сообщение перед ошибкой
        expect(receivedCount, 1,
            reason: 'Должно быть получено одно сообщение перед ошибкой');
        expect(e.toString(), contains('Преднамеренная ошибка'));
      }
    });
  });
}
