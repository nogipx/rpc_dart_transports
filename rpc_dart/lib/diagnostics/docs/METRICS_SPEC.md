<!--
SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>

SPDX-License-Identifier: LGPL-3.0-or-later
-->

# Спецификация диагностических метрик RPC Dart

## 1. Введение

Данный документ описывает спецификацию метрик и диагностических данных, которые собираются и анализируются в рамках диагностического сервиса RPC Dart. Документ содержит формальное описание каждого типа данных, их источников, значения для анализа и форматы представления.

## 2. Классификация диагностических данных

Диагностические данные разделены на следующие категории:

1. **Трассировочные данные** - сведения о пути выполнения запросов
2. **Метрики производительности** - измерения времени выполнения и ресурсов
3. **Данные о стримах** - метрики потоковых взаимодействий
4. **Ошибки и исключения** - информация о сбоях
5. **Системные метрики** - общее состояние системы
6. **Бизнес-метрики** - показатели, специфичные для предметной области
7. **Идентификационные данные** - информация об источнике метрик
8. **Данные безопасности** - метаданные шифрования и защиты данных

## 3. Клиентские метрики

### 3.1. Сетевые метрики клиента

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `client.network.request_sent` | Отправка запроса | Событие | TraceEvent |
| `client.network.response_received` | Получение ответа | Событие | TraceEvent |
| `client.network.request_size` | Размер отправленного запроса | Байты | NumberMetric |
| `client.network.response_size` | Размер полученного ответа | Байты | NumberMetric |
| `client.network.rtt` | Round-Trip Time | Миллисекунды | LatencyMetric |
| `client.network.timeouts` | Количество таймаутов | Счетчик | CounterMetric |
| `client.network.reconnections` | Количество переподключений | Счетчик | CounterMetric |
| `client.network.transport_errors` | Ошибки транспортного уровня | Счетчик | ErrorMetric |
| `client.network.encryption_overhead` | Накладные расходы шифрования | Миллисекунды | LatencyMetric |

### 3.2. Метрики производительности клиента

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `client.perf.method_latency` | Общее время выполнения метода | Миллисекунды | LatencyMetric |
| `client.perf.serialization_time` | Время сериализации | Миллисекунды | LatencyMetric |
| `client.perf.deserialization_time` | Время десериализации | Миллисекунды | LatencyMetric |
| `client.perf.queue_time` | Время в очереди | Миллисекунды | LatencyMetric |
| `client.perf.retry_count` | Количество повторных попыток | Счетчик | CounterMetric |
| `client.perf.memory_usage` | Память, использованная во время запроса | Байты | ResourceMetric |

### 3.3. Метрики стримов клиента

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `client.stream.created` | Создание стрима | Событие | StreamEvent |
| `client.stream.closed` | Закрытие стрима | Событие | StreamEvent |
| `client.stream.messages_sent` | Отправлено сообщений в стрим | Счетчик | StreamMetric |
| `client.stream.messages_received` | Получено сообщений из стрима | Счетчик | StreamMetric |
| `client.stream.bandwidth_out` | Исходящая пропускная способность | Байты/сек | ResourceMetric |
| `client.stream.bandwidth_in` | Входящая пропускная способность | Байты/сек | ResourceMetric |
| `client.stream.backpressure` | Индикатор обратного давления | Счетчик | StreamMetric |
| `client.stream.errors` | Ошибки стрима | Счетчик | ErrorMetric |

### 3.4. Метрики ошибок клиента

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `client.error.rpc_errors` | Ошибки вызова RPC | Счетчик + Детали | ErrorMetric |
| `client.error.serialization_failures` | Ошибки сериализации | Счетчик + Детали | ErrorMetric |
| `client.error.connection_failures` | Ошибки соединения | Счетчик + Детали | ErrorMetric |
| `client.error.timeout_failures` | Ошибки таймаутов | Счетчик + Детали | ErrorMetric |
| `client.error.business_logic_failures` | Ошибки бизнес-логики | Счетчик + Детали | ErrorMetric |
| `client.error.encryption_failures` | Ошибки шифрования | Счетчик + Детали | ErrorMetric |

### 3.5. Системные метрики клиента

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `client.system.active_connections` | Количество активных соединений | Счетчик | ResourceMetric |
| `client.system.pending_requests` | Количество ожидающих запросов | Счетчик | ResourceMetric |
| `client.system.active_streams` | Количество активных стримов | Счетчик | ResourceMetric |
| `client.system.connection_pool_usage` | Использование пула соединений | Процент | ResourceMetric |
| `client.system.buffer_memory_usage` | Использование буферной памяти | Байты | ResourceMetric |

### 3.6. Метрики идентификации клиента

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `client.identity.registered` | Регистрация клиента | Событие | IdentityEvent |
| `client.identity.updated` | Обновление данных клиента | Событие | IdentityEvent |
| `client.identity.heartbeat` | Сигнал активности клиента | Событие | IdentityEvent |
| `client.identity.session_duration` | Длительность сессии | Секунды | TimeMetric |

## 4. Серверные метрики

### 4.1. Сетевые метрики сервера

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `server.network.request_received` | Получение запроса | Событие | TraceEvent |
| `server.network.response_sent` | Отправка ответа | Событие | TraceEvent |
| `server.network.request_size` | Размер полученного запроса | Байты | NumberMetric |
| `server.network.response_size` | Размер отправленного ответа | Байты | NumberMetric |
| `server.network.active_connections` | Активные соединения | Счетчик | ResourceMetric |
| `server.network.transport_errors` | Ошибки транспортного уровня | Счетчик | ErrorMetric |
| `server.network.connection_duration` | Длительность соединения | Секунды | TimeMetric |
| `server.network.decryption_overhead` | Накладные расходы расшифровки | Миллисекунды | LatencyMetric |

### 4.2. Метрики производительности сервера

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `server.perf.method_execution_time` | Время выполнения метода | Миллисекунды | LatencyMetric |
| `server.perf.handler_queue_time` | Время в очереди обработчика | Миллисекунды | LatencyMetric |
| `server.perf.serialization_time` | Время сериализации | Миллисекунды | LatencyMetric |
| `server.perf.deserialization_time` | Время десериализации | Миллисекунды | LatencyMetric |
| `server.perf.middleware_time` | Время выполнения middleware | Миллисекунды | LatencyMetric |
| `server.perf.db_query_time` | Время запросов к БД | Миллисекунды | LatencyMetric |
| `server.perf.external_call_time` | Время внешних вызовов | Миллисекунды | LatencyMetric |
| `server.perf.memory_per_request` | Память на запрос | Байты | ResourceMetric |

### 4.3. Метрики стримов сервера

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `server.stream.created` | Создание стрима | Событие | StreamEvent |
| `server.stream.closed` | Закрытие стрима | Событие | StreamEvent |
| `server.stream.active_streams` | Количество активных стримов | Счетчик | ResourceMetric |
| `server.stream.messages_received` | Получено сообщений из стрима | Счетчик | StreamMetric |
| `server.stream.messages_sent` | Отправлено сообщений в стрим | Счетчик | StreamMetric |
| `server.stream.bandwidth_in` | Входящая пропускная способность | Байты/сек | ResourceMetric |
| `server.stream.bandwidth_out` | Исходящая пропускная способность | Байты/сек | ResourceMetric |
| `server.stream.errors` | Ошибки стрима | Счетчик | ErrorMetric |
| `server.stream.backpressure_applied` | Применено обратное давление | Счетчик | StreamMetric |

### 4.4. Метрики ошибок сервера

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `server.error.handler_exceptions` | Исключения в обработчиках | Счетчик + Детали | ErrorMetric |
| `server.error.serialization_failures` | Ошибки сериализации | Счетчик + Детали | ErrorMetric |
| `server.error.validation_failures` | Ошибки валидации | Счетчик + Детали | ErrorMetric |
| `server.error.unauthorized_access` | Неавторизованный доступ | Счетчик + Детали | SecurityMetric |
| `server.error.rate_limit_exceeded` | Превышен rate limit | Счетчик | SecurityMetric |
| `server.error.db_errors` | Ошибки БД | Счетчик + Детали | ErrorMetric |
| `server.error.external_service_errors` | Ошибки внешних сервисов | Счетчик + Детали | ErrorMetric |
| `server.error.decryption_failures` | Ошибки расшифровки | Счетчик + Детали | SecurityMetric |

### 4.5. Системные метрики сервера

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `server.system.cpu_usage` | Использование CPU | Процент | ResourceMetric |
| `server.system.memory_usage` | Использование памяти | Байты | ResourceMetric |
| `server.system.thread_count` | Количество потоков | Счетчик | ResourceMetric |
| `server.system.request_queue_length` | Длина очереди запросов | Счетчик | ResourceMetric |
| `server.system.event_loop_lag` | Задержка event loop | Миллисекунды | LatencyMetric |
| `server.system.active_handlers` | Количество активных обработчиков | Счетчик | ResourceMetric |
| `server.system.gc_pause_time` | Время пауз сборщика мусора | Миллисекунды | LatencyMetric |

### 4.6. Метрики клиентских сессий

| Метрика | Описание | Единица измерения | Тип данных |
|---------|----------|-------------------|------------|
| `server.clients.active_clients` | Количество активных клиентов | Счетчик | ResourceMetric |
| `server.clients.client_requests` | Запросы по клиентам | Счетчик | ResourceMetric |
| `server.clients.client_errors` | Ошибки по клиентам | Счетчик | ErrorMetric |
| `server.clients.encrypted_connections` | Зашифрованные соединения | Счетчик | SecurityMetric |

## 5. Связанные метрики (сквозная трассировка)

### 5.1. Трассировочные идентификаторы

| Идентификатор | Описание | Пример |
|---------------|----------|--------|
| `trace_id` | Уникальный ID трассировки (весь путь запроса) | "trace-abc-123-xyz-789" |
| `span_id` | ID отдельного сегмента трассировки | "span-45678" |
| `parent_span_id` | ID родительского сегмента | "span-12345" |
| `request_id` | ID конкретного запроса | "req-987654" |
| `session_id` | ID сессии пользователя | "session-abcdef" |
| `user_id` | ID пользователя | "user-123456" |
| `client_id` | ID клиентского экземпляра | "client-789012" |
| `deployment_id` | ID развертывания | "deploy-456789" |

### 5.2. Корреляционные данные

| Данные | Описание | Пример использования |
|--------|----------|----------------------|
| `service_hierarchy` | Иерархия вызовов сервисов | client → gateway → auth → db |
| `method_chain` | Цепочка вызванных методов | login → validate → createSession |
| `request_path` | Полный путь запроса | [client] → [service1] → [service2] → [service1] → [client] |
| `timing_breakdown` | Разбивка времени по этапам | client: 5ms, network: 15ms, server: 30ms, db: 10ms |
| `client_context` | Контекстная информация клиента | app: 'mobile', version: '1.2.3', device: 'iPhone' |

## 6. Модели диагностических данных

### 6.1. TraceEvent

```dart
@freezed
class TraceEvent with _$TraceEvent implements IRpcSerializableMessage {
  factory TraceEvent({
    required String traceId,
    required String serviceName,
    required String methodName,
    required DateTime timestamp,
    required TraceEventType type,
    required ClientIdentity clientIdentity,
    String? spanId,
    String? parentSpanId,
    String? requestId,
    String? sessionId,
    String? userId,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? metadata,
    bool isEncrypted,
    String? encryptionKeyId,
  }) = _TraceEvent;
  
  factory TraceEvent.fromJson(Map<String, dynamic> json) => _$TraceEventFromJson(json);
}

enum TraceEventType {
  clientRequestSent,
  serverRequestReceived,
  serverResponseSent,
  clientResponseReceived,
  clientStreamStarted,
  serverStreamStarted,
  clientStreamEnded,
  serverStreamEnded,
}
```

### 6.2. LatencyMetric

```dart
@freezed
class LatencyMetric with _$LatencyMetric implements IRpcSerializableMessage {
  factory LatencyMetric({
    required String metricName,
    required String serviceName,
    required String methodName,
    required int durationMs,
    required DateTime timestamp,
    required ClientIdentity clientIdentity,
    String? traceId,
    String? spanId,
    String? requestId,
    Map<String, dynamic>? metadata,
    bool isEncrypted,
    String? encryptionKeyId,
  }) = _LatencyMetric;
  
  factory LatencyMetric.fromJson(Map<String, dynamic> json) => _$LatencyMetricFromJson(json);
}
```

### 6.3. StreamMetric

```dart
@freezed
class StreamMetric with _$StreamMetric implements IRpcSerializableMessage {
  factory StreamMetric({
    required String metricName,
    required String streamId,
    required String serviceName,
    required String methodName,
    required StreamMetricType type,
    required DateTime timestamp,
    required ClientIdentity clientIdentity,
    int? messageCount,
    int? byteCount,
    double? ratePerSecond,
    String? traceId,
    Map<String, dynamic>? metadata,
    bool isEncrypted,
    String? encryptionKeyId,
  }) = _StreamMetric;
  
  factory StreamMetric.fromJson(Map<String, dynamic> json) => _$StreamMetricFromJson(json);
}

enum StreamMetricType {
  created,
  closed,
  messageSent,
  messageReceived,
  backpressure,
  error,
}
```

### 6.4. ErrorMetric

```dart
@freezed
class ErrorMetric with _$ErrorMetric implements IRpcSerializableMessage {
  factory ErrorMetric({
    required String metricName,
    required String serviceName,
    required String methodName,
    required String errorType,
    required String errorMessage,
    required DateTime timestamp,
    required ClientIdentity clientIdentity,
    String? stackTrace,
    String? traceId,
    String? spanId,
    String? requestId,
    Map<String, dynamic>? context,
    Map<String, dynamic>? metadata,
    bool isEncrypted,
    String? encryptionKeyId,
  }) = _ErrorMetric;
  
  factory ErrorMetric.fromJson(Map<String, dynamic> json) => _$ErrorMetricFromJson(json);
}
```

### 6.5. ResourceMetric

```dart
@freezed
class ResourceMetric with _$ResourceMetric implements IRpcSerializableMessage {
  factory ResourceMetric({
    required String metricName,
    required String resourceType,
    required double value,
    required String unit,
    required DateTime timestamp,
    required ClientIdentity clientIdentity,
    String? serviceName,
    String? methodName,
    String? traceId,
    Map<String, dynamic>? metadata,
    bool isEncrypted,
    String? encryptionKeyId,
  }) = _ResourceMetric;
  
  factory ResourceMetric.fromJson(Map<String, dynamic> json) => _$ResourceMetricFromJson(json);
}
```

### 6.6. ClientIdentity

```dart
@freezed
class ClientIdentity with _$ClientIdentity implements IRpcSerializableMessage {
  factory ClientIdentity({
    required String clientId,         // Уникальный ID клиента/экземпляра
    required String deploymentId,     // ID развертывания/установки
    String? deviceId,                 // Идентификатор устройства
    String? appVersion,               // Версия приложения
    String? environment,              // Окружение: prod/stage/dev
    String? organizationId,           // ID организации (для multi-tenant)
    Map<String, dynamic>? customTags, // Кастомные теги для группировки
  }) = _ClientIdentity;
  
  factory ClientIdentity.fromJson(Map<String, dynamic> json) => 
    _$ClientIdentityFromJson(json);
}
```

### 6.7. EncryptionInfo

```dart
@freezed
class EncryptionInfo with _$EncryptionInfo implements IRpcSerializableMessage {
  factory EncryptionInfo({
    required String keyId,
    required EncryptionMode mode,
    required DateTime createdAt,
    DateTime? expiresAt,
    String? algorithm,
    int? keySize,
  }) = _EncryptionInfo;
  
  factory EncryptionInfo.fromJson(Map<String, dynamic> json) => 
    _$EncryptionInfoFromJson(json);
}

enum EncryptionMode {
  allData,
  sensitiveOnly,
  metadataOnly,
}
```

## 7. Рекомендации по сбору и анализу

### 7.1. Семплирование метрик

Рекомендуется использовать следующие параметры семплирования для разных типов метрик:

| Тип метрики | Разработка | Тестирование | Продакшен |
|-------------|------------|--------------|-----------|
| Трассировочные события | 100% | 50% | 10% |
| Метрики производительности | 100% | 30% | 5% |
| Ошибки | 100% | 100% | 100% |
| Системные метрики | Каждые 5с | Каждые 10с | Каждые 30с |
| Метрики стримов | 100% | 20% | 2% |
| Идентификационные события | 100% | 100% | 100% |
| Шифрованные данные | По мере необходимости | По мере необходимости | По мере необходимости |

### 7.2. Интерпретация метрик

| Метрика | Норма | Предупреждение | Критическое состояние |
|---------|-------|----------------|----------------------|
| Latency (unary) | < 100ms | 100-500ms | > 500ms |
| Error rate | < 0.1% | 0.1-1% | > 1% |
| Connection errors | < 0.01% | 0.01-0.1% | > 0.1% |
| Memory usage | < 70% | 70-85% | > 85% |
| CPU usage | < 60% | 60-80% | > 80% |
| Stream backpressure | < 5% | 5-20% | > 20% |
| Encryption overhead | < 5ms | 5-20ms | > 20ms |

### 7.3. Корреляция клиент-сервер

Для эффективной диагностики рекомендуется коррелировать клиентские и серверные метрики на основе следующих идентификаторов:

1. `traceId` - основной ключ корреляции для всего пути запроса
2. `requestId` - для сопоставления конкретных запросов и ответов
3. `sessionId` - для отслеживания поведения в рамках одной сессии
4. `methodName` и `serviceName` - для агрегации по функциональности
5. `clientId` и `deploymentId` - для корреляции данных от одного клиента

### 7.4. Идентификация клиентов

Рекомендации по уникальной идентификации клиентов:

1. **Генерация clientId** - каждый экземпляр клиента должен иметь уникальный идентификатор, который сохраняется между сессиями
2. **Группировка по deploymentId** - разные версии и выпуски приложений должны иметь разные идентификаторы развертывания
3. **Сохранение контекста** - метаданные окружения и версии приложения должны присутствовать во всех метриках
4. **Разделение по организациям** - в мульти-тенантных системах необходим идентификатор организации

### 7.5. Работа с шифрованными данными

Рекомендации по работе с шифрованными диагностическими данными:

1. **Ключи шифрования** - используйте уникальные ключи для каждого клиента или развертывания
2. **Обновление ключей** - периодически обновляйте ключи шифрования (key rotation)
3. **Чувствительность данных** - шифруйте только действительно чувствительные данные
4. **Производительность** - учитывайте накладные расходы на шифрование/расшифровку
5. **Безопасное хранение** - обеспечьте безопасное хранение ключей шифрования на диагностическом сервере

### 7.6. Хранение и анализ

Рекомендуемые параметры хранения метрик:

| Тип метрики | Период хранения | Агрегация |
|-------------|-----------------|-----------|
| Трассировочные события | 7 дней | Нет |
| Ошибки | 30 дней | Суточная |
| Метрики производительности | 14 дней | Часовая |
| Системные метрики | 30 дней | Часовая |
| Аггрегированные показатели | 1 год | Суточная |
| Клиентская идентификация | Весь период работы клиента | Нет |

## 8. Визуализация

Рекомендуемые панели мониторинга для диагностического центра:

1. **Overview Dashboard**
   - Общее состояние системы
   - Ключевые индикаторы производительности
   - Счетчики ошибок

2. **Service Performance Dashboard**
   - Latency по сервисам и методам
   - Throughput по сервисам
   - Топ-10 самых медленных методов

3. **Trace Explorer**
   - Поиск по трассировкам
   - Визуализация цепочек вызовов
   - Breakdown времени выполнения

4. **Stream Monitor**
   - Активные стримы
   - Пропускная способность
   - События создания/закрытия

5. **Error Analysis**
   - Распределение ошибок по типам
   - Тренды возникновения ошибок
   - Детали для отладки

6. **Client Monitor**
   - Статистика по клиентам
   - Сравнение производительности между клиентами
   - Фильтрация данных по клиентам/развертываниям

7. **Security Dashboard**
   - Статус шифрования
   - Уровни доступа к данным
   - Журнал доступа к чувствительным данным 