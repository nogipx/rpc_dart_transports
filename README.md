# RPC Dart

Платформонезависимая реализация gRPC-подобного протокола для Dart/Flutter.

## Особенности

- 🚀 **Платформонезависимость** - работает на всех платформах Dart/Flutter
- 🔄 **Двунаправленная коммуникация** - поддержка двусторонней передачи данных
- 🔐 **Типобезопасность** - строгая типизация API через контракты сервисов
- 🔁 **Различные типы RPC** - унарные вызовы, серверный и клиентский стриминг, двунаправленный стриминг
- 🧩 **Расширяемость** - поддержка middleware и кастомных транспортов

## Установка

```yaml
dependencies:
  rpc_dart: ^0.1.0
```

## Архитектура

- **RpcTransport** - обеспечивает передачу данных между узлами
- **RpcSerializer** - сериализует и десериализует сообщения
- **RpcEndpoint** - базовый API для регистрации и вызова методов
- **RpcMiddleware** - промежуточная обработка запросов и ответов
- **RpcServiceContract** - описание методов сервиса с типизацией

## Быстрый старт

```dart
import 'package:rpc_dart/rpc_dart.dart';

void main() async {
  // Настройка транспорта
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  
  // Создание эндпоинтов
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
  
  // Регистрация метода на сервере
  server.registerMethod(
    'CalculatorService',
    'add',
    (context) async {
      final payload = context.payload as Map<String, dynamic>;
      return {'result': payload['a'] + payload['b']};
    },
  );
  
  // Вызов метода с клиента
  final result = await client.invoke(
    'CalculatorService',
    'add',
    {'a': 5, 'b': 3},
  );
  
  print('Результат: ${result['result']}'); // Результат: 8
  
  await client.close();
  await server.close();
}
```

## Типы вызовов

### Унарные вызовы

Стандартный вызов с одним запросом и одним ответом.

```dart
// На сервере
server.unary('CalculatorService', 'add').register<CalculatorRequest, CalculatorResponse>(
  handler: (request) async {
    return CalculatorResponse(request.a + request.b);
  },
  requestParser: CalculatorRequest.fromJson,
  responseParser: CalculatorResponse.fromJson,
);

// На клиенте
final result = await client
    .unary('CalculatorService', 'add')
    .call<CalculatorRequest, CalculatorResponse>(
      CalculatorRequest(5, 3),
      responseParser: CalculatorResponse.fromJson,
    );
```

### Серверный стриминг

Сервер возвращает поток данных в ответ на один запрос.

```dart
// На сервере
server.serverStreaming('CounterService', 'count').register<CountRequest, NumberMessage>(
  handler: (request) async* {
    for (int i = 1; i <= request.count; i++) {
      yield NumberMessage(i);
      await Future.delayed(Duration(milliseconds: 100));
    }
  },
  requestParser: CountRequest.fromJson,
  responseParser: NumberMessage.fromJson,
);

// На клиенте
final stream = client
    .serverStreaming('CounterService', 'count')
    .openStream<CountRequest, NumberMessage>(
      CountRequest(5),
      responseParser: NumberMessage.fromJson,
    );

stream.listen((data) => print('Получено: ${data.value}'));
```

### Клиентский стриминг

Клиент отправляет поток данных, сервер возвращает один ответ.

```dart
// На сервере
server.clientStreaming('SumService', 'calculateSum').register<NumberMessage, SumResult>(
  handler: (stream) async {
    int sum = 0;
    await for (final value in stream) {
      sum += value.value;
    }
    return SumResult(sum);
  },
  requestParser: NumberMessage.fromJson,
  responseParser: SumResult.fromJson,
);

// На клиенте
final clientStream = client
    .clientStreaming('SumService', 'calculateSum')
    .openClientStream<NumberMessage, SumResult>(
      responseParser: SumResult.fromJson,
    );

// Отправляем числа
clientStream.controller.add(NumberMessage(10));
clientStream.controller.add(NumberMessage(20));
clientStream.controller.add(NumberMessage(30));

// Завершаем поток и получаем результат
clientStream.controller.close();
final result = await clientStream.response;
print('Сумма: ${result.total}'); // Сумма: 60
```

### Двунаправленный стриминг

Клиент и сервер обмениваются потоками данных одновременно.

```dart
// На сервере
server.bidirectional('ChatService', 'chat').register<ChatMessage, ChatMessage>(
  handler: (incomingStream, messageId) {
    return incomingStream.map((message) {
      return ChatMessage(
        text: 'Ответ на: ${message.text}',
        sender: 'server',
      );
    });
  },
  requestParser: ChatMessage.fromJson,
  responseParser: ChatMessage.fromJson,
);

// На клиенте
final channel = client
    .bidirectional('ChatService', 'chat')
    .createChannel<ChatMessage, ChatMessage>(
      requestParser: ChatMessage.fromJson,
      responseParser: ChatMessage.fromJson,
    );

// Подписка на входящие сообщения
channel.incoming.listen(
  (message) => print('Получено: ${message.text}'),
);

// Отправка сообщений
channel.send(ChatMessage(text: 'Привет!', sender: 'client'));
```

## Контракты сервисов

Контракты позволяют декларативно описать структуру сервиса:

```dart
// Определение контракта
abstract base class CalculatorContract extends RpcServiceContract {
  @override
  final String serviceName = 'CalculatorService';

  @override
  void registerMethodsFromClass() {
    addUnaryMethod<CalculatorRequest, CalculatorResponse>(
      methodName: 'add',
      handler: add,
      argumentParser: CalculatorRequest.fromJson,
      responseParser: CalculatorResponse.fromJson,
    );
    
    addServerStreamingMethod<CountRequest, NumberMessage>(
      methodName: 'generateSequence',
      handler: generateSequence,
      argumentParser: CountRequest.fromJson,
      responseParser: NumberMessage.fromJson,
    );
  }
  
  // Абстрактные методы
  Future<CalculatorResponse> add(CalculatorRequest request);
  Stream<NumberMessage> generateSequence(CountRequest request);
}

// Реализация на сервере
final class ServerCalculator extends CalculatorContract {
  @override
  Future<CalculatorResponse> add(CalculatorRequest request) async {
    return CalculatorResponse(request.a + request.b);
  }
  
  @override
  Stream<NumberMessage> generateSequence(CountRequest request) async* {
    for (int i = 1; i <= request.count; i++) {
      yield NumberMessage(i);
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
}

// Реализация на клиенте
final class ClientCalculator extends CalculatorContract {
  final RpcEndpoint endpoint;
  
  ClientCalculator(this.endpoint);
  
  @override
  Future<CalculatorResponse> add(CalculatorRequest request) {
    return endpoint
        .unary(serviceName, 'add')
        .call<CalculatorRequest, CalculatorResponse>(
          request,
          responseParser: CalculatorResponse.fromJson,
        );
  }
  
  @override
  Stream<NumberMessage> generateSequence(CountRequest request) {
    return endpoint
        .serverStreaming(serviceName, 'generateSequence')
        .openStream<CountRequest, NumberMessage>(
          request,
          responseParser: NumberMessage.fromJson,
        );
  }
}

// Регистрация контрактов
final calculator = ClientCalculator(clientEndpoint);
serverEndpoint.registerServiceContract(ServerCalculator());
clientEndpoint.registerServiceContract(calculator);

// Использование на клиенте
final result = await calculator.add(CalculatorRequest(5, 10));
print('Результат: ${result.result}'); // Результат: 15

final numberStream = calculator.generateSequence(CountRequest(5));
numberStream.listen((number) => print('Получено: ${number.value}'));
```

## Транспорты

Библиотека включает:

- **MemoryTransport** - для обмена в рамках одного процесса
- **WebSocketTransport** - для обмена через WebSocket соединения
- **IsolateTransport** - для обмена между изолятами

Все транспорты реализуют общий интерфейс, что позволяет легко заменять их.

## Middleware

Middleware позволяют перехватывать и модифицировать запросы и ответы:

```dart
// Встроенные middleware
endpoint.addMiddleware(LoggingMiddleware(id: 'client'));
endpoint.addMiddleware(TimingMiddleware());

// Собственные middleware
class AuthMiddleware implements SimpleRpcMiddleware {
  final String authToken;
  
  AuthMiddleware(this.authToken);
  
  @override
  FutureOr<dynamic> onRequest(
    String serviceName, 
    String methodName, 
    dynamic payload, 
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    if (direction == RpcDataDirection.toRemote) {
      final mutableContext = context as MutableRpcMethodContext;
      mutableContext.metadata ??= {};
      mutableContext.metadata!['auth_token'] = authToken;
    }
    return payload;
  }
}

endpoint.addMiddleware(AuthMiddleware('user-token-123'));
```

### Функциональные middleware с RpcMiddlewareWrapper

Для быстрого создания middleware без реализации полного интерфейса:

```dart
final authMiddleware = RpcMiddlewareWrapper(
  debugLabel: 'Auth',
  onRequestHandler: (serviceName, methodName, payload, context, direction) {
    if (direction == RpcDataDirection.toRemote) {
      if (isProtectedMethod(serviceName, methodName)) {
        final token = getAuthToken();
        final mutableContext = context as MutableRpcMethodContext;
        mutableContext.metadata ??= {};
        mutableContext.metadata!['Authorization'] = 'Bearer $token';
      }
    }
    return payload;
  },
);

endpoint.addMiddleware(authMiddleware);
```

## Обработка ошибок

```dart
try {
  final result = await client.invoke(
    'CalculatorService',
    'divide',
    {'a': 10, 'b': 0},
  );
} catch (e) {
  if (e is RpcException) {
    print('RPC ошибка: ${e.message}, код: ${e.code}');
  } else {
    print('Неизвестная ошибка: $e');
  }
}
```

## Дополнительные примеры

Больше примеров можно найти в директории `example/`:

- `calculator_example.dart` - Унарные вызовы
- `stream_example.dart` - Серверный и клиентский стриминг
- `bidirectional_example.dart` - Двунаправленный стриминг
- `contracts_example.dart` - Использование контрактов
- `websocket_example.dart` - WebSocket транспорт
