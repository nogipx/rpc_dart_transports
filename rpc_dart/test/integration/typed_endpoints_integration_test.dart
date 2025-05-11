import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Тестовые модели сообщений
class TestRequest implements IRpcSerializableMessage {
  final int a;
  final int b;

  TestRequest(this.a, this.b);

  @override
  Map<String, dynamic> toJson() => {'a': a, 'b': b};

  static TestRequest fromJson(Map<String, dynamic> json) {
    return TestRequest(
      json['a'] as int,
      json['b'] as int,
    );
  }
}

class TestResponse implements IRpcSerializableMessage {
  final int result;

  TestResponse(this.result);

  @override
  Map<String, dynamic> toJson() => {'result': result};

  static TestResponse fromJson(Map<String, dynamic> json) {
    return TestResponse(json['result'] as int);
  }
}

class CountRequest implements IRpcSerializableMessage {
  final int count;

  CountRequest(this.count);

  @override
  Map<String, dynamic> toJson() => {'count': count};

  static CountRequest fromJson(Map<String, dynamic> json) {
    return CountRequest(json['count'] as int);
  }
}

class CountResponse implements IRpcSerializableMessage {
  final int value;

  CountResponse(this.value);

  @override
  Map<String, dynamic> toJson() => {'value': value};

  static CountResponse fromJson(Map<String, dynamic> json) {
    return CountResponse(json['value'] as int);
  }
}

// Контракт тестового сервиса
abstract base class TestContract
    extends RpcServiceContract<IRpcSerializableMessage> {
  @override
  final String serviceName = 'TestService';

  // Константы для имен методов
  static const String multiplyMethod = 'multiply';
  static const String countToMethod = 'countTo';

  @override
  void setup() {
    // Унарный метод
    addUnaryMethod<TestRequest, TestResponse>(
      methodName: multiplyMethod,
      handler: multiply,
      argumentParser: TestRequest.fromJson,
      responseParser: TestResponse.fromJson,
    );

    // Стриминговый метод
    addServerStreamingMethod<CountRequest, CountResponse>(
      methodName: countToMethod,
      handler: countTo,
      argumentParser: CountRequest.fromJson,
      responseParser: CountResponse.fromJson,
    );
  }

  // Методы контракта
  Future<TestResponse> multiply(TestRequest request);
  Stream<CountResponse> countTo(CountRequest request);
}

// Серверная реализация
final class ServerTestService extends TestContract {
  @override
  Future<TestResponse> multiply(TestRequest request) async {
    final result = request.a * request.b;
    return TestResponse(result);
  }

  @override
  Stream<CountResponse> countTo(CountRequest request) async* {
    for (int i = 1; i <= request.count; i++) {
      await Future.delayed(Duration(milliseconds: 10)); // Small delay
      yield CountResponse(i);
    }
  }
}

// Клиентская реализация
final class ClientTestService extends TestContract {
  final RpcEndpoint _endpoint;

  ClientTestService(this._endpoint);

  @override
  Future<TestResponse> multiply(TestRequest request) {
    return _endpoint
        .unary(serviceName, TestContract.multiplyMethod)
        .call<TestRequest, TestResponse>(
          request: request,
          responseParser: TestResponse.fromJson,
        );
  }

  @override
  Stream<CountResponse> countTo(CountRequest request) {
    return _endpoint
        .serverStreaming(serviceName, TestContract.countToMethod)
        .openStream<CountRequest, CountResponse>(
          request: request,
          responseParser: CountResponse.fromJson,
        );
  }
}

void main() {
  group('Типизированные эндпоинты и контракты', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientTestService clientService;
    late ServerTestService serverService;

    setUp(() {
      // Создаем пару транспортов для памяти
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');

      // Соединяем транспорты
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        debugLabel: 'CLIENT',
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        debugLabel: 'SERVER',
      );

      // Создаем сервисы
      clientService = ClientTestService(clientEndpoint);
      serverService = ServerTestService();

      // Регистрируем серверный контракт
      serverEndpoint.registerServiceContract(serverService);

      // Добавляем очистку ресурсов
      addTearDown(() async {
        await clientEndpoint.close();
        await serverEndpoint.close();
      });
    });

    test('унарный_метод_корректно_вычисляет_и_возвращает_результат', () async {
      // Создаем запрос
      final request = TestRequest(5, 7);

      // Вызываем метод
      final response = await clientService.multiply(request);

      // Проверяем результат
      expect(response.result, equals(35)); // 5 * 7 = 35
    });

    test('стриминговый_метод_корректно_возвращает_поток_значений', () async {
      // Создаем запрос
      final request = CountRequest(5);

      // Получаем поток значений
      final stream = clientService.countTo(request);

      // Собираем все значения из потока
      final responses = await stream.toList();

      // Проверяем количество и содержимое ответов
      expect(responses.length, equals(5));

      // Проверяем, что значения идут по порядку
      for (int i = 0; i < responses.length; i++) {
        expect(responses[i].value, equals(i + 1));
      }
    });
  });
}
