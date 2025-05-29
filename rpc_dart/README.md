[![Pub Version](https://img.shields.io/pub/v/rpc_dart.svg)](https://pub.dev/packages/rpc_dart)

# RPC Dart

> **Создавайте масштабируемые, типобезопасные приложения через чистую доменную архитектуру**

RPC Dart — это мощная библиотека для построения приложений с использованием архитектурного подхода **Backend-for-Domain (BFD)**, обеспечивающая кроссплатформенную коммуникацию между изолированными доменами с полной поддержкой типобезопасности и стриминга.

## Архитектурный подход Backend-for-Domain

Backend-for-Domain (BFD) — это современный архитектурный подход, решающий фундаментальную проблему организации кода в сложных приложениях путем четкого разделения на изолированные домены с формальными контрактами взаимодействия.

### Основные принципы BFD

1. **Доменная изоляция**
   - Каждый домен представляет собой независимую бизнес-область с четкими границами
   - Домены взаимодействуют только через формальные API-контракты
   - Внутренняя реализация домена полностью скрыта от других частей системы

2. **Контрактное взаимодействие**
   - Все взаимодействия между доменами формализованы в виде интерфейсов-контрактов
   - Контракты определяют типы данных, методы и потоки для коммуникации
   - Компилятор проверяет соответствие всех взаимодействий контрактам

3. **Транспортная независимость**
   - Бизнес-логика не зависит от способа передачи данных
   - Один и тот же код работает как для локальных, так и для удаленных вызовов
   - Транспорты легко заменяются в зависимости от контекста использования

4. **Эволюционная масштабируемость**
   - Архитектура "растет" вместе с проектом без необходимости кардинальных изменений
   - Локальные вызовы легко трансформируются в распределенные при необходимости
   - Поддержка всех паттернов коммуникации: от унарных до двунаправленных стримов

```
┌───────────────────┐       ┌────────────────────┐
│   Домен клиента   │       │   Домен сервера    │
│                   │       │                    │
│  ┌─────────────┐  │       │  ┌─────────────┐   │
│  │ Caller      │◄─┼───────┼─►│ Responder   │   │
│  │ Contract    │  │       │  │ Contract    │   │
│  └─────────────┘  │       │  └─────────────┘   │
│                   │       │                    │
└───────────────────┘       └────────────────────┘
```

### Компоненты BFD архитектуры

- **Contract** — интерфейсы, определяющие API взаимодействия между доменами
- **Responder** — серверная сторона, реализующая бизнес-логику и обрабатывающая запросы
- **Caller** — клиентская сторона, инициирующая запросы к другим доменам
- **Transport** — механизмы передачи данных между доменами
- **Endpoint** — точки подключения контрактов к транспортам
- **Codec** — сериализаторы/десериализаторы для типобезопасного преобразования данных

### Преимущества BFD перед традиционными подходами

- **Типобезопасность от начала до конца** — ошибки обнаруживаются на этапе компиляции
- **Чистая доменная логика** — бизнес-правила не зависят от инфраструктуры и UI
- **Гибкое масштабирование** — эволюция от монолита к микросервисам без переписывания кода
- **Упрощенное тестирование** — изолированные компоненты легко тестировать по отдельности
- **Полиглотная совместимость** — возможность взаимодействия с компонентами на других языках через общие протоколы
- **Производительность** — возможность распараллеливания через изоляты без изменения кода

### Сценарии применения BFD

- **Фронтенд/Бэкенд изоляция** — отделение UI от бизнес-логики даже в монолитных приложениях
- **Многопоточная обработка** — безопасное распараллеливание через изоляты с типобезопасной коммуникацией
- **Микрофронтенды** — организация больших приложений как набора независимых мини-приложений
- **Распределенные системы** — единый код для локального прототипа и распределенной продакшн-системы
- **Мультиплатформенные приложения** — единая бизнес-логика для разных платформ с разными UI

## 🚀 Особенности

- **Контрактная архитектура** — формальное определение API между доменами
- **Транспортная независимость** — от in-memory для тестов до WebSockets в продакшене
- **Полная типобезопасность** — компилятор проверяет правильность всех взаимодействий
- **Все типы RPC** — унарный, серверный/клиентский/двунаправленный стриминг
- **CBOR сериализация** — компактная и эффективная передача данных
- **Изоляция уровней** — бизнес-логика не зависит от UI и транспорта
- **Тестируемость** — легкая подмена транспортов и моков для тестирования

## Использование BFD в экосистеме Flutter

Backend-for-Domain отлично интегрируется в экосистему Flutter:

1. **В монолитных приложениях** — для разделения UI от бизнес-логики и обеспечения чистых границ между функциональными модулями
2. **При работе с изолятами** — для типобезопасной коммуникации между потоками
3. **В микрофронтендах** — для коммуникации между мини-приложениями внутри одного контейнера
4. **В распределенных системах** — один и тот же код можно использовать как для локальной, так и для удаленной коммуникации

### Ключевые преимущества при эволюции проекта

BFD позволяет **эволюционировать архитектуру** вместе с ростом проекта:

1. **Начните с монолита** — используйте `RpcInMemoryTransport` для коммуникации между доменами
2. **Масштабируйте с изолятами** — замените на `RpcIsolateTransport` для многопоточности
3. **Переходите к микросервисам** — используйте сетевые транспорты для распределения

**Ваш код доменов остается неизменным на всех этапах!**

## Архитектура и концепции

### Контракты

Контракты определяют API для взаимодействия между компонентами:

```dart
/// Общий интерфейс для контракта 
abstract interface class ICalculatorContract implements IRpcContract {
  static const methodCalculate = 'calculate';
  static const methodStreamCalculate = 'streamCalculate';

  /// Выполняет одиночную операцию
  Future<CalculationResponse> calculate(CalculationRequest request);

  /// Обрабатывает поток вычислений
  Stream<CalculationResponse> streamCalculate(
    Stream<CalculationRequest> requests,
  );
}
```

### Серверная и клиентская реализации

```dart
/// Серверная реализация
final class CalculatorResponder extends RpcResponderContract
    implements ICalculatorContract {
  
  CalculatorResponder() : super('CalculatorService');

  @override
  void setup() {
    // Регистрация методов
    addUnaryMethod<CalculationRequest, CalculationResponse>(
      methodName: ICalculatorContract.methodCalculate,
      handler: calculate,
      requestCodec: CalculationRequest.codec,
      responseCodec: CalculationResponse.codec,
    );

    addBidirectionalMethod<CalculationRequest, CalculationResponse>(
      methodName: ICalculatorContract.methodStreamCalculate,
      handler: streamCalculate,
      requestCodec: CalculationRequest.codec,
      responseCodec: CalculationResponse.codec,
    );
  }

  @override
  Future<CalculationResponse> calculate(CalculationRequest request) async {
    // Реализация бизнес-логики
    return CalculationResponse(result: performCalculation(request));
  }

  @override
  Stream<CalculationResponse> streamCalculate(
      Stream<CalculationRequest> requests) async* {
    await for (final request in requests) {
      yield CalculationResponse(result: performCalculation(request));
    }
  }
}

/// Клиентская реализация
class CalculatorCaller extends RpcCallerContract
    implements ICalculatorContract {
  
  CalculatorCaller(RpcCallerEndpoint endpoint)
      : super('CalculatorService', endpoint);

  @override
  Future<CalculationResponse> calculate(CalculationRequest request) {
    return endpoint.unaryRequest<CalculationRequest, CalculationResponse>(
      serviceName: serviceName,
      methodName: ICalculatorContract.methodCalculate,
      requestCodec: CalculationRequest.codec,
      responseCodec: CalculationResponse.codec,
      request: request,
    );
  }

  @override
  Stream<CalculationResponse> streamCalculate(
      Stream<CalculationRequest> requests) {
    return endpoint.bidirectionalStream<CalculationRequest, CalculationResponse>(
      serviceName: serviceName,
      methodName: ICalculatorContract.methodStreamCalculate,
      requestCodec: CalculationRequest.codec,
      responseCodec: CalculationResponse.codec,
      requests: requests,
    );
  }
}
```

### Типы коммуникации

RPC Dart поддерживает четыре типа взаимодействия:

```
┌──────────┐                 ┌──────────┐
│  Клиент  │                 │  Сервер  │
└────┬─────┘                 └────┬─────┘
     │       ──── Запрос ────▶    │     ◄── Унарный
     │       ◀─── Ответ ─────     │
     │                            │
     │       ──── Запрос ────▶    │     ◄── Серверный
     │       ◀─── Ответ1 ────     │         стриминг
     │       ◀─── Ответ2 ────     │
     │                            │
     │       ──── Запрос1 ───▶    │     ◄── Клиентский
     │       ──── Запрос2 ───▶    │         стриминг
     │       ◀─── Ответ ─────     │
     │                            │
     │       ──── Запрос1 ───▶    │     ◄── Двунаправленный
     │       ◀─── Ответ1 ────     │         стриминг
     │       ──── Запрос2 ───▶    │
     ▼                            ▼
```

### Транспорты

Транспорты абстрагируют механизм передачи данных:

```dart
// Создание транспортов
final transport = RpcInMemoryTransport.pair();

// Создание эндпоинтов
final serverEndpoint = RpcResponderEndpoint(
  transport: transport.$1,
  loggerColors: RpcLoggerColors.singleColor(AnsiColor.cyan),
);
final clientEndpoint = RpcCallerEndpoint(
  transport: transport.$2,
  loggerColors: RpcLoggerColors.singleColor(AnsiColor.magenta),
);
```

### Важное замечание при работе со стримами

Если вы создаете Responder напрямую (минуя RpcResponderEndpoint), необходимо явно привязать его к потоку сообщений:

```dart
// Создание транспортов
final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

// Создание responder'а напрямую
final server = ServerStreamResponder<RpcString, RpcString>(
  id: 1,
  transport: serverTransport,
  serviceName: 'TestService',
  methodName: 'TestMethod',
  requestCodec: serializer,
  responseCodec: serializer,
  handler: (request) async* {
    yield 'Response 1'.rpc;
    yield 'Response 2'.rpc;
  },
);

// ВАЖНО: Привязка к потоку сообщений
server.bindToMessageStream(
  serverTransport.incomingMessages.where((msg) => msg.streamId == 1),
);
```

Без этого шага респондер не будет получать сообщения от клиента, что приведет к "мертвым" стримам.

### Примитивные типы

Библиотека включает базовые примитивные типы с поддержкой операторов:

```dart
// Строковый тип
final stringMessage = RpcString("Hello World");

// Целочисленный тип с операторами
final intMessage = RpcInt(42);
final sum = intMessage + RpcInt(10); // RpcInt(52)

// Дробный тип
final doubleMessage = RpcDouble(3.14);

// Логический тип
final boolMessage = RpcBool(true);

// Пустое значение
final nullMessage = RpcNull();
```

## Рекомендации по применению

1. **Выделяйте чистые границы доменов** — определите контракты взаимодействия между компонентами
2. **Следуйте принципу единой ответственности** — каждый контракт должен иметь четкую цель
3. **Используйте подходящие транспорты** — `InMemoryTransport` для тестов, `IsolateTransport` для многопоточности
4. **Документируйте контракты** — они являются основой взаимодействия между командами
5. **Создавайте типобезопасные модели** — используйте преимущества статической типизации Dart
6. **Разделяйте модели по слоям** — используйте DTOs, Entities и State-классы для разных уровней

## Начало работы

```dart
// Создание транспортов
final transport = RpcInMemoryTransport.pair();

// Создание эндпоинтов
final serverEndpoint = RpcResponderEndpoint(transport: transport.$1);
final clientEndpoint = RpcCallerEndpoint(transport: transport.$2);

// Регистрация на сервере
final server = CalculatorResponder();
serverEndpoint.registerServiceContract(server);

// Использование на клиенте
final client = CalculatorCaller(clientEndpoint);

// Унарный вызов
final response = await client.calculate(
  CalculationRequest(a: 10, b: 5, operation: 'add')
);
print('Результат: ${response.result}'); // 15
```

## Обработка ошибок

При работе со стримами ошибки передаются в виде сообщений с метаданными:

```dart
// Отправка запроса
await client.send(request);

// Получение и обработка ответов
client.responses.listen((message) {
  if (message.isMetadataOnly) {
    // Проверка на ошибку (gRPC статус != 0 означает ошибку)
    final status = message.metadata?.getHeaderValue('grpc-status');
    final errorMessage = message.metadata?.getHeaderValue('grpc-message');
    
    if (status != null && status != '0') {
      print('Получена ошибка: $errorMessage (код: $status)');
      return;
    }
  }
  
  // Обработка полезной нагрузки
  if (message.payload != null) {
    print('Получен ответ: ${message.payload}');
  }
});
```

## Логирование и отладка

```dart
// Настройка уровня логирования
RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

// Создание логгера с цветовым оформлением
final logger = RpcLogger(
  'MyComponent',
  colors: RpcLoggerColors.singleColor(AnsiColor.cyan),
);

// Логирование
logger.info('Информация');
logger.error('Ошибка', error: exception);
```

## FAQ: Ответы на частые вопросы

### Не слишком ли это сложно для простых приложений?

**Честный ответ**: да, для очень маленьких приложений BFD может быть избыточен. Но большинство приложений не остаются маленькими навсегда. BFD обеспечивает плавный путь роста: начните с `InMemoryTransport` в монолитном приложении, и когда придет время масштабироваться, просто замените транспорт, не меняя бизнес-логику.

### Что насчет производительности? Все эти слои абстракции не замедлят работу?

Влияние на производительность минимально благодаря:
- Эффективной CBOR сериализации (компактнее JSON)
- Возможности работать полностью в памяти для локальных вызовов
- Поддержке изолятов, что позволяет распараллелить тяжелые вычисления

На практике, возможность легко переносить вычисления в отдельные потоки даёт прирост производительности в сравнении с монолитным подходом.

### Как BFD сочетается с BLoC/Provider/Riverpod?

Отлично сочетается! BLoC может использоваться для управления состоянием UI, а BFD — для коммуникации между доменами:

```dart
class UserBloc extends Bloc<UserEvent, UserState> {
  final UserServiceCaller _userService;
  
  UserBloc(this._userService) : super(UserInitial()) {
    on<LoadUserEvent>((event, emit) async {
      emit(UserLoading());
      try {
        final user = await _userService.getUserById(event.userId);
        emit(UserLoaded(user));
      } catch (e) {
        emit(UserError(e.toString()));
      }
    });
  }
}
```

### Как писать тесты для BFD компонентов?

Тестирование упрощается благодаря чистым границам между компонентами:

1. **Тестирование доменной логики**: тестируйте `Responder` классы напрямую, вызывая их методы
2. **Интеграционное тестирование**: используйте `InMemoryTransport` для проверки взаимодействия компонентов
3. **Мокирование**: легко создавайте моки для контрактов благодаря интерфейсам

```dart
test('должен правильно выполнять вычисления', () async {
  final calculator = CalculatorResponder();
  final response = await calculator.calculate(
    CalculationRequest(a: 5, b: 3, operation: 'add')
  );
  
  expect(response.result, equals(8));
});
```

### Не будет ли слишком много бойлерплейта?

Немного больше, чем при обычном подходе, но этот код:
- Типобезопасен, что снижает количество рантайм ошибок
- Имеет предсказуемую структуру, упрощающую чтение и поддержку
- Может быть сгенерирован инструментами для автоматизации

Выигрыш в долгосрочной перспективе компенсирует начальные затраты на написание контрактов.

### Что если я захочу изменить API? Насколько сложно будет вносить изменения?

Изменения в API с BFD становятся более контролируемыми:
- Контракты четко определяют, что именно меняется
- Компилятор подсвечивает все места, требующие обновления
- Версионирование контрактов упрощает поддержку обратной совместимости

### Стоит ли использовать BFD для веб-приложений на Flutter?

Да, особенно если:
- Вы планируете повторно использовать логику между мобильной и веб-версиями
- У вас есть компоненты с интенсивными вычислениями (можно выносить в Web Workers)
- Вы строите прогрессивное веб-приложение с оффлайн-функциональностью

### Можно ли частично внедрять BFD в существующий проект?

Абсолютно! Начните с изоляции одного домена через BFD, сохраняя остальную архитектуру нетронутой. Постепенно расширяйте применение подхода по мере роста выгоды от его использования.

### Почему мой стрим не получает сообщения или зависает?

Наиболее распространенная причина - отсутствие привязки responder'а к потоку сообщений через `bindToMessageStream()`. 

- При использовании `RpcResponderEndpoint` и регистрации контрактов эта привязка происходит автоматически
- При прямом создании responder'ов (`ServerStreamResponder`, `ClientStreamResponder`, `BidirectionalStreamResponder`) необходимо явно вызывать метод `bindToMessageStream(stream)`
- При обработке ошибок проверяйте gRPC статусы в метаданных (`response.metadata?.getHeaderValue('grpc-status')`) вместо использования `onError` в потоках

## Лицензия

LGPL-3.0-or-later
