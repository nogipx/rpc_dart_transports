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

Набор транспортов для RPC Dart фреймворка, включая роутер для P2P сообщений.

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

## Лицензия

LGPL-3.0
