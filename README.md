<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->

# RPC Dart Transports

Библиотека транспортов для RPC Dart - предоставляет различные способы передачи RPC сообщений.

## Поддерживаемые транспорты

### 🌐 WebSocket Transport
- Двунаправленная связь через WebSocket
- Поддержка мультиплексирования потоков
- Автоматическое переподключение

### 🔄 Isolate Transport  
- Связь между Dart изолятами
- Высокая производительность для CPU-интенсивных задач
- Изоляция ошибок

### 🚀 HTTP/2 Transport (NEW!)
- Современный HTTP/2 протокол
- gRPC-совместимый формат сообщений
- Мультиплексирование потоков
- Поддержка TLS/SSL

### 🔀 Router
- Маршрутизация сообщений между клиентами
- P2P соединения через центральный роутер
- Управление группами клиентов

## HTTP/2 Transport

HTTP/2 транспорт реализует gRPC-совместимый протокол поверх HTTP/2. Поддерживает как клиентские, так и серверные соединения.

### Особенности

- **Мультиплексирование**: Множественные RPC вызовы через одно соединение
- **gRPC совместимость**: Использует стандартные gRPC headers и frame формат
- **TLS поддержка**: Защищенные HTTPS соединения
- **Stream управление**: Автоматическое управление HTTP/2 streams

### Использование

#### Клиентское соединение

```dart
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

// HTTP соединение
final transport = await Http2ClientTransport.connect(
  host: 'localhost',
  port: 8080,
);

// HTTPS соединение
final secureTransport = await Http2ClientTransport.secureConnect(
  host: 'api.example.com',
  port: 443,
);

// Создание RPC вызова
final streamId = transport.createStream();
final metadata = RpcMetadata.forClientRequest('MyService', 'MyMethod');

await transport.sendMetadata(streamId, metadata);
await transport.sendMessage(streamId, requestData);
await transport.finishSending(streamId);

// Обработка ответов
transport.getMessagesForStream(streamId).listen((message) {
  if (message.payload != null) {
    // Обработка данных ответа
    print('Received: ${utf8.decode(message.payload!)}');
  }
});
```

#### Серверное соединение

```dart
import 'package:http2/http2.dart' as http2;

// Создание HTTP/2 сервера (требует дополнительной настройки)
final serverConnection = http2.ServerTransportConnection.viaSocket(socket);
final transport = Http2ServerTransport.create(
  connection: serverConnection,
  logger: logger,
);

// Обработка входящих сообщений
transport.incomingMessages.listen((message) {
  if (message.isMetadataOnly) {
    // Обработка метаданных запроса
    print('Method: ${message.methodPath}');
  } else if (message.payload != null) {
    // Обработка данных запроса
    final requestData = message.payload!;
    
    // Отправка ответа
    final responseData = processRequest(requestData);
    transport.sendMessage(message.streamId, responseData);
    transport.finishSending(message.streamId);
  }
});
```

### gRPC совместимость

HTTP/2 транспорт использует стандартный gRPC протокол:

- **Headers**: Стандартные HTTP/2 pseudo-headers (`:method`, `:path`, `:scheme`, `:authority`)
- **Content-Type**: `application/grpc+proto`
- **Frame format**: 5-байтовый префикс + protobuf данные
- **Status codes**: Стандартные gRPC статус коды

### Примеры

Смотрите `example/http2_example.dart` для полного примера использования.

## Установка

Добавьте в `pubspec.yaml`:

```yaml
dependencies:
  rpc_dart_transports:
    git:
      url: https://github.com/nogipx/rpc_dart.git
      ref: main
      path: rpc_dart_transports
```

## Лицензия

LGPL-3.0-or-later

## Компоненты

### WebSocket Transport
- `RpcWebSocketCallerTransport` - клиентский WebSocket транспорт
- `RpcWebSocketResponderTransport` - серверный WebSocket транспорт

### Router
Роутер для маршрутизации сообщений между клиентами с поддержкой:
- Unicast (1:1) сообщения
- Multicast (1:N) сообщения по группам
- Broadcast (1:ALL) сообщения
- Request-Response паттерн с таймаутами
- События роутера
- Обновление метаданных через P2P поток
- Heartbeat через P2P поток

## Router API изменения

**ВАЖНО**: В последней версии методы `updateMetadata` и `heartbeat` **перенесены из unary вызовов в P2P поток** для правильной идентификации клиентов.

### Старый API (УСТАРЕЛ):
```dart
// Не работает - требует clientId который недоступен в unary методах
await routerClient.updateMetadata({'version': '1.1.0'});
await routerClient.heartbeat();
```

### Новый API (через P2P поток):
```dart
// 1. Регистрируемся
final response = await routerClient.register(
  clientName: 'MyClient',
  groups: ['developers'],
  metadata: {'version': '1.0.0'},
);

// 2. Инициализируем P2P соединение (ОБЯЗАТЕЛЬНО!)
await routerClient.initializeP2P(
  onP2PMessage: (message) {
    print('Получено P2P сообщение: ${message.type}');
  },
);

// 3. Теперь updateMetadata и heartbeat работают
await routerClient.updateMetadata({
  'version': '1.1.0',
  'capabilities': ['p2p', 'metadata'],
  'updated_at': DateTime.now().toIso8601String(),
});

await routerClient.heartbeat();

// Или используем прямые P2P методы
routerClient.sendHeartbeat();
```

### Типы сообщений роутера

```dart
enum RouterMessageType {
  unicast,         // Сообщение конкретному клиенту
  multicast,       // Сообщение группе клиентов
  broadcast,       // Сообщение всем клиентам
  error,           // Сообщение об ошибке
  request,         // Запрос с ожиданием ответа
  response,        // Ответ на запрос
  heartbeat,       // ❌ Heartbeat (ЧЕРЕЗ P2P)
  updateMetadata,  // ❌ Обновление метаданных (ЧЕРЕЗ P2P)
}
```

### Пример использования

```dart
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';

void main() async {
  // Создаем клиента
  final transport = RpcWebSocketCallerTransport.connect(
    Uri.parse('ws://localhost:8080/ws'),
  );
  
  final endpoint = RpcCallerEndpoint(transport: transport);
  await endpoint.start();
  
  final routerClient = RouterClient(callerEndpoint: endpoint);
  
  // Регистрируемся
  final registerResponse = await routerClient.register(
    clientName: 'TestClient',
    groups: ['developers'],
    metadata: {'version': '1.0.0'},
  );
  
  print('Зарегистрирован: ${registerResponse.clientId}');
  
  // Инициализируем P2P
  await routerClient.initializeP2P(
    onP2PMessage: (message) {
      print('P2P: ${message.type} от ${message.senderId}');
    },
  );
  
  // Обновляем метаданные
  await routerClient.updateMetadata({'version': '1.1.0'});
  
  // Отправляем heartbeat
  await routerClient.heartbeat();
  
  // Отправляем сообщения
  await routerClient.sendUnicast('client-2', {'hello': 'world'});
  await routerClient.sendBroadcast({'announcement': 'Hello everyone!'});
  
  // Отправляем запрос с ожиданием ответа
  final response = await routerClient.sendRequest(
    'client-2',
    {'action': 'getData'},
    timeout: Duration(seconds: 5),
  );
  
  print('Ответ: $response');
}
```

## Тестирование

```bash
dart test
```

Все тесты проходят: **46/46** ✅

## CLI Роутер

Пакет включает в себя CLI инструмент `rpc_dart_router` для запуска WebSocket роутера.

### Установка

Глобальная установка:
```bash
dart pub global activate --source path .
```

После установки команда `rpc_dart_router` будет доступна глобально.

### Использование

```bash
# Запуск с настройками по умолчанию (0.0.0.0:11111)
rpc_dart_router

# Запуск на localhost:8080
rpc_dart_router -h localhost -p 8080

# Тихий режим
rpc_dart_router --quiet

# Подробный режим с debug логами
rpc_dart_router -v --log-level debug

# Показать справку
rpc_dart_router --help

# Показать версию
rpc_dart_router --version
```

### Опции

- `-h, --host` - Хост для привязки сервера (по умолчанию: 0.0.0.0)
- `-p, --port` - Порт для прослушивания (по умолчанию: 11111)
- `-l, --log-level` - Уровень логирования: debug, info, warning, error, critical, none (по умолчанию: info)
- `-q, --quiet` - Тихий режим (минимум вывода)
- `-v, --verbose` - Подробный режим (детальный вывод)
- `--help` - Показать справку
- `--version` - Показать версию

### Логирование

Роутер поддерживает несколько уровней логирования из RPC Dart:

- `debug` 🔍 - Максимум информации, включая детали каждого соединения
- `info` 📌 - Основная информация о работе роутера (по умолчанию)
- `warning` ⚠️ - Предупреждения и нестандартные ситуации
- `error` ❌ - Ошибки
- `critical` 🔥 - Критические ошибки
- `none` - Без логов

Флаг `--verbose` включает дополнительную статистику и детали.
Флаг `--quiet` переопределяет уровень логирования на `none`.

### Запуск локально

Если пакет не установлен глобально:

```bash
dart run bin/rpc_dart_router.dart [options]
```

## Разработка

### Запуск тестов

```bash
dart test
```

### Анализ кода

```bash
dart analyze
```

### Сборка нативных бинарей

Для создания самостоятельных исполняемых файлов:

```bash
# Автоматическая сборка для текущей платформы
./build.sh

# Ручная сборка для текущей платформы
dart compile exe bin/rpc_dart_router.dart -o build/rpc_dart_router

# Сборка через Dart скрипт (включая Docker для Linux)
dart run build_all.dart
```

#### Кроссплатформенная сборка

**Вариант 1: GitHub Actions (рекомендуется)**
1. Перейдите в раздел **Actions** GitHub репозитория `rpc_dart`
2. Выберите workflow **"Build RPC Dart Router"**
3. Нажмите **"Run workflow"** и укажите:
   - **Version**: `v1.0.0` (или любую другую)
   - **Create release**: ✅ (для создания релиза)
   - **Platforms**: `linux-only` (или `all` для всех платформ)
4. Дождитесь завершения сборки (~3-5 минут)
5. Скачайте:
   - **Артефакты** из раздела Artifacts (временные файлы)
   - **Релиз** из раздела Releases (постоянные файлы)

**Вариант 2: Docker для Linux**
```bash
# Для сборки Linux версии на macOS/Windows
docker build -t rpc-dart-router .
docker run --rm -v $(pwd)/build:/output rpc-dart-router cp rpc_dart_router-linux /output/
```

**Вариант 3: Ручная сборка**
- **Linux**: запустите `dart compile exe` на Linux машине
- **macOS**: запустите `dart compile exe` на macOS
- **Windows**: запустите `dart compile exe` на Windows

#### Готовые бинари

После сборки получите:
- `build/rpc_dart_router-linux` - для Linux серверов
- `build/rpc_dart_router-macos` - для macOS  
- `build/rpc_dart_router-windows.exe` - для Windows

Скопируйте нужный файл на целевую платформу и запускайте:
```bash
# Linux
chmod +x rpc_dart_router-linux
./rpc_dart_router-linux --help

# macOS  
chmod +x rpc_dart_router-macos
./rpc_dart_router-macos --help

# Windows
rpc_dart_router-windows.exe --help
```
