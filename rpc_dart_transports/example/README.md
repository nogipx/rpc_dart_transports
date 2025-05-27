# Примеры для RPC Dart Transports

В этой директории находятся примеры использования различных транспортов для RPC Dart.

## Пример mesh-коммуникации через изоляты

Демонстрирует создание mesh-сети из нескольких узлов, работающих в разных изолятах, и обмен сообщениями между ними.

### Запуск

```bash
dart run mesh_isolate_example.dart
```

### Возможности примера

Пример демонстрирует:
1. Создание mesh-узла в основном потоке
2. Запуск нескольких изолятов с mesh-узлами
3. Установление соединений между узлами
4. Отправку различных типов сообщений:
   - Unicast (отправка конкретному узлу)
   - Multicast (отправка группе узлов)
   - Broadcast (отправка всем узлам)
5. Обработку входящих сообщений
6. Использование типизированных параметров транспорта

### Структура примера

- `main()` - основная функция, создающая mesh-узел и запускающая изоляты
- `connectIsolateTransport()` - вспомогательная функция для подключения транспорта изолята
- `demoSendMessages()` - функция, демонстрирующая отправку различных типов сообщений
- `workerEntrypoint()` - точка входа для изолята с mesh-узлом
- `demoTransportOptions()` - демонстрация использования типизированных параметров транспорта

### Типизированные параметры транспорта

В примере используются новые типизированные параметры транспорта, которые обеспечивают безопасность типов и улучшенную автодополнение в IDE. Доступны следующие типы параметров:

1. **WebSocketTransportParameters** - для WebSocket транспорта:
   ```dart
   final options = TransportOptions.webSocket(
     address: 'ws://example.com:8080',
     isServer: false,
   );
   ```

2. **InMemoryTransportParameters** - для In-Memory транспорта:
   ```dart
   final options = TransportOptions.inMemory(
     isPrimary: true,
     pairId: 'demo-pair',
   );
   ```

3. **IsolateTransportParameters** - для Isolate транспорта:
   ```dart
   final options = TransportOptions.isolate(
     isolateId: 'demo-isolate',
     existingTransport: transport,
   );
   ```

Для обратной совместимости поддерживается создание из нетипизированных параметров:
```dart
final options = TransportOptions.fromLegacy(
  transportType: TransportTypes.webSocket,
  parameters: {'address': 'ws://legacy.example.com'},
);
```

### Дополнительная информация

См. документацию в `_README.md` в директории `lib/src/mesh` для более подробной информации о mesh-транспорте. 