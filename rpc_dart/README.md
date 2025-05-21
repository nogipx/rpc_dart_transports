[![Pub Version](https://img.shields.io/pub/v/rpc_dart.svg)](https://pub.dev/packages/rpc_dart)

# RPC Dart

Кроссплатформенная RPC библиотека для Dart/Flutter с поддержкой всех видов стриминга.

## Особенности

- 🚀 **Кроссплатформенность** - работает на всех платформах Dart/Flutter
- 🌐 **Независимость от транспорта** - WebSocket, Memory, Isolate и другие
- 💪 **Типобезопасность** - строгая типизация контрактов и сообщений
- 🔄 **Все типы RPC** - унарный, серверный/клиентский/двунаправленный стриминг
- 🧩 **Middleware** - расширение через промежуточные обработчики
- 📝 **Сериализация** - JSON и MsgPack
- 🏗️ **Модульная архитектура** - компоненты с единой ответственностью

## Пример контракта

Создание контракта API с использованием абстрактного класса:

```dart
/// Контракт для демонстрационного сервиса
abstract class DemoServiceContract extends RpcServiceContract {
  DemoServiceContract() : super('demo_service');

  @override
  void setup() {
    // Регистрируем унарный метод
    addUnaryRequestMethod<RpcString, RpcString>(
      methodName: 'echo',
      handler: echo,
      argumentParser: RpcString.fromJson,
      responseParser: RpcString.fromJson,
    );

    // Регистрируем метод с серверным стримингом
    addServerStreamingMethod<RpcInt, RpcString>(
      methodName: 'generateNumbers',
      handler: generateNumbers,
      argumentParser: RpcInt.fromJson,
      responseParser: RpcString.fromJson,
    );

    // Регистрируем метод с клиентским стримингом
    addClientStreamingMethod<RpcString, RpcInt>(
      methodName: 'countWords',
      handler: countWords,
      argumentParser: RpcString.fromJson,
      responseParser: RpcInt.fromJson,
    );

    // Регистрируем двунаправленный метод
    addBidirectionalStreamingMethod<RpcString, RpcString>(
      methodName: 'chat',
      handler: chat,
      argumentParser: RpcString.fromJson,
      responseParser: RpcString.fromJson,
    );

    super.setup();
  }

  // Унарный метод - эхо
  Future<RpcString> echo(RpcString request);

  // Метод с клиентским стримингом
  ClientStreamingBidiStream<RpcString, RpcInt> countWords();

  // Метод с серверным стримингом
  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt count);

  // Двунаправленный метод
  BidiStream<RpcString, RpcString> chat();
}
```

## Примеры реализаций

### Серверная реализация

```dart
final class DemoServer extends DemoServiceContract {
  @override
  Future<RpcString> echo(RpcString request) async {
    return RpcString(request.value);
  }

  @override
  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt count) {
    // Создаем генератор с функцией, которая принимает стрим запросов и возвращает стрим ответов
    final generator = BidiStreamGenerator<RpcInt, RpcString>((requests) async* {
      for (int i = 1; i <= count.value; i++) {
        await Future.delayed(Duration(milliseconds: 500));
        yield RpcString('Число $i');
      }
    });

    // Создаем и возвращаем стрим для сервера
    return generator.createServerStreaming(initialRequest: count);
  }

  @override
  ClientStreamingBidiStream<RpcString, RpcInt> countWords() {
    final generator = BidiStreamGenerator<RpcString, RpcInt>((requests) async* {
      int totalWords = 0;

      await for (final request in requests) {
        final words = request.value.split(' ').where((word) => word.isNotEmpty).length;
        totalWords += words;
      }

      yield RpcInt(totalWords);
    });

    return generator.createClientStreaming();
  }

  @override
  BidiStream<RpcString, RpcString> chat() {
    final generator = BidiStreamGenerator<RpcString, RpcString>((requests) async* {
      await for (final request in requests) {
        yield RpcString('Сервер получил: ${request.value}');
      }
    });

    return generator.create();
  }
}
```

### Клиентская реализация

```dart
final class DemoClient extends DemoServiceContract {
  final RpcEndpoint _endpoint;

  DemoClient(this._endpoint);

  @override
  BidiStream<RpcString, RpcString> chat() {
    return _endpoint
        .bidirectionalStreaming(
          serviceName: 'demo_service',
          methodName: 'chat',
        )
        .call(
          responseParser: RpcString.fromJson,
        );
  }

  @override
  ClientStreamingBidiStream<RpcString, RpcInt> countWords() {
    return _endpoint
        .clientStreaming(
          serviceName: 'demo_service',
          methodName: 'countWords',
        )
        .call(
          responseParser: RpcInt.fromJson,
        );
  }

  @override
  Future<RpcString> echo(RpcString request) {
    return _endpoint
        .unaryRequest(
          serviceName: 'demo_service',
          methodName: 'echo',
        )
        .call(
          request: request,
          responseParser: RpcString.fromJson,
        );
  }

  @override
  ServerStreamingBidiStream<RpcInt, RpcString> generateNumbers(RpcInt count) {
    return _endpoint
        .serverStreaming(
          serviceName: 'demo_service',
          methodName: 'generateNumbers',
        )
        .call(
          request: count,
          responseParser: RpcString.fromJson,
        );
  }
}
```

## Регистрация и использование

```dart
// Создание транспортов (в памяти для примера)
final clientTransport = MemoryTransport('client');
final serverTransport = MemoryTransport('server');

// Соединение транспортов
clientTransport.connect(serverTransport);
serverTransport.connect(clientTransport);

// Создание эндпоинтов
final client = RpcEndpoint(transport: clientTransport);
final server = RpcEndpoint(transport: serverTransport);

// Регистрация на сервере
final demoServer = DemoServer();
server.registerServiceContract(demoServer);

// Использование на клиенте
final demoClient = DemoClient(client);

// Унарный вызов
final response = await demoClient.echo(RpcString("Привет!"));
print(response.value); // "Привет!"

// Серверный стриминг
final stream = demoClient.generateNumbers(RpcInt(5));
await for (final number in stream) {
  print(number.value); // "Число 1", "Число 2", ...
}

// Клиентский стриминг
final counter = demoClient.countWords();
counter.send(RpcString("Привет мир"));
counter.send(RpcString("Это тест"));
await counter.finishSending();
final wordCount = await counter.getResponse();
print(wordCount?.value); // 4

// Двунаправленный стриминг
final chat = demoClient.chat();
chat.stream.listen((message) {
  print('Получено: ${message.value}');
});
chat.send(RpcString("Привет!"));
```

## Типы сообщений

### Встроенные примитивы

Библиотека предоставляет примитивные типы для удобной сериализации:

```dart
// Строковый тип
final stringMessage = RpcString("Hello World");

// Целочисленный тип
final intMessage = RpcInt(42);
final sum = intMessage + RpcInt(10); // RpcInt(52)

// Дробный тип
final doubleMessage = RpcDouble(3.14);

// Логический тип
final boolMessage = RpcBool(true);

// Пустое значение
final nullMessage = RpcNull();
```

### Создание пользовательских типов

Для создания своих типов сообщений, реализуйте интерфейс `IRpcSerializableMessage`:

```dart
class User extends IRpcSerializableMessage {
  final String name;
  final int age;
  final List<String> roles;

  User({
    required this.name,
    required this.age,
    required this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] as String,
      age: json['age'] as int,
      roles: List<String>.from(json['roles'] as List),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'roles': roles,
    };
  }
}

// Использование в контракте
addUnaryRequestMethod<User, RpcBool>(
  methodName: 'createUser',
  handler: createUser,
  argumentParser: User.fromJson,
  responseParser: RpcBool.fromJson,
);
```

## Типы RPC

### 1. Унарный RPC
Один запрос → один ответ

```dart
// Регистрация
addUnaryRequestMethod<RequestType, ResponseType>(
  methodName: 'method',
  handler: handler,
  argumentParser: RequestType.fromJson,
  responseParser: ResponseType.fromJson,
);

// Вызов
final result = await endpoint
    .unaryRequest(serviceName: 'service', methodName: 'method')
    .call<RequestType, ResponseType>(
      request: request,
      responseParser: ResponseType.fromJson,
    );
```

### 2. Серверный стриминг
Один запрос → поток ответов

```dart
// Регистрация
addServerStreamingMethod<RequestType, ResponseType>(
  methodName: 'method',
  handler: handler,
  argumentParser: RequestType.fromJson,
  responseParser: ResponseType.fromJson,
);

// Вызов
final stream = endpoint
    .serverStreaming(serviceName: 'service', methodName: 'method')
    .call<RequestType, ResponseType>(
      request: request,
      responseParser: ResponseType.fromJson,
    );

await for (final response in stream) {
  // Обработка ответов
}
```

### 3. Клиентский стриминг
Поток запросов → один ответ

```dart
// Регистрация
addClientStreamingMethod<RequestType, ResponseType>(
  methodName: 'method',
  handler: handler,
  argumentParser: RequestType.fromJson,
  responseParser: ResponseType.fromJson,
);

// Вызов
final clientStream = endpoint
    .clientStreaming(serviceName: 'service', methodName: 'method')
    .call<RequestType, ResponseType>(
      responseParser: ResponseType.fromJson,
    );

// Отправка данных
clientStream.send(request1);
clientStream.send(request2);
await clientStream.finishSending();

// Получение результата
final result = await clientStream.getResponse();
```

### 4. Двунаправленный стриминг
Поток запросов ↔ поток ответов

```dart
// Регистрация
addBidirectionalStreamingMethod<RequestType, ResponseType>(
  methodName: 'method',
  handler: handler,
  argumentParser: RequestType.fromJson,
  responseParser: ResponseType.fromJson,
);

// Вызов
final bidiStream = endpoint
    .bidirectionalStreaming(serviceName: 'service', methodName: 'method')
    .call<RequestType, ResponseType>(
      responseParser: ResponseType.fromJson,
    );

// Подписка на ответы
bidiStream.stream.listen((response) {
  // Обработка ответов
});

// Отправка данных
bidiStream.send(request);
```

## Транспорты

Библиотека предоставляет интерфейс `RpcTransport`, который необходимо реализовать для обеспечения обмена сообщениями:

```dart
class MyTransport implements RpcTransport {
  // Реализация методов транспорта
}
```

В библиотеке имеется базовая реализация `MemoryTransport` для тестирования и прототипирования. Для использования в production разработчику следует реализовать собственный транспорт в зависимости от требований приложения.

## Обработка ошибок

```dart
try {
  final result = await client.echo(RpcString("test"));
} on RpcStatusException catch (e) {
  // Обработка ошибок статуса
} on RpcException catch (e) {
  // Обработка прочих RPC ошибок
}
```

## Логирование

```dart
RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);
final logger = RpcLogger('MyComponent');
logger.info('Информация');
logger.error('Ошибка', error: exception, data: {'key': 'value'});
```

## Примеры

В директории `example/` представлены примеры для всех типов RPC взаимодействий.
См. [README.md](example/README.md) для более подробной информации.

## Лицензия

LGPL-3.0-or-later
