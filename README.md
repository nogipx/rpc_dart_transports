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
server.bidirectionalMethod('ChatService', 'chat')
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
    .bidirectionalMethod('ChatService', 'chat')
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
    extends DeclarativeRpcServiceContract<RpcSerializableMessage> {
  
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
        .unaryMethod(serviceName, 'add')
        .call<CalculatorRequest, CalculatorResponse>(
          request,
          responseParser: CalculatorResponse.fromJson,
        );
  }
  
  @override
  Stream<SequenceData> generateSequence(SequenceRequest request) {
    return endpoint
        .serverStreamingMethod(serviceName, 'generateSequence')
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
abstract base class CalculatorContract extends DeclarativeRpcServiceContract {
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

// Реализация на сервере
final class ServerCalculatorContract extends CalculatorContract {
  @override
  Future<CalculatorResponse> add(CalculatorRequest request) async {
    return CalculatorResponse(request.a + request.b);
  }
  
  @override
  Future<CalculatorResponse> multiply(CalculatorRequest request) async {
    return CalculatorResponse(request.a * request.b);
  }
  
  @override
  Stream<SequenceResponse> generateSequence(SequenceRequest request) {
    return Stream.periodic(
      Duration(milliseconds: 200),
      (i) => SequenceResponse(i + 1),
    ).take(request.count);
  }
}

// Реализация на клиенте
final class ClientCalculatorContract extends CalculatorContract {
  final RpcEndpoint client;
  
  ClientCalculatorContract(this.client);
  
  @override
  Future<CalculatorResponse> add(CalculatorRequest request) {
    return client.invokeTyped<CalculatorRequest, CalculatorResponse>(
      serviceName: serviceName,
      methodName: 'add',
      request: request,
    );
  }
  
  @override
  Future<CalculatorResponse> multiply(CalculatorRequest request) {
    return client.invokeTyped<CalculatorRequest, CalculatorResponse>(
      serviceName: serviceName,
      methodName: 'multiply',
      request: request,
    );
  }
  
  @override
  Stream<SequenceResponse> generateSequence(SequenceRequest request) {
    return client.openTypedStream<SequenceRequest, SequenceResponse>(
      serviceName,
      'generateSequence',
      request: request,
    );
  }
}

// Использование
final serverContract = ServerCalculatorContract();
server.registerContract(serverContract);

final calculator = ClientCalculatorContract(client);
final response = await calculator.add(CalculatorRequest(10, 5));
print('Результат: ${response.result}'); // Результат: 15
```

## Middleware и расширения

```dart
// Добавление логирования
client.addMiddleware(LoggingMiddleware(
  logger: (message) => print(message),
));

// Добавление измерения времени запросов
server.addMiddleware(TimingMiddleware(
  onTiming: (message, duration) => print(
    'Время выполнения: $message - ${duration.inMilliseconds}ms',
  ),
));

// Доступные встроенные middleware
// - LoggingMiddleware - логирование
// - TimingMiddleware - измерение времени
// - DebugMiddleware - отладка
// - MetadataMiddleware - работа с метаданными
```

## Транспорты

По умолчанию библиотека включает:

- **MemoryTransport** - для обмена в пределах одного процесса
- **IsolateTransport** - для обмена между изолятами

### Пользовательский транспорт

```dart
class WebSocketTransport implements RpcTransport {
  @override
  final String id;
  
  final WebSocket _socket;
  final StreamController<Uint8List> _incomingController = StreamController<Uint8List>.broadcast();
  bool _isAvailable = true;
  
  WebSocketTransport(this.id, this._socket) {
    _socket.listen(
      (data) => _incomingController.add(data is Uint8List ? data : Uint8List.fromList(data)),
      onDone: () => _isAvailable = false,
      onError: (e) => _isAvailable = false,
    );
  }
  
  @override
  Future<void> send(Uint8List data) async {
    if (!isAvailable) throw StateError('Transport is not available');
    _socket.add(data);
  }
  
  @override
  Stream<Uint8List> receive() => _incomingController.stream;
  
  @override
  Future<void> close() async {
    _isAvailable = false;
    await _socket.close();
    await _incomingController.close();
  }
  
  @override
  bool get isAvailable => _isAvailable && _socket.readyState == WebSocket.open;
}
```

## Контекст метода (RpcMethodContext)

При обработке запросов каждый обработчик получает контекст с полями:
- `messageId` - уникальный ID сообщения
- `payload` - данные запроса
- `metadata` - дополнительные метаданные
- `serviceName` - имя сервиса
- `methodName` - имя метода

## Типизированные вызовы методов

```dart
// Типизированные сообщения
class CalculatorRequest implements RpcSerializableMessage {
  final int a;
  final int b;

  CalculatorRequest(this.a, this.b);

  @override
  Map<String, dynamic> toJson() => {'a': a, 'b': b};

  static CalculatorRequest fromJson(Map<String, dynamic> json) {
    return CalculatorRequest(
      json['a'] as int, 
      json['b'] as int,
    );
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

// Регистрация унарного метода на сервере
server.unaryMethod('CalculatorService', 'add')
    .register<CalculatorRequest, CalculatorResponse>(
      handler: (request) async {
        return CalculatorResponse(request.a + request.b);
      },
      requestParser: CalculatorRequest.fromJson,
      responseParser: CalculatorResponse.fromJson,
    );

// Вызов типизированного унарного метода с клиента
final response = await client
    .unaryMethod('CalculatorService', 'add')
    .call<CalculatorRequest, CalculatorResponse>(
      CalculatorRequest(5, 3),
      responseParser: CalculatorResponse.fromJson,
    );
    
print('Результат: ${response.result}'); // Результат: 8
```

## Стриминг данных (Server Streaming)

```dart
// Регистрация стрима на сервере
server.serverStreamingMethod('NumberService', 'generateNumbers')
    .register<NumberRequest, NumberResponse>(
      handler: (request) async* {
        for (var i = 1; i <= request.count; i++) {
          yield NumberResponse(i);
          await Future.delayed(Duration(milliseconds: 100));
        }
      },
      requestParser: NumberRequest.fromJson,
      responseParser: NumberResponse.fromJson,
    );

// Получение данных на клиенте
final stream = client
    .serverStreamingMethod('NumberService', 'generateNumbers')
    .openStream<NumberRequest, NumberResponse>(
      NumberRequest(5),
      responseParser: NumberResponse.fromJson,
    );

stream.listen(
  (data) => print('Получено: ${data.value}'),
  onDone: () => print('Стрим завершен'),
);
```

## Клиентский стриминг (Client Streaming)

```dart
// Регистрация обработчика на сервере
server.clientStreamingMethod('SumService', 'calculateSum')
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
    .clientStreamingMethod('SumService', 'calculateSum')
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
