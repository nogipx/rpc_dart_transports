# Подход к тестированию RPC библиотеки

В этом проекте используется фабричный подход для организации тестов RPC библиотеки.

## Фабричный подход с использованием расширяемых контрактов

Этот подход использует фабрику для динамического создания и комбинирования тестовых контрактов. Преимущества:

- Легко добавлять новые типы тестовых контрактов
- Не требуется создавать новые классы для каждой комбинации контрактов
- Позволяет переиспользовать существующие контракты в разных комбинациях
- Унифицированный подход ко всем тестам в библиотеке
- Меньше дублирования кода благодаря централизованному созданию тестового окружения

Ключевые компоненты:
- `IExtensionTestContract` - интерфейс для расширяемых тестовых контрактов
- `TestContractFactory` - фабрика для создания тестовых контрактов и окружения
- Пользовательские контракты, реализующие `IExtensionTestContract`

### Важное замечание о регистрации контрактов

В RPC архитектуре клиентские контракты **НЕ должны регистрироваться** на эндпоинтах. Регистрация приводит к ошибке типов, так как клиентские и серверные реализации методов отличаются. Поэтому:

- Серверные контракты должны быть зарегистрированы на серверном эндпоинте
- Клиентские контракты НЕ должны быть зарегистрированы ни на каком эндпоинте
- Клиентские контракты просто используют эндпоинты для отправки запросов

## Примеры использования

### Базовая настройка с одним контрактом

```dart
// Настройка тестового окружения с фабрикой
final testEnv = TestContractFactory.setupTestEnvironment(
  extensionFactories: [
    (
      type: CalculatorTestsContract,
      clientFactory: (endpoint) => CalculatorTestsClient(endpoint),
      serverFactory: () => CalculatorTestsServer(),
    ),
  ],
);

// Извлечение компонентов из тестового окружения
final clientEndpoint = testEnv.clientEndpoint;
final serverEndpoint = testEnv.serverEndpoint;
final clientContract = testEnv.clientContract;
final serverContract = testEnv.serverContract;

// Получение конкретных реализаций из коллекции расширений
final calculatorClient = 
    testEnv.clientExtensions.get<CalculatorTestsContract>() as CalculatorTestsClient;
final calculatorServer = 
    testEnv.serverExtensions.get<CalculatorTestsContract>() as CalculatorTestsServer;
```

### Настройка с несколькими контрактами

```dart
// Настройка тестового окружения с несколькими расширениями
final testEnv = TestContractFactory.setupTestEnvironment(
  extensionFactories: [
    (
      type: CalculatorTestsContract,
      clientFactory: (endpoint) => CalculatorTestsClient(endpoint),
      serverFactory: () => CalculatorTestsServer(),
    ),
    (
      type: LoggingTestsContract,
      clientFactory: (endpoint) => LoggingTestsClient(endpoint),
      serverFactory: () => LoggingTestsServer(),
    ),
    (
      type: AuthTestsContract,
      clientFactory: (endpoint) => AuthTestsClient(endpoint),
      serverFactory: () => AuthTestsServer(),
    ),
  ],
);

// Получение конкретных реализаций
final calculatorClient = testEnv.clientExtensions.get<CalculatorTestsContract>() as CalculatorTestsClient;
final loggingClient = testEnv.clientExtensions.get<LoggingTestsContract>() as LoggingTestsClient;
final authClient = testEnv.clientExtensions.get<AuthTestsContract>() as AuthTestsClient;
```

### Использование с базовыми контрактами

```dart
// Создание тестового окружения с базовыми контрактами и дополнительными расширениями
final testEnv = TestContractFactory.setupTestEnvironmentWithBase(
  extensionFactories: [
    (
      type: CalculatorTestsContract,
      clientFactory: (endpoint) => CalculatorTestsClient(endpoint),
      serverFactory: () => CalculatorTestsServer(),
    ),
  ],
);

// Доступ к базовым контрактам и расширениям
final baseClientContract = testEnv.baseClientContract;
final baseServerContract = testEnv.baseServerContract;
final calculatorClient = testEnv.clientExtensions.get<CalculatorTestsContract>() as CalculatorTestsClient;

// Теперь можно использовать и базовые методы, и методы из расширений
final echoResponse = await baseClientContract.unaryTests.echoUnary(UnaryRequest("test"));
final calcResponse = await calculatorClient.calculate(CalculationRequest(10, 5, "add"));
```

## Создание нового типа тестов

Для создания нового типа тестов достаточно:

1. Создать абстрактный класс, наследующий от `IExtensionTestContract`
2. Создать серверную и клиентскую реализации этого класса
3. Использовать фабрику для включения нового типа тестов в тестовое окружение

```dart
// Определение нового типа тестов
abstract class AuthTestsContract extends IExtensionTestContract {
  AuthTestsContract() : super('auth_tests');
  
  Future<AuthResponse> login(AuthRequest request);
}

// Использование нового типа в тестах
final testEnv = TestContractFactory.setupTestEnvironment(
  extensionFactories: [
    (
      type: AuthTestsContract,
      clientFactory: (endpoint) => AuthTestsClient(endpoint),
      serverFactory: () => AuthTestsServer(),
    ),
  ],
);

// Получение реализации
final authClient = testEnv.clientExtensions.get<AuthTestsContract>() as AuthTestsClient;
``` 