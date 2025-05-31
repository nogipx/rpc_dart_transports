# Диагностика сетевых проблем: VPN vs без VPN

## 🚨 Проблема: "Попытка отправить данные после закрытия транспорта"

### Симптомы
- С VPN: все работает нормально ✅
- Без VPN: warnings в логах сервера ⚠️
- Сообщения между клиентами не доходят без VPN ❌

## 🔍 Техническая причина

### **С VPN (корректное поведение)**
```
Client ←→ [VPN Tunnel] ←→ Server
```
1. **Защищенное соединение**: WebSocket трафик скрыт внутри VPN туннеля
2. **Корректное закрытие**: При отключении выполняется полный WebSocket handshake
3. **Событие onDone**: RouterContract получает сигнал закрытия
4. **Чистый cleanup**: Клиент удаляется из EventDistributor до отправки событий

### **Без VPN (проблемное поведение)**
```
Client ←→ [NAT/Firewall] ←→ Internet ←→ Server
```
1. **Резкий обрыв**: NAT/Firewall агрессивно закрывает WebSocket соединения
2. **Zombie connection**: Transport остается в подвешенном состоянии  
3. **Отсутствие onDone**: RouterContract не получает сигнал закрытия вовремя
4. **Ghost client**: Клиент остается в EventDistributor
5. **Warning**: Попытка отправить события в уже закрытый транспорт

## 🛠️ Внесенные исправления

### 1. Синхронизация таймаутов
```dart
// Было: EventDistributor cleanup через 5 минут
// Стало: EventDistributor cleanup через 80% от client timeout
inactivityThreshold: Duration(
  milliseconds: (clientInactivityTimeout.inMilliseconds * 0.8).round()
)
```

### 2. Проактивная очистка EventDistributor
```dart
// При отключении клиента принудительно очищаем EventDistributor
final eventClientId = 'events_$clientId';
if (_eventDistributor.hasClientStream(eventClientId)) {
  _eventDistributor.closeClientStream(eventClientId);
}
```

### 3. Детекция Zombie Connections
```dart
// Проверяем закрытые StreamController'ы
if (streamController != null && streamController.isClosed) {
  zombieClients.add(clientId);
}

// Проверяем рассинхронизацию с GlobalMessageBus
if (!_messageBus.isClientRegistered(clientId) && _clientsInfo.containsKey(clientId)) {
  zombieClients.add(clientId);
}
```

### 4. Улучшенная обработка ошибок в GlobalMessageBus
```dart
// Автоматически удаляем закрытые стримы
if (streamController != null && streamController.isClosed) {
  unregisterClientStream(clientId);
}
```

## 🎯 Рекомендации для продакшена

### Настройки сервера
```dart
final sharedRouterImpl = RouterResponderImpl(
  logger: logger,
  healthCheckInterval: Duration(seconds: 30),     // Частые проверки
  clientInactivityTimeout: Duration(minutes: 2),  // Быстрое отключение
);
```

### Мониторинг
- Следить за количеством zombie connections в логах
- Отслеживать warnings "Попытка отправить данные после закрытия транспорта"
- Контролировать рассинхронизацию между роутером и GlobalMessageBus

### Клиентские настройки
```dart
// Включить более агрессивный heartbeat для соединений без VPN
final routerClient = RouterClient(
  callerEndpoint: endpoint,
  heartbeatInterval: Duration(seconds: 15), // Чаще для борьбы с NAT
);
```

## 📊 Диагностические команды

### Проверка состояния роутера
```bash
dart run rpc_dart_transports/bin/debug_bus_stats.dart
```

### Мониторинг логов
```bash
# Искать warnings о закрытых транспортах
grep "Попытка отправить данные после закрытия транспорта" router.log

# Искать zombie connections
grep "Zombie connection" router.log

# Искать рассинхронизацию
grep "Рассинхронизация" router.log
```

## 🚀 Автоматическое тестирование

Для проверки исправлений рекомендуется:

1. **Тест с VPN**: Подключить 2+ клиентов через VPN, проверить обмен сообщениями
2. **Тест без VPN**: Подключить 2+ клиентов напрямую, проверить обмен сообщениями  
3. **Тест резкого отключения**: Имитировать обрыв соединения (убить процесс клиента)
4. **Мониторинг логов**: Убедиться что нет warnings о закрытых транспортах

## 🔗 Связанные файлы

- `rpc_dart_transports/lib/src/router/implementations/router_responder.dart` - основная логика роутера
- `rpc_dart_transports/lib/src/router/global_message_bus.dart` - глобальная шина сообщений  
- `rpc_dart_transports/bin/rpc_dart_router.dart` - сервер роутера
- `rpc_dart_transports/bin/debug_bus_stats.dart` - диагностические утилиты 