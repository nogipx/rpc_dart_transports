# RPC Dart

Платформонезависимая реализация gRPC-подобного протокола для Dart/Flutter.

## Особенности

- 🚀 **Платформонезависимость** - работает на всех платформах Dart/Flutter
- 🔄 **Двунаправленная коммуникация** - поддержка двусторонней передачи данных
- 🔐 **Типобезопасность** - строгая типизация API через контракты сервисов
- 📦 **Декларативные сервисы** - четкое определение API через контракты
- 🔁 **Различные типы RPC** - унарные вызовы, серверный и клиентский стриминг, bidirectional
- 🧩 **Расширяемость** - поддержка плагинов, middleware и кастомных транспортов

## Установка

```yaml
dependencies:
  rpc_dart: ^0.1.0
```

## Архитектура

- **RpcTransport** - обеспечивает передачу двоичных данных между узлами
- **RpcSerializer** - сериализует и десериализует сообщения
- **RpcEndpoint** - базовый API для регистрации и вызова методов
- **RpcMiddleware** - промежуточная обработка запросов и ответов
- **RpcServiceContract** - описание методов сервиса с типизацией
- **RpcMethod** - представление методов RPC (унарные, стриминговые)

## Быстрый старт

```dart
import 'package:rpc_dart/rpc_dart.dart';

void main() async {
  // Настройка транспорта и сериализатора
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  
  final serializer = JsonSerializer();
  final client = RpcEndpoint(clientTransport, serializer);
  final server = RpcEndpoint(serverTransport, serializer);
  
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
  
  // Освобождение ресурсов
  await client.close();
  await server.close();
}
```

## Стриминг данных

```dart
// Регистрация стрима на сервере
server.registerMethod(
  'StreamService',
  'generateNumbers',
  (context) async {
    final count = context.payload['count'] as int;
    final messageId = context.messageId;
    
    // Запуск асинхронной генерации
    Future.microtask(() async {
      for (var i = 1; i <= count; i++) {
        await server.sendStreamData(messageId, i);
        await Future.delayed(Duration(milliseconds: 100));
      }
      await server.closeStream(messageId);
    });
    
    return {'status': 'started'};
  },
);

// Получение данных на клиенте
final stream = client.openStream(
  'StreamService',
  'generateNumbers',
  request: {'count': 5},
);

stream.listen(
  (data) => print('Получено: $data'),
  onDone: () => print('Стрим завершен'),
);
```

## Двунаправленный стриминг (Bidirectional)

```dart
// Регистрация на сервере
server.bidirectional('ChatService', 'chat')
    .register<ChatMessage, ChatMessage>(
      handler: (incomingStream, messageId) {
        // Обрабатываем входящие сообщения и отправляем ответы
        return incomingStream.map((message) {
          print('Сервер получил: ${message.text}');
          return ChatMessage(
            text: 'Ответ на: ${message.text}',
            sender: 'server',
          );
        });
      },
      requestParser: ChatMessage.fromJson,
      responseParser: ChatMessage.fromJson,
    );

// Создание канала на клиенте
final channel = client
    .bidirectional('ChatService', 'chat')
    .createChannel<ChatMessage, ChatMessage>(
      requestParser: ChatMessage.fromJson,
      responseParser: ChatMessage.fromJson,
    );

// Подписка на входящие сообщения
channel.incoming.listen(
  (message) => print('Клиент получил: ${message.text}'),
  onDone: () => print('Канал закрыт'),
);

// Отправка сообщений
channel.send(ChatMessage(text: 'Привет, сервер!', sender: 'client'));

// Закрытие канала
await channel.close();
```

## Контракты сервисов

Контракты позволяют декларативно описать структуру сервиса с типизированными методами:

```dart
// Определение контракта
abstract base class CalculatorContract 
    extends RpcServiceContract<RpcSerializableMessage> {
  
  @override
  final String serviceName = 'CalculatorService';
  
  RpcEndpoint? get endpoint;

  @override
  void registerMethodsFromClass() {
    // Унарный метод
    addUnaryMethod<CalculatorRequest, CalculatorResponse>(
      methodName: 'add',
      handler: add,
      argumentParser: CalculatorRequest.fromJson,
      responseParser: CalculatorResponse.fromJson,
    );
    
    // Стриминговый метод
    addServerStreamingMethod<SequenceRequest, SequenceData>(
      methodName: 'generateSequence',
      handler: generateSequence,
      argumentParser: SequenceRequest.fromJson,
      responseParser: SequenceData.fromJson,
    );
  }
  
  // Объявление методов
  Future<CalculatorResponse> add(CalculatorRequest request);
  Stream<SequenceData> generateSequence(SequenceRequest request);
}

// Реализация контракта на сервере
final class ServerCalculatorContract extends CalculatorContract {
  @override
  RpcEndpoint? get endpoint => null;
  
  @override
  Future<CalculatorResponse> add(CalculatorRequest request) async {
    return CalculatorResponse(request.a + request.b);
  }
  
  @override
  Stream<SequenceData> generateSequence(SequenceRequest request) async* {
    for (int i = 1; i <= request.count; i++) {
      yield SequenceData(i);
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
}

// Реализация контракта на клиенте
final class ClientCalculatorContract extends CalculatorContract {
  @override
  final RpcEndpoint endpoint;
  
  ClientCalculatorContract(this.endpoint);
  
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
  Stream<SequenceData> generateSequence(SequenceRequest request) {
    return endpoint
        .serverStreaming(serviceName, 'generateSequence')
        .openStream<SequenceRequest, SequenceData>(
          request,
          responseParser: SequenceData.fromJson,
        );
  }
}

// Регистрация контрактов
serverEndpoint.registerServiceContract(ServerCalculatorContract());
clientEndpoint.registerServiceContract(ClientCalculatorContract(clientEndpoint));

// Использование
final contract = ClientCalculatorContract(clientEndpoint);
final result = await contract.add(CalculatorRequest(5, 10));
print('Результат: ${result.result}'); // Результат: 15
```

## Дополнительные примеры

Больше примеров можно найти в директории `example/`:

- Унарные вызовы
- Серверный стриминг
- Клиентский стриминг
- Двунаправленный стриминг
- Использование контрактов
- WebSocket транспорт

## Типизированные контракты

```dart
// Сообщения
class CalculatorRequest implements RpcSerializableMessage {
  final int a;
  final int b;

  CalculatorRequest(this.a, this.b);

  @override
  Map<String, dynamic> toJson() => {'a': a, 'b': b};

  static CalculatorRequest fromJson(Map<String, dynamic> json) {
    return CalculatorRequest(json['a'] as int, json['b'] as int);
  }
}

class CalculatorResponse implements RpcSerializableMessage {
  final int result;

  CalculatorResponse(this.result);

  @override
  Map<String, dynamic> toJson() => {'result': result};

  static CalculatorResponse fromJson(Map<String, dynamic> json) {
    return CalculatorResponse(json['result'] as int);
  }
}

// Контракт сервиса
abstract base class CalculatorContract extends RpcServiceContract {
  @override
  final String serviceName = 'CalculatorService';

  @override
  void registerMethodsFromClass() {
    // Унарные методы
    addUnaryMethod<CalculatorRequest, CalculatorResponse>(
      methodName: 'add',
      handler: add,
      argumentParser: CalculatorRequest.fromJson,
      responseParser: CalculatorResponse.fromJson,
    );
    
    addUnaryMethod<CalculatorRequest, CalculatorResponse>(
      methodName: 'multiply',
      handler: multiply,
      argumentParser: CalculatorRequest.fromJson,
      responseParser: CalculatorResponse.fromJson,
    );
    
    // Стриминговый метод
    addServerStreamingMethod<SequenceRequest, SequenceResponse>(
      methodName: 'generateSequence',
      handler: generateSequence,
      argumentParser: SequenceRequest.fromJson,
      responseParser: SequenceResponse.fromJson,
    );
  }

  // Абстрактные методы контракта
  Future<CalculatorResponse> add(CalculatorRequest request);
  Future<CalculatorResponse> multiply(CalculatorRequest request);
  Stream<SequenceResponse> generateSequence(SequenceRequest request);
}
```

## Транспорты

По умолчанию библиотека включает:

- **MemoryTransport** - для обмена в пределах одного процесса
- **IsolateTransport** - для обмена между изолятами
- **WebSocketTransport** - для обмена через WebSocket соединения

### Пример WebSocket транспорта

```dart
// Клиентская часть
final wsClientTransport = WebSocketTransport('client', 'ws://localhost:8080', 
  autoConnect: true);
final clientEndpoint = RpcEndpoint(wsClientTransport, JsonSerializer());

// Серверная часть (при наличии WebSocket сервера)
final server = await HttpServer.bind('localhost', 8080);
await for (var request in server) {
  if (request.uri.path == '/ws') {
    final socket = await WebSocketTransformer.upgrade(request);
    final transport = WebSocketTransport.fromWebSocket('server', socket);
    final endpoint = RpcEndpoint(transport, JsonSerializer());
    
    // Регистрация методов...
  }
}
```

## Middleware и расширения

```dart
// Добавление логирования
client.addMiddleware(DebugMiddleware(id: 'client'));

// Добавление middleware для изменения запросов
server.addMiddleware(
  RpcMiddleware(
    onRequest: (request) {
      // Модифицируем запрос
      final metadata = request.metadata ?? {};
      metadata['timestamp'] = DateTime.now().toIso8601String();
      return request.copyWith(metadata: metadata);
    },
    onResponse: (response) {
      // Можем модифицировать ответ
      return response;
    },
  ),
);
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

## Контекст метода (RpcMethodContext)

При обработке запросов каждый обработчик получает контекст с полями:
- `messageId` - уникальный ID сообщения
- `payload` - данные запроса
- `metadata` - дополнительные метаданные
- `serviceName` - имя сервиса
- `methodName` - имя метода

## Клиентский стриминг (Client Streaming)

```dart
// Регистрация обработчика на сервере
server.clientStreaming('SumService', 'calculateSum')
    .register<NumberValue, SumResult>(
      handler: (stream) async {
        int sum = 0;
        await for (final value in stream) {
          sum += value.number;
        }
        return SumResult(sum);
      },
      requestParser: NumberValue.fromJson,
      responseParser: SumResult.fromJson,
    );

// Использование на клиенте
final (controller, resultFuture) = client
    .clientStreaming('SumService', 'calculateSum')
    .openClientStream<NumberValue, SumResult>(
      responseParser: SumResult.fromJson,
    );

// Отправляем числа
controller.add(NumberValue(10));
controller.add(NumberValue(20));
controller.add(NumberValue(30));

// Завершаем поток и получаем результат
await controller.close();
final result = await resultFuture;
print('Сумма: ${result.total}'); // Сумма: 60
```

## Статусы транспорта

RPC Dart предоставляет статусы выполнения операций транспорта:

```dart
enum RpcTransportActionStatus {
  success,
  transportUnavailable,
  connectionClosed,
  connectionNotEstablished,
  unknownError,
}
```

Это позволяет точно определить причину проблемы при отправке сообщений.
