# gRPC Bridge

Платформонезависимая реализация gRPC-подобного протокола для Dart/Flutter.

## Особенности

- 🚀 **Платформонезависимость** - работает на всех платформах, поддерживаемых Dart и Flutter
- 🔄 **Двунаправленная коммуникация** - полностью двунаправленный обмен данными
- 🔐 **Типобезопасность** - поддержка типизированных контрактов и эндпоинтов
- 📦 **Контракты сервисов** - декларативное описание API
- 🔁 **Унарные вызовы и стриминг** - поддержка как обычных запросов, так и потоков данных
- 🧩 **Расширяемость** - легко добавить новые транспорты и сериализаторы

## Установка

```yaml
dependencies:
  grpc_bridge: ^0.1.0
```

## Использование

### Основные компоненты

Библиотека строится на нескольких ключевых компонентах:

1. **Transport** - отвечает за передачу бинарных данных
2. **Serializer** - сериализует/десериализует сообщения
3. **Endpoint** - базовый API для RPC-вызовов
4. **TypedEndpoint** - типизированный API с поддержкой контрактов
5. **ServiceContract** - описание доступных методов сервиса 

### Простой пример

```dart
import 'package:grpc_bridge/grpc_bridge.dart';

void main() async {
  // Создаем транспорты (в реальном примере они могут быть на разных устройствах)
  final transport1 = MemoryTransport('client');
  final transport2 = MemoryTransport('server');
  
  // Соединяем транспорты для демонстрации
  transport1.connect(transport2);
  transport2.connect(transport1);
  
  // Создаем сериализатор
  final serializer = JsonSerializer();
  
  // Создаем конечные точки
  final client = Endpoint(transport1, serializer);
  final server = Endpoint(transport2, serializer);
  
  // Регистрируем метод на сервере
  server.registerMethod(
    'CalculatorService',
    'add',
    (context) async {
      final payload = context.payload as Map<String, dynamic>;
      final a = payload['a'] as int;
      final b = payload['b'] as int;
      return {'result': a + b};
    },
  );
  
  // Вызываем метод с клиента
  final result = await client.invoke(
    'CalculatorService',
    'add',
    {'a': 5, 'b': 3},
  );
  
  print('Result: ${result['result']}'); // Result: 8
  
  // Закрываем ресурсы
  await client.close();
  await server.close();
}
```

### Потоковая передача данных

```dart
import 'package:grpc_bridge/grpc_bridge.dart';

void main() async {
  // Настройка как в предыдущем примере
  final transport1 = MemoryTransport('client');
  final transport2 = MemoryTransport('server');
  transport1.connect(transport2);
  transport2.connect(transport1);
  
  final serializer = JsonSerializer();
  final client = Endpoint(transport1, serializer);
  final server = Endpoint(transport2, serializer);
  
  // Регистрируем потоковый метод на сервере
  server.registerMethod(
    'StreamService',
    'generateNumbers',
    (context) async {
      final payload = context.payload as Map<String, dynamic>;
      final count = payload['count'] as int;
      
      // Получаем ID сообщения из контекста для потока
      final messageId = context.messageId;
      
      // Запускаем генерацию чисел в отдельном потоке
      Future.microtask(() async {
        for (var i = 1; i <= count; i++) {
          // Отправляем данные в поток
          await server.sendStreamData(messageId, i);
          await Future.delayed(Duration(milliseconds: 100));
        }
        
        // Сигнализируем о завершении потока
        await server.closeStream(messageId);
      });
      
      // Возвращаем подтверждение активации стрима
      return {'status': 'streaming'};
    },
  );
  
  // Открываем поток со стороны клиента
  final stream = client.openStream(
    'StreamService',
    'generateNumbers',
    request: {'count': 5},
  );
  
  // Подписываемся на получение данных
  stream.listen(
    (data) => print('Received: $data'),
    onDone: () => print('Stream completed'),
  );
}
```

### Использование типизированных контрактов

Библиотека поддерживает декларативное определение контрактов сервисов:

```dart
import 'package:grpc_bridge/grpc_bridge.dart';

// Определяем сообщения для запросов и ответов
class CalculatorRequest implements TypedMessage {
  final int a;
  final int b;

  CalculatorRequest(this.a, this.b);

  @override
  Map<String, dynamic> toJson() => {'a': a, 'b': b};

  @override
  String get messageType => 'CalculatorRequest';

  static CalculatorRequest fromJson(Map<String, dynamic> json) {
    return CalculatorRequest(
      json['a'] as int,
      json['b'] as int,
    );
  }
}

class CalculatorResponse implements TypedMessage {
  final int result;

  CalculatorResponse(this.result);

  @override
  Map<String, dynamic> toJson() => {'result': result};

  @override
  String get messageType => 'CalculatorResponse';

  static CalculatorResponse fromJson(Map<String, dynamic> json) {
    return CalculatorResponse(json['result'] as int);
  }
}

// Определяем контракт сервиса
abstract base class CalculatorContract extends DeclarativeServiceContract {
  TypedEndpoint? get client;

  @override
  final String serviceName = 'CalculatorService';

  @override
  void registerMethodsFromClass() {
    // Регистрируем унарный метод
    addUnaryMethod<CalculatorRequest, CalculatorResponse>(
      methodName: 'add',
      handler: add,
      argumentParser: CalculatorRequest.fromJson,
      responseParser: CalculatorResponse.fromJson,
    );
  }

  // Определяем метод с типизированной сигнатурой
  Future<CalculatorResponse> add(CalculatorRequest request);
}

// Реализация контракта на сервере
final class ServerCalculator extends CalculatorContract {
  @override
  TypedEndpoint? get client => null;

  @override
  Future<CalculatorResponse> add(CalculatorRequest request) async {
    return CalculatorResponse(request.a + request.b);
  }
}

// Реализация контракта на клиенте
final class ClientCalculator extends CalculatorContract {
  @override
  final TypedEndpoint client;

  ClientCalculator(this.client);

  @override
  Future<CalculatorResponse> add(CalculatorRequest request) {
    return client.invokeTyped<CalculatorRequest, CalculatorResponse>(
      serviceName: serviceName,
      methodName: 'add',
      request: request,
    );
  }
}

void main() async {
  // Настройка транспорта как в предыдущих примерах
  final transport1 = MemoryTransport('client');
  final transport2 = MemoryTransport('server');
  transport1.connect(transport2);
  transport2.connect(transport1);
  
  final serializer = JsonSerializer();
  
  // Создаем типизированные эндпоинты
  final clientEndpoint = TypedEndpoint(transport1, serializer);
  final serverEndpoint = TypedEndpoint(transport2, serializer);
  
  // Создаем и регистрируем сервис
  final calculatorService = ServerCalculator();
  serverEndpoint.registerContract(calculatorService);
  
  // Создаем клиента
  final calculator = ClientCalculator(clientEndpoint);
  
  // Вызываем типизированный метод
  final request = CalculatorRequest(10, 5);
  final response = await calculator.add(request);
  
  print('Результат: ${request.a} + ${request.b} = ${response.result}');
  
  // Закрываем ресурсы
  await clientEndpoint.close();
  await serverEndpoint.close();
}
```

### Стриминг с типизированными контрактами

```dart
// Добавляем в контракт калькулятора поддержку стрима
abstract base class CalculatorContract extends DeclarativeServiceContract {
  // ... существующий код ...

  @override
  void registerMethodsFromClass() {
    // ... существующие методы ...
    
    // Регистрируем стриминговый метод
    addServerStreamingMethod<SequenceRequest, int>(
      methodName: 'generateSequence',
      handler: generateSequence,
      argumentParser: SequenceRequest.fromJson,
      responseParser: (json) => json['count'] as int,
    );
  }

  // Определяем стриминговый метод
  Stream<int> generateSequence(SequenceRequest request);
}

// Реализация на сервере
final class ServerCalculator extends CalculatorContract {
  // ... существующий код ...

  @override
  Stream<int> generateSequence(SequenceRequest request) {
    return Stream.periodic(
      Duration(milliseconds: 200),
      (i) => i + 1,
    ).take(request.count);
  }
}

// Реализация на клиенте
final class ClientCalculator extends CalculatorContract {
  // ... существующий код ...

  @override
  Stream<int> generateSequence(SequenceRequest request) {
    return client.openTypedStream<SequenceRequest, int>(
      serviceName,
      'generateSequence',
      request,
    );
  }
}

// Использование
void main() async {
  // ... настройка как в предыдущем примере ...
  
  // Создаем запрос
  final sequenceRequest = SequenceRequest(5);
  
  // Получаем стрим чисел
  await for (final number in calculator.generateSequence(sequenceRequest)) {
    print('Получено число: $number');
  }
  
  print('Стрим завершен');
}
```

## Создание собственных транспортов

Можно создать собственную реализацию транспорта, имплементировав интерфейс `Transport`:

```dart
class WebSocketTransport implements Transport {
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
    if (!isAvailable) {
      throw StateError('Transport is not available');
    }
    
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

## Расширенные возможности

### Контекст метода

При обработке запросов, каждый обработчик получает `MethodContext`, который содержит:

- `messageId` - уникальный идентификатор сообщения
- `payload` - данные запроса
- `metadata` - дополнительные метаданные
- `serviceName` - имя вызываемого сервиса
- `methodName` - имя вызываемого метода

```dart
server.registerMethod(
  'ExampleService',
  'contextAwareMethod',
  (context) async {
    print('Вызван метод: ${context.serviceName}.${context.methodName}');
    print('ID сообщения: ${context.messageId}');
    print('Метаданные: ${context.metadata}');
    
    return {'status': 'ok'};
  },
);
```

### Декларативные контракты

Декларативный подход позволяет определять контракты в виде классов:

1. Создаем базовый абстрактный класс, наследующий от `DeclarativeServiceContract`
2. Определяем абстрактные методы с типизированными сигнатурами
3. Реализуем эти методы на сервере и клиенте

Это дает преимущества в виде:
- Проверки типов во время компиляции
- Автодополнения в IDE
- Лучшей масштабируемости и поддержки кода

