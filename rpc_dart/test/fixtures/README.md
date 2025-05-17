# Подходы к тестированию RPC библиотеки

В этом проекте реализовано два различных подхода к организации тестов RPC библиотеки.

## 1. Подход с использованием фабрики контрактов

Этот подход использует фабрику для динамического создания и комбинирования тестовых контрактов. Преимущества:

- Легко добавлять новые типы тестовых контрактов
- Не требуется создавать новые классы для каждой комбинации контрактов
- Позволяет переиспользовать существующие контракты в разных комбинациях

Ключевые компоненты:
- `IExtensionTestContract` - интерфейс для расширяемых тестовых контрактов
- `TestContractFactory` - фабрика для создания тестовых контрактов и окружения
- Пользовательские контракты, реализующие `IExtensionTestContract`

### Важное замечание о регистрации контрактов

В RPC архитектуре клиентские контракты **НЕ должны регистрироваться** на эндпоинтах. Регистрация приводит к ошибке типов, так как клиентские и серверные реализации методов отличаются. Поэтому:

- Серверные контракты должны быть зарегистрированы на серверном эндпоинте
- Клиентские контракты НЕ должны быть зарегистрированы ни на каком эндпоинте
- Клиентские контракты просто используют эндпоинты для отправки запросов

Пример использования:

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
clientEndpoint = testEnv.$1;
serverEndpoint = testEnv.$2;
clientContract = testEnv.$3;
serverContract = testEnv.$4;

// Получение конкретных реализаций из коллекции расширений
calculatorClient = testEnv.$5.get<CalculatorTestsContract>() as CalculatorTestsClient;
calculatorServer = testEnv.$6.get<CalculatorTestsContract>() as CalculatorTestsServer;
```

## 2. Прямой подход с явными контрактами

Этот подход не использует фабрики, а создает контракты напрямую. Преимущества:

- Более простой и прямолинейный код
- Меньше абстракций
- Легче понять с первого взгляда
- Не имеет зависимостей от дополнительной инфраструктуры

Ключевые компоненты:
- Конкретные классы контрактов, наследующиеся напрямую от `RpcServiceContract`
- Явное создание экземпляров контрактов
- Прямая регистрация контрактов в эндпоинтах

Пример использования:

```dart
// Создание транспортов и эндпоинтов
final clientTransport = MemoryTransport('client');
final serverTransport = MemoryTransport('server');

clientTransport.connect(serverTransport);
serverTransport.connect(clientTransport);

clientEndpoint = RpcEndpoint(
  transport: clientTransport,
  debugLabel: 'client',
);

serverEndpoint = RpcEndpoint(
  transport: serverTransport,
  debugLabel: 'server',
);

// Создание серверных реализаций контрактов
fileUploadServer = FileUploadServiceServer();
basicStreamServer = BasicStreamServiceServer();

// Регистрация контрактов на сервере
serverEndpoint.registerServiceContract(fileUploadServer);
serverEndpoint.registerServiceContract(basicStreamServer);

// Создание клиентских реализаций контрактов
fileUploadClient = FileUploadServiceClient(clientEndpoint);
basicStreamClient = BasicStreamServiceClient(clientEndpoint);
```

## Рекомендации по выбору подхода

1. **Используйте фабрику**, если:
   - У вас много различных типов тестов, которые нужно комбинировать
   - Вы часто создаете одни и те же комбинации контрактов в разных тестах
   - Важна возможность быстрого добавления новых контрактов без изменения структуры

2. **Используйте прямой подход**, если:
   - Тесты относительно простые и не требуют сложной инфраструктуры
   - Вам важна ясность и прямолинейность кода
   - У вас небольшое количество контрактов или они редко меняются

В обоих случаях можно создать удобные вспомогательные методы для упрощения настройки тестового окружения. 