# 🚀 RPC Dart Chat 2.0

Современное Flutter приложение-чат, демонстрирующее возможности **транспорт-агностичного** RPC фреймворка rpc_dart.

## ✨ Особенности

### 🔄 Транспорт-агностичность
- **HTTP/2** - высокопроизводительный gRPC-style транспорт (по умолчанию)
- **WebSocket** - традиционный, надежный транспорт
- **Автоматическое переподключение** с exponential backoff
- **Горячая замена транспорта** без потери данных

### 💬 Возможности чата
- **Групповые комнаты** с мультикастом сообщений
- **Приватные сообщения** через unicast
- **Индикаторы печатания** в реальном времени
- **Система реакций** на сообщения
- **Список онлайн пользователей**
- **События роутера** для уведомлений

### 🎨 Современный UI
- **Material Design 3** с динамическими цветами
- **Темная и светлая темы** 
- **Адаптивный дизайн** для всех платформ
- **Плавные анимации** и переходы
- **Элегантные уведомления**

## 🚀 Быстрый старт

### 1️⃣ Запуск роутер сервера

```bash
# HTTP/2 роутер (по умолчанию)
dart run rpc_dart_transports:rpc_dart_router --stats

# HTTP/2 + WebSocket роутер
dart run rpc_dart_transports:rpc_dart_router -t http2 -t websocket --stats

# С детальными логами
dart run rpc_dart_transports:rpc_dart_router -v --log-level debug
```

### 2️⃣ Запуск Flutter приложения

```bash
cd rpc_dart_chat
flutter run
```

### 3️⃣ Подключение

1. Введите имя пользователя
2. Выберите транспорт (WebSocket/HTTP/2)
3. Укажите URL сервера:
   - **HTTP/2**: `http://localhost:11112` (рекомендуемый)
   - **WebSocket**: `ws://localhost:11111`
4. Нажмите "Подключиться"

## 🔧 Архитектура

### Транспорт-агностичный дизайн

```dart
// Любой транспорт!
IRpcTransport transport = RpcWebSocketCallerTransport.connect(uri);
// IRpcTransport transport = await RpcHttp2CallerTransport.connect(...);

RpcCallerEndpoint endpoint = RpcCallerEndpoint(transport: transport);
RpcRouterClient client = RpcRouterClient(callerEndpoint: endpoint);
```

### Компоненты чата

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ChatService   │◄──►│  RpcRouterClient │◄──►│ Транспорт-сервер │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ UI Компоненты   │    │ Endpoint Layer  │    │ WebSocket/HTTP2 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📱 Поддерживаемые платформы

- ✅ **Android**
- ✅ **iOS** 
- ✅ **Web**
- ✅ **Windows**
- ✅ **macOS**
- ✅ **Linux**

## 🎯 Примеры использования

### Отправка сообщений

```dart
// Групповое сообщение
await chatService.sendMessage("Привет всем!");

// Приватное сообщение
await chatService.sendPrivateMessage(userId, "Привет!");

// Broadcast
await routerClient.sendBroadcast({'announcement': 'Важное объявление'});
```

### Смена транспорта

```dart
// Переключение с WebSocket на HTTP/2 без потери соединения
await chatService.switchTransport(TransportType.http2);
```

### События реального времени

```dart
// Подписка на события роутера
await routerClient.subscribeToEvents();
routerClient.events.listen((event) {
  switch (event.type) {
    case RouterEventType.clientConnected:
      showNotification('Пользователь присоединился');
      break;
    case RouterEventType.topologyChanged:
      updateUsersList();
      break;
  }
});
```

## 🔬 Технические детали

### Состояние подключения

```dart
enum ChatConnectionState {
  disconnected,
  connecting, 
  connected,
  reconnecting,
  error,
}
```

### Автоматическое переподключение

- **Exponential backoff**: 2s → 4s → 8s → 16s → 30s
- **Максимум попыток**: 5
- **Jitter**: случайная задержка для предотвращения thundering herd
- **Graceful degradation**: приложение остается отзывчивым

### Производительность

- **Ленивая загрузка** сообщений
- **Виртуализация списков** для больших чатов  
- **Debounced typing indicators** (3 секунды)
- **Efficient state management** с Provider

## 🎨 Кастомизация

### Темы

```dart
// Светлая тема
ThemeData.from(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue, 
    brightness: Brightness.light
  ),
)

// Темная тема  
ThemeData.from(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark
  ),
)
```

### Анимации

- **Hero transitions** между экранами
- **Пульсирующий логотип** на экране приветствия
- **Slide-in уведомления** для новых сообщений
- **Skeleton loading** для списка пользователей

## 🚀 Запуск в продакшене

### Конфигурация роутера

```bash
# Продакшн роутер с TLS
dart run rpc_dart_transports:rpc_dart_router \
  --host 0.0.0.0 \
  --websocket-port 443 \
  --http2-port 8443 \
  --transport http2,websocket \
  --stats \
  --client-timeout 300 \
  --log-level info
```

### Flutter Web

```bash
# Оптимизированная сборка для Web
flutter build web --release --web-renderer canvaskit
```

### Мобильные приложения

```bash
# Android APK
flutter build apk --release --split-per-abi

# iOS
flutter build ios --release
```

## 🤝 Вклад в развитие

1. Fork проекта
2. Создайте ветку: `git checkout -b feature/amazing-feature`
3. Commit изменения: `git commit -m 'Add amazing feature'`
4. Push в ветку: `git push origin feature/amazing-feature`
5. Откройте Pull Request

## 📄 Лицензия

LGPL-3.0-or-later - детали в файле [LICENSE](../LICENSE)

## 🔗 Полезные ссылки

- [RPC Dart Framework](../rpc_dart/)
- [Transport Layer](../rpc_dart_transports/)
- [Router Documentation](../docs/)
- [Flutter Guide](https://flutter.dev)

---

*RPC Dart Chat - демонстрация будущего транспорт-агностичных приложений! 🚀*
