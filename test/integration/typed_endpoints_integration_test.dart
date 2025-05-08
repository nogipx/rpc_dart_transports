import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Тестовые модели сообщений
class TestRequest implements RpcSerializableMessage {
  final int value;

  TestRequest(this.value);

  @override
  Map<String, dynamic> toJson() => {'value': value};

  static TestRequest fromJson(Map<String, dynamic> json) {
    return TestRequest(json['value'] as int);
  }
}

class TestResponse implements RpcSerializableMessage {
  final int result;

  TestResponse(this.result);

  @override
  Map<String, dynamic> toJson() => {'result': result};

  static TestResponse fromJson(Map<String, dynamic> json) {
    return TestResponse(json['result'] as int);
  }
}

// Контракт для тестов
abstract base class TestContract
    extends DeclarativeRpcServiceContract<RpcSerializableMessage> {
  RpcEndpoint? get endpoint;

  @override
  final String serviceName = 'TestService';

  @override
  void registerMethodsFromClass() {
    // Унарный метод
    addUnaryMethod<TestRequest, TestResponse>(
      methodName: 'multiply',
      handler: multiply,
      argumentParser: TestRequest.fromJson,
      responseParser: TestResponse.fromJson,
    );

    // Стриминговый метод
    addServerStreamingMethod<TestRequest, TestResponse>(
      methodName: 'countTo',
      handler: countTo,
      argumentParser: TestRequest.fromJson,
      responseParser: TestResponse.fromJson,
    );
  }

  // Методы контракта
  Future<TestResponse> multiply(TestRequest request);
  Stream<TestResponse> countTo(TestRequest request);
}

// Серверная реализация контракта
base class ServerTestService extends TestContract {
  @override
  RpcEndpoint? get endpoint => null;

  @override
  Future<TestResponse> multiply(TestRequest request) async {
    return TestResponse(request.value * 2);
  }

  @override
  Stream<TestResponse> countTo(TestRequest request) async* {
    for (int i = 1; i <= request.value; i++) {
      yield TestResponse(i);
      await Future.delayed(Duration(milliseconds: 10));
    }
  }
}

// Клиентская реализация контракта
base class ClientTestService extends TestContract {
  @override
  final RpcEndpoint endpoint;

  ClientTestService(this.endpoint);

  @override
  Future<TestResponse> multiply(TestRequest request) {
    return endpoint.invokeTyped<TestRequest, TestResponse>(
      serviceName: serviceName,
      methodName: 'multiply',
      request: request,
    );
  }

  @override
  Stream<TestResponse> countTo(TestRequest request) {
    return endpoint.openTypedStream<TestRequest, TestResponse>(
      serviceName,
      'countTo',
      request,
    );
  }
}

// Специальная реализация для тестирования произвольных методов
base class CustomServiceContract
    implements RpcServiceContract<RpcSerializableMessage> {
  @override
  dynamic getArgumentParser(
      RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>
          method) {
    return null;
  }

  @override
  dynamic getHandler(
      RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>
          method) {
    return null;
  }

  @override
  List<RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>>
      get methods => [];

  @override
  dynamic getResponseParser(
      RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>
          method) {
    return null;
  }

  @override
  String get serviceName => 'CustomService';

  @override
  RpcMethodContract<Request, Response>? findMethodTyped<
      Request extends RpcSerializableMessage,
      Response extends RpcSerializableMessage>(String methodName) {
    return null;
  }
}

void main() {
  group('Типизированные эндпоинты и контракты', () {
    // Создаем реальные компоненты для тестов
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late JsonSerializer serializer;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientTestService clientService;
    late ServerTestService serverService;

    setUp(() {
      // Arrange - подготовка
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');

      // Соединяем транспорты
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем сериализатор
      serializer = JsonSerializer();

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(clientTransport, serializer);
      serverEndpoint = RpcEndpoint(serverTransport, serializer);

      // Создаем сервисы
      clientService = ClientTestService(clientEndpoint);
      serverService = ServerTestService();

      // Регистрируем контракты
      serverEndpoint.registerContract(serverService);
      clientEndpoint.registerContract(clientService);
    });

    tearDown(() async {
      // Освобождение ресурсов
      await clientEndpoint.close();
      await serverEndpoint.close();
    });

    test('унарный_метод_корректно_вычисляет_и_возвращает_результат', () async {
      // Arrange - подготовка
      final request = TestRequest(5);
      final expectedResult = 10; // 5 * 2 = 10

      // Act - действие
      final response = await clientService.multiply(request);

      // Assert - проверка
      expect(response.result, equals(expectedResult));
    });

    test('стриминговый_метод_корректно_возвращает_поток_значений', () async {
      // Arrange - подготовка
      final request = TestRequest(3);
      final expectedValues = [1, 2, 3];
      final actualValues = <int>[];

      // Act - действие
      final stream = clientService.countTo(request);

      // Assert - проверка
      await for (var response in stream) {
        actualValues.add(response.result);
      }

      expect(actualValues, equals(expectedValues));
    });

    test('регистрация_нетипизированного_метода_работает_корректно', () async {
      // Arrange - подготовка
      final serviceName = 'CalculatorService';
      final methodName = 'divide';

      // Регистрируем нетипизированный метод на сервере
      serverEndpoint.registerMethod(
        serviceName,
        methodName,
        (context) async {
          final payload = context.payload as Map<String, dynamic>;
          final value = payload['value'] as int;
          return {'result': value ~/ 2};
        },
      );

      // Act - действие
      final response = await clientEndpoint.invoke(
        serviceName,
        methodName,
        {'value': 10},
      );

      // Assert - проверка
      expect(response['result'], equals(5));
    });

    test('вызов_несуществующего_метода_вызывает_исключение', () async {
      // Act & Assert - действие и проверка
      expect(
        () => clientEndpoint.invokeTyped<TestRequest, TestResponse>(
          serviceName: 'NonexistentService',
          methodName: 'nonexistentMethod',
          request: TestRequest(5),
        ),
        throwsA(anything),
      );
    });
  });
}
