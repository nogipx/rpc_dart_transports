[![Pub Version](https://img.shields.io/pub/v/rpc_dart.svg)](https://pub.dev/packages/rpc_dart)

## Особенности

- 🚀 **Кроссплатформенность** - работает на всех платформах, где поддерживается Dart/Flutter
- 🌐 **Независимость от транспорта** - поддержка различных транспортных протоколов (Memory, Proxy, WebSocket, Isolate)
- 💪 **Типобезопасность** - строгая типизация контрактов и сообщений
- 🔄 **Поддержка всех типов RPC** - унарные вызовы, серверный стриминг, клиентский стриминг, двунаправленный стриминг
- 🧩 **Middleware** - расширение функциональности через промежуточные обработчики
- 📝 **Сериализация** - поддержка JSON и MsgPack сериализаторов
- 📊 **Диагностика** - встроенные инструменты для мониторинга и сбора метрик
- 🔒 **Безопасность** - поддержка шифрованного транспорта для защиты данных

## Основные компоненты

- **RpcEndpoint** - основной компонент для взаимодействия с RPC
- **RpcTransport** - абстракция транспортного уровня (WebSocket, Memory, Isolate)
- **RpcSerializer** - сериализация/десериализация сообщений (JSON, MsgPack)
- **RpcServiceContract** - контракты для описания API сервисов
- **RpcMiddleware** - промежуточные обработчики для запросов/ответов
- **RpcDiagnostics** - система мониторинга и сбора метрик

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
    debugLabel: 'client',
  );
  
  final server = RpcEndpoint(
    transport: serverTransport,
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
final streamingBidi = client
    .serverStreaming('TaskService', 'startTask')
    .call<TaskRequest, ProgressMessage>(
      request: TaskRequest(taskId: 'task-123', taskName: 'Обработка'),
      responseParser: ProgressMessage.fromJson,
    );

// Подписка на обновления
await for (final update in streamingBidi.stream) {
  print('Прогресс: ${update.progress}%, ${update.message}');
}

// Закрываем стрим после использования
await streamingBidi.close();
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
final clientStreamingBidi = client
    .clientStreaming('UploadService', 'uploadFile')
    .call<FileChunk, UploadResult>(
      responseParser: UploadResult.fromJson,
    );

// Отправка данных
clientStreamingBidi.send(FileChunk(data: [/* данные */], index: 1));
clientStreamingBidi.send(FileChunk(data: [/* данные */], index: 2));

// Завершаем отправку данных и ожидаем результат
await clientStreamingBidi.finishTransfer();
final result = await clientStreamingBidi.response;

print('Загружено ${result.totalSize} байт в ${result.chunks} частях');

// Закрываем стрим после использования
await clientStreamingBidi.close();
```

#### Двунаправленный стриминг

```dart
// На сервере
server.bidirectional('ChatService', 'chat').register<ChatMessage, ChatMessage>(
  handler: (incomingStream) {
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
final bidiStream = client
    .bidirectional('ChatService', 'chat')
    .call<ChatMessage, ChatMessage>(
      responseParser: ChatMessage.fromJson,
    );

// Подписка на входящие сообщения
final subscription = bidiStream.stream.listen((message) {
  print('${message.sender}: ${message.text}');
});

// Отправка сообщений
bidiStream.send(ChatMessage(
  sender: 'Клиент',
  text: 'Привет!',
  timestamp: DateTime.now().toIso8601String(),
));

// После использования закрываем поток
await bidiStream.close();
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

## Диагностика

Начиная с версии 0.3.0, библиотека поддерживает встроенную систему диагностики:

```dart
// Создание и настройка диагностического клиента
final diagnosticClient = RpcDiagnosticClient(
  // Настройка диагностического клиента
  options: RpcDiagnosticOptions(
    // Частота сбора метрик (от 0.0 до 1.0)
    samplingRate: 0.1, 
    // Максимальный размер буфера метрик
    maxBufferSize: 100,
    // Интервал отправки метрик (мс)
    flushIntervalMs: 5000,
    // Включить шифрование чувствительных данных
    encryptionEnabled: true,
    // Минимальный уровень логирования
    minLogLevel: RpcLoggerLevel.info,
    // Включить логирование в консоль
    consoleLoggingEnabled: true,
    // Включить сбор трассировок
    traceEnabled: true,
    // Включить сбор метрик задержки
    latencyEnabled: true,
    // Включить сбор метрик стримов
    streamMetricsEnabled: true,
    // Включить сбор метрик ошибок
    errorMetricsEnabled: true,
  ),
);

// Установка диагностического клиента
RpcLoggerSettings.setDiagnostic(diagnosticClient);
// Установка минимального уровня логирования
RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

// Пример пользовательского логирования
final logger = RpcLogger('MyComponent');
logger.info('Операция выполнена успешно');
logger.error(
  'Произошла ошибка',
  error: Exception('Пример ошибки'),
  data: {'userId': '12345'}
);

// При необходимости диагностику можно отключить
// RpcLoggerSettings.removeDiagnostic();
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
    IRpcContext context,
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
    IRpcContext context,
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

### ProxyTransport

Используется для перенаправления сообщений через произвольные потоки:

```dart
final clientTransport = ProxyTransport(
  id: 'client',
  incomingStream: incomingStream,
  timeout: Duration(seconds: 10),
  sendFunction: (data) async {
    // Отправка данных через произвольный поток
  },
);
final serverTransport = ProxyTransport(
  id: 'server',
  incomingStream: incomingStream,
  timeout: Duration(seconds: 10),
  sendFunction: (data) async {
    // Отправка данных через произвольный поток
  },
);
```

### EncryptedTransport

Транспорт с поддержкой шифрования для защиты передаваемых данных:

```dart
final secureTransport = EncryptedTransport(
  baseTransport: webSocketTransport,
  encryptionService: AesEncryptionService(
    key: 'your-secure-key',
  ),
);
```

### rpc_dart_transports

Для других реализаций транспорта см. библиотеку [rpc_dart_transports](https://pub.dev/packages/rpc_dart_transports).

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
} on RpcStatusException catch (e) {
  print('RPC ошибка: ${e.message}');
  print('Код статуса: ${e.code}');
  print('Детали: ${e.details}');
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
