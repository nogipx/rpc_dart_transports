# Примеры использования RPC Dart

В этой директории находятся примеры, демонстрирующие различные возможности библиотеки RPC Dart.

## Типы примеров

Библиотека демонстрирует четыре основных типа RPC взаимодействий:

1. **Унарный (Unary)** - один запрос → один ответ (example: калькулятор)
2. **Клиентский стриминг (Client Streaming)** - поток запросов → один ответ (example: загрузка файла частями)
3. **Серверный стриминг (Server Streaming)** - один запрос → поток ответов (example: мониторинг задачи)
4. **Двунаправленный стриминг (Bidirectional)** - поток запросов ↔ поток ответов (example: чат)

## Запуск примеров

### Через бинарный файл (рекомендуется)

Для запуска примеров можно использовать скомпилированный бинарный файл, который принимает аргументы командной строки:

```bash
# Компиляция бинарного файла
dart compile exe bin/main.dart -o bin/examples

# Запуск конкретного примера
./bin/examples -e unary      # Унарный RPC пример
./bin/examples -e client     # Клиентский стриминг пример
./bin/examples -e server     # Серверный стриминг пример
./bin/examples -e bidirectional  # Двунаправленный стриминг пример

# Также можно указать номер примера
./bin/examples -e 1  # Унарный пример
./bin/examples -e 2  # Клиентский стриминг
# и т.д.

# Отключение режима отладки (подробных логов)
./bin/examples -e unary --no-debug

# Получение справки
./bin/examples --help
```

### Через Dart CLI

```bash
# Запуск через Dart
dart run bin/main.dart -e unary
```

## Описание примеров

### Унарный пример (калькулятор)

Демонстрирует простой запрос-ответ с базовыми математическими операциями.

```dart
// Пример вызова метода
final result = await clientContract.compute(ComputeRequest(value1: 10, value2: 5));
print(result.sum);  // 15
```

### Клиентский стриминг (загрузка файла)

Демонстрирует отправку потока данных клиентом и получение одного итогового ответа.

```dart
// Отправка блоков данных
final processStream = await streamService.processDataBlocks(...);
final controller = processStream.controller;

// Отправка нескольких блоков
controller.add(DataBlock(data: [...], index: 1));
controller.add(DataBlock(data: [...], index: 2));
await controller.close();

// Получение итогового результата
final result = await processStream.response;
```

### Серверный стриминг (мониторинг прогресса)

Демонстрирует отправку одного запроса и получение потока обновлений от сервера.

```dart
// Запуск задачи
final request = TaskRequest(taskId: '...', taskName: 'Анализ данных');
final stream = client.serverStreaming('TaskService', 'startTask')
    .openStream<TaskRequest, ProgressMessage>(request);

// Обработка потока обновлений
await for (final progress in stream) {
  print('Прогресс: ${progress.progress}%: ${progress.message}');
}
```

### Двунаправленный стриминг (чат)

Демонстрирует двунаправленную коммуникацию между клиентом и сервером.

```dart
// Открытие канала
final channel = await chatService.chat();

// Отслеживание входящих сообщений
channel.incoming.listen((message) {
  print('${message.sender}: ${message.text}');
});

// Отправка сообщений
channel.send(ChatMessage(sender: 'User', text: 'Привет!'));
```

## Реализация своих контрактов

Есть два подхода к созданию контрактов:

1. **Декларативный подход** - контракт создается с использованием абстрактного класса, наследующего от `RpcServiceContract`. Этот подход рекомендуется использовать для серьезных приложений, как показано в примерах.

2. **Прямая регистрация методов** - регистрация методов производится напрямую через методы эндпоинта. Подходит для прототипирования и простых случаев.

## Структура проекта

```
example/
  ├── bin/                    # Исполняемые файлы
  │   ├── main.dart           # Основной файл запуска примеров
  │   └── examples            # Скомпилированный бинарный файл
  ├── lib/                    # Библиотечный код
  │   ├── unary/              # Пример унарного RPC
  │   ├── client_streaming/   # Пример клиентского стриминга
  │   ├── server_streaming/   # Пример серверного стриминга
  │   └── bidirectional/      # Пример двунаправленного стриминга
  └── README.md               # Этот файл
``` 