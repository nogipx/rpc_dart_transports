<!--
SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>

SPDX-License-Identifier: LGPL-3.0-or-later
-->

# Необходимые изменения для реализации диагностического сервиса

На основе анализа кодовой базы библиотеки RPC Dart, для реализации диагностического сервиса потребуются следующие изменения и дополнения:

## 1. Новые файлы для диагностики

### 1.1. Контракты и интерфейсы

- **`lib/src/diagnostics/contracts/diagnostic_contract.dart`**
  - Базовый контракт диагностического сервиса
  - Определение методов для сбора различных метрик

- **`lib/src/diagnostics/contracts/diagnostic_service.dart`**
  - Интерфейс для взаимодействия с диагностическим сервисом
  - Основной API для сбора метрик внутри библиотеки

### 1.2. Модели данных

- **`lib/src/diagnostics/models/client_identity.dart`**
  - Модель для идентификации клиентов
  - Включает clientId, deploymentId, deviceId и другие идентификаторы

- **`lib/src/diagnostics/models/trace_event.dart`**
  - Модель для трассировочных событий
  - Содержит информацию о вызовах методов и их выполнении

- **`lib/src/diagnostics/models/latency_metric.dart`**
  - Модель для метрик производительности
  - Содержит информацию о времени выполнения операций

- **`lib/src/diagnostics/models/stream_metric.dart`**
  - Модель для метрик стриминга
  - Содержит информацию о потоках данных

- **`lib/src/diagnostics/models/error_metric.dart`**
  - Модель для сбора информации об ошибках

- **`lib/src/diagnostics/models/resource_metric.dart`**
  - Модель для отслеживания использования ресурсов

- **`lib/src/diagnostics/models/encryption_info.dart`**
  - Модель информации о шифровании
  - Содержит keyId, режим шифрования и другие параметры

### 1.3. Реализации

- **`lib/src/diagnostics/client/diagnostic_client.dart`**
  - Клиентская реализация контракта
  - Отправляет метрики на сервер диагностики

- **`lib/src/diagnostics/client/no_op_diagnostic_client.dart`**
  - Реализация-заглушка для отключения диагностики
  - Все методы пустые для минимального влияния на производительность

- **`lib/src/diagnostics/middleware/diagnostic_middleware.dart`**
  - Middleware для автоматического сбора метрик
  - Встраивается в конвейер обработки запросов

- **`lib/src/diagnostics/transport/encrypted_transport.dart`**
  - Транспорт с поддержкой шифрования
  - Обертка вокруг существующих транспортов

- **`lib/src/diagnostics/collectors/metric_collector.dart`**
  - Собирает и агрегирует диагностические данные
  - Управляет семплированием и буферизацией

### 1.4. Утилиты

- **`lib/src/diagnostics/util/encryption_key.dart`**
  - Класс для управления ключами шифрования
  - Генерация, хранение и вращение ключей

- **`lib/src/diagnostics/util/sampling.dart`**
  - Утилиты для семплирования метрик
  - Позволяет контролировать объем собираемых данных

## 2. Изменения в существующих файлах

### 2.1. Расширение RpcEndpoint

Файл: **`lib/src/endpoint/_index.dart`**
- Добавить импорт для диагностических компонентов

Файл: **`lib/src/endpoint/rpc_endpoint.dart`**
- Добавить поддержку диагностики в класс RpcEndpoint:
```dart
// Добавить поле для хранения экземпляра диагностического сервиса
DiagnosticService? _diagnosticService;

// Добавить метод для включения диагностики
void enableDiagnostics({
  required DiagnosticContract contract,
  required ClientIdentity clientIdentity,
  DiagnosticOptions? options,
}) {
  _diagnosticService = DiagnosticClient(
    contract: contract,
    clientIdentity: clientIdentity,
    options: options ?? DiagnosticOptions(),
  );
}

// Добавить геттер для доступа к диагностическому сервису
DiagnosticService? get diagnostics => _diagnosticService;
```

### 2.2. Интеграция в транспортный слой

Файл: **`lib/src/transport/rpc_transport.dart`**
- Добавить интерфейс для шифрованного транспорта

### 2.3. Внедрение сбора метрик

Файл: **`lib/src/endpoint/impl/rpc_endpoint_core_impl.dart`**
- Добавить вызовы диагностического сервиса в следующие методы:
  - `_handleIncomingData` - для отслеживания входящих сообщений
  - `_handleRequest` - для измерения времени обработки запросов
  - `_handleResponse` - для фиксации времени получения ответов
  - `_handleError` - для сбора информации об ошибках
  - `_sendMessage` - для отслеживания исходящих сообщений
  - `openStream`, `sendStreamData`, `closeStream` - для мониторинга стримов

### 2.4. Автоматический сбор метрик

Файл: **`lib/src/middleware/middleware_chain.dart`**
- Добавить поддержку для диагностического middleware

### 2.5. Публичный API

Файл: **`lib/rpc_dart.dart`**
- Экспортировать публичные интерфейсы и классы диагностики
```dart
// Диагностика
export '../src/diagnostics/src/diagnostics/contracts/diagnostic_contract.dart';
export '../src/diagnostics/src/diagnostics/contracts/diagnostic_service.dart';
export '../src/diagnostics/src/diagnostics/models/client_identity.dart';
export '../src/diagnostics/src/diagnostics/client/diagnostic_client.dart';
export '../src/diagnostics/src/diagnostics/middleware/diagnostic_middleware.dart';
export '../src/diagnostics/src/diagnostics/transport/encrypted_transport.dart';
export '../src/diagnostics/src/diagnostics/util/encryption_key.dart';
```

## 3. Последовательность реализации

1. [DONE] Создать модели данных - базовые классы для всех метрик 
2. [DONE] Реализовать контракт диагностического сервиса - API для общения клиента с сервером
3. [DONE] Создать шифрованный транспорт - обертка над существующими транспортами
4. Имплементировать клиентскую и серверную части контракта
5. Разработать middleware для автоматического сбора метрик
6. Расширить RpcEndpoint функционалом для работы с диагностикой
7. Интегрировать вызовы диагностического сервиса в основные компоненты библиотеки
8. Обеспечить гибкое конфигурирование (включение/отключение, семплирование и т.д.)

## 4. Тестирование

Для полноценного тестирования диагностического сервиса необходимо создать:

- **`test/diagnostics/models_test.dart`** - тесты для моделей данных
- **`test/diagnostics/client_test.dart`** - тесты клиентской части
- **`test/diagnostics/middleware_test.dart`** - тесты middleware
- **`test/diagnostics/transport_test.dart`** - тесты шифрованного транспорта
- **`test/integration/diagnostics_integration_test.dart`** - интеграционные тесты

## 5. Потенциальные сложности

1. **Производительность**
   - Необходимо оптимизировать сбор метрик, чтобы минимизировать влияние на основной код
   - Реализовать семплирование и асинхронную обработку метрик

2. **Безопасность**
   - Обеспечить безопасность чувствительных данных через шифрование
   - Управление ключами шифрования

3. **Обратная совместимость**
   - Все изменения должны быть обратно совместимыми
   - Диагностика должна быть опциональной и отключаемой
