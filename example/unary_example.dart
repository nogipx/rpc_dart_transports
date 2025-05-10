import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования унарных вызовов (одиночный запрос -> одиночный ответ)
void main() async {
  print('=== Пример унарных вызовов ===\n');

  // Создаем транспорты в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  print('Транспорты соединены');

  // Создаем эндпоинты с метками для отладки
  final client = RpcEndpoint(
    transport: clientTransport,
    serializer: JsonSerializer(),
    debugLabel: 'client',
  );
  final server = RpcEndpoint(
    transport: serverTransport,
    serializer: JsonSerializer(),
    debugLabel: 'server',
  );
  print('Эндпоинты созданы');

  server.registerServiceContract(SimpleRpcServiceContract('Calculator'));
  server.registerServiceContract(SimpleRpcServiceContract('StringService'));
  server.registerServiceContract(SimpleRpcServiceContract('TypedService'));
  server.registerServiceContract(SimpleRpcServiceContract('ErrorService'));
  client.registerServiceContract(SimpleRpcServiceContract('Calculator'));
  client.registerServiceContract(SimpleRpcServiceContract('StringService'));
  client.registerServiceContract(SimpleRpcServiceContract('TypedService'));
  client.registerServiceContract(SimpleRpcServiceContract('ErrorService'));

  // Добавляем middleware для логирования
  server.addMiddleware(
    RpcMiddlewareWrapper(
      debugLabel: 'ServerLogger',
      onRequestHandler: (service, method, payload, context, direction) {
        print('Сервер получил запрос: $service.$method');
        return payload;
      },
      onResponseHandler: (service, method, response, context, direction) {
        print('Сервер отправил ответ: $response');
        return response;
      },
    ),
  );

  try {
    // Регистрируем методы на сервере
    registerServerMethods(server);
    print('Методы зарегистрированы');

    // Демонстрация базовых унарных вызовов
    await demonstrateBasicUnary(client);

    // Демонстрация унарных вызовов с типизацией
    await demonstrateTypedUnary(client);

    // Демонстрация обработки ошибок
    await demonstrateErrorHandling(client);
  } catch (e) {
    print('Произошла ошибка: $e');
  } finally {
    // Закрываем эндпоинты
    await client.close();
    await server.close();
    print('\nЭндпоинты закрыты');
  }

  print('\n=== Пример завершен ===');
}

/// Регистрация методов на сервере
void registerServerMethods(RpcEndpoint server) {
  // 1. Базовый метод калькулятора с Map в качестве входных и выходных данных
  server.unary('Calculator', 'add').register<RpcMap, RpcMap>(
        handler: (request) async {
          final a = request['a'] as int;
          final b = request['b'] as int;
          return RpcMap<String, RpcInt>({'result': RpcInt(a + b)});
        },
        requestParser: RpcMap.fromJson,
        responseParser: RpcMap.fromJson,
      );

  // 2. Строковый метод
  server.unary('StringService', 'concat').register<RpcMap, RpcMap>(
        handler: (request) async {
          final strings = request['strings'] as List<dynamic>;
          final separator = request['separator'] as String? ?? ' ';
          return RpcMap<String, RpcString>(
              {'result': RpcString(strings.join(separator))});
        },
        requestParser: RpcMap.fromJson,
        responseParser: RpcMap.fromJson,
      );

  // 3. Типизированный метод с сериализацией
  server
      .unary('TypedService', 'greet')
      .register<GreetingRequest, GreetingResponse>(
        handler: (request) async {
          return GreetingResponse(
            message: 'Привет, ${request.name}!',
            timestamp: DateTime.now().toIso8601String(),
          );
        },
        requestParser: GreetingRequest.fromJson,
        responseParser: GreetingResponse.fromJson,
      );

  // 4. Метод с ошибкой
  server.unary('ErrorService', 'divide').register<RpcMap, RpcMap>(
        handler: (request) async {
          final a = request['a'] as int;
          final b = request['b'] as int;
          return RpcMap<String, RpcInt>({'result': RpcInt(a ~/ b)});
        },
        requestParser: RpcMap.fromJson,
        responseParser: RpcMap.fromJson,
      );
}

/// Демонстрация базовых унарных вызовов
Future<void> demonstrateBasicUnary(RpcEndpoint client) async {
  print('\n--- Базовые унарные вызовы ---');

  // Сложение чисел
  final addResult = await client.invoke(
    'Calculator',
    'add',
    {'a': 5, 'b': 3},
  );
  print('5 + 3 = ${addResult['result']}');

  // Конкатенация строк
  final concatResult = await client.invoke(
    'StringService',
    'concat',
    {
      'strings': ['Привет', 'мир', 'RPC'],
      'separator': ', ',
    },
  );
  print('Конкатенация: ${concatResult['result']}');
}

/// Демонстрация типизированных унарных вызовов
Future<void> demonstrateTypedUnary(RpcEndpoint client) async {
  print('\n--- Типизированные унарные вызовы ---');

  final request = GreetingRequest(name: 'Пользователь');

  final response = await client
      .unary('TypedService', 'greet')
      .call<GreetingRequest, GreetingResponse>(
        request: request,
        responseParser: GreetingResponse.fromJson,
      );

  print('Получено сообщение: ${response.message}');
  print('Время отправки: ${response.timestamp}');
}

/// Демонстрация обработки ошибок
Future<void> demonstrateErrorHandling(RpcEndpoint client) async {
  print('\n--- Обработка ошибок ---');

  try {
    await client.invoke(
      'ErrorService',
      'divide',
      {'a': 10, 'b': 0},
    );
    print('Этот код не должен выполниться');
  } catch (e) {
    print('Перехвачена ошибка: $e');
  }

  // Успешное деление
  final divideResult = await client.invoke(
    'ErrorService',
    'divide',
    {'a': 10, 'b': 2},
  );
  print('10 / 2 = ${divideResult['result']}');
}

/// Класс запроса приветствия
class GreetingRequest implements IRpcSerializableMessage {
  final String name;

  GreetingRequest({required this.name});

  @override
  Map<String, dynamic> toJson() => {'name': name};

  static GreetingRequest fromJson(Map<String, dynamic> json) {
    return GreetingRequest(name: json['name'] as String);
  }
}

/// Класс ответа с приветствием
class GreetingResponse implements IRpcSerializableMessage {
  final String message;
  final String timestamp;

  GreetingResponse({
    required this.message,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
        'message': message,
        'timestamp': timestamp,
      };

  static GreetingResponse fromJson(Map<String, dynamic> json) {
    return GreetingResponse(
      message: json['message'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}
