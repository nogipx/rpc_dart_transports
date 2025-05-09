# Примеры использования RPC Dart

В этой директории собраны примеры использования библиотеки RPC Dart для различных сценариев.

## Структура примеров

- [calculator](./calculator) - Базовый пример с реализацией контракта калькулятора
- [calculator_example.dart](./calculator_example.dart) - Демонстрация использования контракта калькулятора
- [bidirectional_example.dart](./bidirectional_example.dart) - Простой пример двунаправленного стриминга без контрактов

## Типы RPC вызовов

Библиотека RPC Dart поддерживает четыре типа RPC вызовов:

1. **Унарный (Unary)** - один запрос, один ответ
2. **Серверный стриминг (Server Streaming)** - один запрос, поток ответов
3. **Клиентский стриминг (Client Streaming)** - поток запросов, один ответ
4. **Двунаправленный стриминг (Bidirectional Streaming)** - поток запросов, поток ответов

## Запуск примеров

Для запуска любого примера используйте:

```bash
dart run example/calculator_example.dart

dart run example/bidirectional_example.dart
```

## Описание примеров

### Калькулятор

Демонстрирует использование унарных методов и серверного стриминга через контракт сервиса.

```dart
// Клиентский вызов унарного метода
final response = await clientContract.add(CalculatorRequest(5, 3));

// Клиентский вызов стримингового метода
final stream = clientContract.generateSequence(SequenceRequest(5));
await for (final item in stream) {
  print(item.count);
}
```

### Простой двунаправленный стрим

Демонстрирует минимальную реализацию двунаправленного стриминга без использования контрактов.

```dart
// Регистрация на сервере
serverEndpoint
    .bidirectional('EchoService', 'echo')
    .register<StringMessage, StringMessage>(
      handler: (incomingStream, messageId) {
        return incomingStream.map((data) {
          return StringMessage(text: 'Эхо: ${data.text}');
        });
      },
      requestParser: StringMessage.fromJson,
      responseParser: StringMessage.fromJson,
    );

// Создание и использование канала на клиенте
final channel = clientEndpoint
    .bidirectional('EchoService', 'echo')
    .createChannel<StringMessage, StringMessage>(
      requestParser: StringMessage.fromJson,
      responseParser: StringMessage.fromJson,
    );

// Отправка сообщений
channel.send(StringMessage(text: 'Привет!'));
```

## Реализация своих контрактов

Есть два подхода к созданию контрактов:

1. **Декларативный подход** - см. пример в директории `calculator`, где контракт создается с использованием абстрактного класса, наследующего от `RpcServiceContract`. Этот подход рекомендуется использовать для серьезных приложений.

2. **Прямая регистрация методов** - см. примеры `upload_example.dart`, `chat_example.dart` и `bidirectional_simple_example.dart`, где регистрация методов производится напрямую через методы эндпоинта. Подходит для прототипирования и простых случаев. 