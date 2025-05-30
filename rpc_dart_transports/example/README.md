# Router API Example

Новый Router API использует чистые RPC методы вместо RouterMessage.

## Основные изменения

### Прямые RPC методы к роутеру:
- `register()` - регистрация клиента
- `ping()` - проверка задержки
- `getOnlineClients()` - получение списка клиентов
- `updateMetadata()` - обновление метаданных
- `heartbeat()` - keep-alive
- `events` - подписка на события роутера

### P2P сообщения:
- `initializeP2P()` - инициализация P2P
- `sendUnicast()` - 1:1 сообщения
- `sendMulticast()` - 1:N по группе
- `sendBroadcast()` - 1:ALL сообщения
- `sendRequest()` - request-response с таймаутом

## Пример использования

```dart
// Создание клиента
final client = RouterClient(
  callerEndpoint: endpoint,
  logger: logger,
);

// Регистрация
await client.register(
  clientName: 'Alice',
  groups: ['developers'],
);

// P2P сообщения
await client.initializeP2P();
await client.sendUnicast('bob_id', {'message': 'Hello!'});

// События
await client.subscribeToEvents();
client.events.listen((event) => print('Event: ${event.type}'));
``` 