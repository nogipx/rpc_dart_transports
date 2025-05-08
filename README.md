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

### С использованием контрактов (декларативный подход):

```dart
// Определение контракта с двунаправленным методом
abstract base class ChatServiceContract extends DeclarativeRpcServiceContract<ChatMessage> {
  @override
  final String serviceName = 'ChatService';

  @override
  void registerMethodsFromClass() {
    addBidirectionalStreamingMethod<ChatMessage, ChatMessage>(
      methodName: 'chat',
      handler: chat,
      argumentParser: ChatMessage.fromJson,
      responseParser: ChatMessage.fromJson,
    );
  }

  // Метод принимает поток сообщений и возвращает поток ответов
  Stream<ChatMessage> chat(Stream<ChatMessage> messages);
}

// Реализация на сервере
final class ServerChatService extends ChatServiceContract {
  @override
  Stream<ChatMessage> chat(Stream<ChatMessage> messages) async* {
    // Обрабатываем каждое входящее сообщение
    await for (final message in messages) {
      print('Сервер получил: ${message.text}');
      
      // Отправляем ответ
      yield ChatMessage(
        'server',
        'Ответ на: ${message.text}',
        DateTime.now(),
      );
    }
  }
}

// Реализация на клиенте
final class ClientChatService extends ChatServiceContract {
  final RpcEndpoint client;
  
  ClientChatService(this.client);
  
  @override
  Stream<ChatMessage> chat(Stream<ChatMessage> messages) {
    return client.openBidirectionalStream<ChatMessage, ChatMessage>(
      serviceName,
      'chat',
      messages,
    );
  }
}

// Использование
final chatServer = ServerChatService();
serverEndpoint.registerContract(chatServer);

final chatClient = ClientChatService(clientEndpoint);

// Создаем контроллер для отправки сообщений
final messageController = StreamController<ChatMessage>();

// Открываем двунаправленный стрим
final responses = chatClient.chat(messageController.stream);

// Подписываемся на ответы
responses.listen((message) {
  print('Клиент получил: ${message.text}');
});

// Отправляем сообщения
messageController.add(ChatMessage('client', 'Привет!', DateTime.now()));
```

### Упрощенный подход с BidirectionalChannel

```dart
// Регистрируем обработчик на сервере
serverEndpoint.registerBidirectionalHandler(
  'EchoService',
  'echo',
  (incomingStream, messageId) {
    print('[Сервер]: Принимаю входящие сообщения...');
    
    // Просто отправляем назад сообщения с префиксом
    return incomingStream.map((data) {
      print('[Сервер]: Получено: $data');
      
      if (data is String) {
        return 'Эхо: $data';
      } else if (data is Map<String, dynamic> && data['text'] != null) {
        return 'Эхо: ${data['text']}';
      } else {
        return 'Получено неизвестное сообщение';
      }
    });
  },
);

// Создаем двунаправленный канал на клиенте
final channel = clientEndpoint.createBidirectionalChannel(
  'EchoService',
  'echo',
);

// Подписываемся на входящие сообщения
channel.listen(
  (message) => print('[Клиент]: Получил ответ: $message'),
  onError: (e) => print('[Клиент]: Ошибка: $e'),
  onDone: () => print('[Клиент]: Соединение закрыто'),
);

// Отправляем сообщения
channel.send('Привет, сервер!');

// Закрываем канал когда он больше не нужен
await channel.close();
```

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
