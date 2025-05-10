Платформонезависимая реализация RPC (Remote Procedure Call) протокола для Dart и Flutter.

[![Pub Version](https://img.shields.io/pub/v/rpc_dart.svg)](https://pub.dev/packages/rpc_dart)

## Особенности

- 🚀 **Кроссплатформенность** - работает на всех платформах, где поддерживается Dart/Flutter
- 🌐 **Независимость от транспорта** - поддержка различных транспортных протоколов (WebSocket, Memory, Isolate)
- 💪 **Типобезопасность** - строгая типизация контрактов и сообщений
- 🔄 **Поддержка всех типов RPC** - унарные вызовы, серверный стриминг, клиентский стриминг, двунаправленный стриминг
- 🧩 **Middleware** - расширение функциональности через промежуточные обработчики
- 📝 **Сериализация** - поддержка JSON и возможность добавления кастомных сериализаторов

## Основные компоненты

- **RpcEndpoint** - основной компонент для взаимодействия с RPC
- **RpcTransport** - абстракция транспортного уровня (WebSocket, Memory, Isolate)
- **RpcSerializer** - сериализация/десериализация сообщений (JSON)
- **RpcServiceContract** - контракты для описания API сервисов
- **RpcMiddleware** - промежуточные обработчики для запросов/ответов

## Типы RPC взаимодействий

RPC Dart поддерживает четыре типа взаимодействий:

1. **Унарный RPC** - один запрос → один ответ
2. **Серверный стриминг** - один запрос → поток ответов
3. **Клиентский стриминг** - поток запросов → один ответ
4. **Двунаправленный стриминг** - поток запросов ↔ поток ответов

## Быстрый старт

### Базовая настройка

```dart
import 'package:rpc_dart/rpc_dart.dart';

void main() async {
  // Создание транспортов (в памяти для примера)
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');
  
  // Соединение транспортов
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  
  // Создание RPC эндпоинтов
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
  
  // Добавление middleware для логирования (опционально)
  client.addMiddleware(LoggingMiddleware(id: 'client'));
  server.addMiddleware(LoggingMiddleware(id: 'server'));
  
  // После использования закрываем эндпоинты
  await client.close();
  await server.close();
}
```

### Примеры вызовов

#### Унарный RPC

```dart
// На сервере
server.unary('CalculatorService', 'add').register<CalculatorRequest, CalculatorResponse>(
  handler: (request) async {
    return CalculatorResponse(sum: request.a + request.b);
  },
  requestParser: CalculatorRequest.fromJson,
  responseParser: CalculatorResponse.fromJson,
);

// На клиенте
final result = await client
    .unary('CalculatorService', 'add')
    .call<CalculatorRequest, CalculatorResponse>(
      request: CalculatorRequest(a: 5, b: 3),
      responseParser: CalculatorResponse.fromJson,
    );

print('Сумма: ${result.sum}'); // Сумма: 8
```

#### Серверный стриминг

```dart
// На сервере
server.serverStreaming('TaskService', 'startTask').register<TaskRequest, ProgressMessage>(
  handler: (request) async* {
    for (int i = 0; i <= 100; i += 10) {
      yield ProgressMessage(
        taskId: request.taskId,
        progress: i,
        status: i == 100 ? 'completed' : 'in_progress',
        message: 'Выполнено $i%',
      );
      await Future.delayed(Duration(milliseconds: 100));
    }
  },
  requestParser: TaskRequest.fromJson,
  responseParser: ProgressMessage.fromJson,
);

// На клиенте
final stream = client
    .serverStreaming('TaskService', 'startTask')
    .openStream<TaskRequest, ProgressMessage>(
      request: TaskRequest(taskId: 'task-123', taskName: 'Обработка'),
      responseParser: ProgressMessage.fromJson,
    );

// Подписка на обновления
await for (final update in stream) {
  print('Прогресс: ${update.progress}%, ${update.message}');
}
```

#### Клиентский стриминг

```dart
// На сервере
server.clientStreaming('UploadService', 'uploadFile').register<FileChunk, UploadResult>(
  handler: (stream) async {
    int totalSize = 0;
    int chunks = 0;
    
    await for (final chunk in stream) {
      totalSize += chunk.data.length;
      chunks++;
    }
    
    return UploadResult(
      success: true,
      totalSize: totalSize,
      chunks: chunks,
    );
  },
  requestParser: FileChunk.fromJson,
  responseParser: UploadResult.fromJson,
);

// На клиенте
final clientStream = client
    .clientStreaming('UploadService', 'uploadFile')
    .openClientStream<FileChunk, UploadResult>(
      responseParser: UploadResult.fromJson,
    );

final controller = clientStream.controller!;

// Отправка данных
controller.add(FileChunk(data: [/* данные */], index: 1));
controller.add(FileChunk(data: [/* данные */], index: 2));
await controller.close();

// Получение результата
final result = await clientStream.response;
print('Загружено ${result!.totalSize} байт в ${result.chunks} частях');
```

#### Двунаправленный стриминг

```dart
// На сервере
server.bidirectional('ChatService', 'chat').register<ChatMessage, ChatMessage>(
  handler: (incomingStream, messageId) {
    // Обработка входящих сообщений и возврат стрима ответов
    return incomingStream.map((message) {
      return ChatMessage(
        sender: 'Сервер',
        text: 'Ответ на: ${message.text}',
        timestamp: DateTime.now().toIso8601String(),
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
      responseParser: ChatMessage.fromJson,
    );

// Подписка на входящие сообщения
channel.incoming.listen((message) {
  print('${message.sender}: ${message.text}');
});

// Отправка сообщений
channel.send(ChatMessage(
  sender: 'Клиент',
  text: 'Привет!',
  timestamp: DateTime.now().toIso8601String(),
));

// После использования закрываем канал
await channel.close();
```

## Контракты сервисов

Рекомендуемый подход к организации RPC API - использование контрактов сервисов:

```dart
// Определение контракта
abstract base class CalculatorContract extends RpcServiceContract {
  @override
  String get serviceName => 'CalculatorService';

  @override
  void setup() {
    // Регистрация унарного метода
    addUnaryMethod<ComputeRequest, ComputeResult>(
      methodName: 'compute',
      handler: compute,
      argumentParser: ComputeRequest.fromJson,
      responseParser: ComputeResult.fromJson,
    );
  }

  // Абстрактный метод, который должен быть реализован
  Future<ComputeResult> compute(ComputeRequest request);
}

// Серверная реализация
final class ServerCalculator extends CalculatorContract {
  @override
  Future<ComputeResult> compute(ComputeRequest request) async {
    final sum = request.value1 + request.value2;
    final difference = request.value1 - request.value2;
    final product = request.value1 * request.value2;
    final quotient = request.value1 / request.value2;
    
    return ComputeResult(
      sum: sum,
      difference: difference,
      product: product,
      quotient: quotient,
    );
  }
}

// Клиентская реализация
final class ClientCalculator extends CalculatorContract {
  final RpcEndpoint _endpoint;
  
  ClientCalculator(this._endpoint);
  
  @override
  Future<ComputeResult> compute(ComputeRequest request) {
    return _endpoint
        .unary(serviceName, 'compute')
        .call<ComputeRequest, ComputeResult>(
          request: request,
          responseParser: ComputeResult.fromJson,
        );
  }
}

// Регистрация контрактов
server.registerServiceContract(ServerCalculator());
final calculator = ClientCalculator(client);
client.registerServiceContract(calculator);

// Использование
final result = await calculator.compute(ComputeRequest(value1: 10, value2: 5));
print('Сумма: ${result.sum}'); // Сумма: 15
```

## Middleware

Middleware позволяют перехватывать и модифицировать запросы и ответы:

```dart
// Логирующий middleware
class LoggingMiddleware implements SimpleRpcMiddleware {
  final String id;
  
  LoggingMiddleware({required this.id});
  
  @override
  FutureOr<dynamic> onRequest(
    String serviceName, 
    String methodName, 
    dynamic payload, 
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    final directionStr = direction == RpcDataDirection.toRemote ? '→' : '←';
    print('[$id] $directionStr $serviceName.$methodName - ${payload.runtimeType}');
    return payload;
  }
}

// Middleware для авторизации
class AuthMiddleware implements SimpleRpcMiddleware {
  final String token;
  
  AuthMiddleware(this.token);
  
  @override
  FutureOr<dynamic> onRequest(
    String serviceName, 
    String methodName, 
    dynamic payload, 
    RpcMethodContext context,
    RpcDataDirection direction,
  ) {
    if (direction == RpcDataDirection.toRemote) {
      final mutableContext = context.toMutable();
      mutableContext.setHeaderMetadata(
        Map<String, dynamic>.from(mutableContext.headerMetadata ?? {})
          ..['authorization'] = 'Bearer $token'
      );
    }
    return payload;
  }
}

// Добавление middleware к эндпоинту
client.addMiddleware(LoggingMiddleware(id: 'client'));
client.addMiddleware(AuthMiddleware('user-token-123'));
```

## Транспорты

### MemoryTransport

Используется для коммуникации в рамках одного процесса (для тестирования или примеров):

```dart
final clientTransport = MemoryTransport('client');
final serverTransport = MemoryTransport('server');
clientTransport.connect(serverTransport);
serverTransport.connect(clientTransport);
```

### WebSocketTransport

Используется для коммуникации через WebSocket (между клиентом и сервером):

```dart
// На сервере
final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
final wsServer = WebSocketTransport.createServerFromHttpServer(server);

// На клиенте
final wsClient = await WebSocketTransport.connect('ws://localhost:8080');
```

### IsolateTransport

Используется для коммуникации между изолятами (параллельными потоками) в Dart:

```dart
// В основном изоляте
final mainTransport = IsolateTransport('main');

// Создание и запуск изолята
final receivePort = ReceivePort();
await Isolate.spawn(
  workerIsolate,
  receivePort.sendPort,
);

final workerSendPort = await receivePort.first as SendPort;
mainTransport.connectToIsolate(workerSendPort);

// В рабочем изоляте
void workerIsolate(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);
  
  final workerTransport = IsolateTransport('worker');
  workerTransport.connectToIsolate(mainSendPort, receivePort);
  
  // ...
}
```

## Примеры

В директории `example/` представлены примеры использования библиотеки для различных типов RPC взаимодействий:

- Унарный RPC: калькулятор
- Клиентский стриминг: загрузка файла частями
- Серверный стриминг: мониторинг прогресса
- Двунаправленный стриминг: чат

### Запуск примеров

```bash
# Перейти в директорию примеров
cd example

# Скомпилировать бинарный файл
dart compile exe bin/main.dart -o bin/examples

# Запустить конкретный пример
./bin/examples -e unary      # Унарный RPC (калькулятор)
./bin/examples -e client     # Клиентский стриминг (загрузка файла)
./bin/examples -e server     # Серверный стриминг (мониторинг)
./bin/examples -e bidirectional  # Двунаправленный стриминг (чат)

# Получить справку
./bin/examples --help
```

Подробнее о примерах можно прочитать в [README.md](example/README.md) директории примеров.

## Обработка ошибок

```dart
try {
  final result = await client
      .unary('CalculatorService', 'divide')
      .call<DivideRequest, DivideResult>(
        request: DivideRequest(a: 10, b: 0),
        responseParser: DivideResult.fromJson,
      );
} on RpcException catch (e) {
  print('RPC ошибка: ${e.message}');
  print('Код ошибки: ${e.code}');
  print('Детали: ${e.details}');
} catch (e) {
  print('Ошибка: $e');
}
```

## Лицензия

LGPL-3.0-or-later
