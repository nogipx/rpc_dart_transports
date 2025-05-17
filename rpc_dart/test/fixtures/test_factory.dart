// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';
import 'test_contract.dart';
import 'dart:mirrors';

/// Интерфейс для расширяемых тестовых контрактов
abstract class IExtensionTestContract extends RpcServiceContract {
  // Пустой интерфейс, просто для типизации
  IExtensionTestContract(String serviceName) : super(serviceName);
}

/// Класс для сборки тестового контракта с расширениями
class TestContractFactory {
  /// Отладка - получить список зарегистрированных сервисов
  static Map<String, dynamic> debugGetRegisteredServices(RpcEndpoint endpoint) {
    try {
      final instanceMirror = reflect(endpoint);

      // Попытка получить приватное поле _contracts
      final field = instanceMirror.type.declarations.entries
          .firstWhere((d) => d.key.toString() == 'Symbol("_contracts")')
          .value as VariableMirror;

      final contracts = instanceMirror.getField(field.simpleName).reflectee;
      return contracts as Map<String, dynamic>;
    } catch (e) {
      print('Debug: Ошибка при использовании reflection: $e');
      return {};
    }
  }

  /// Создает контракт с базовыми и дополнительными субконтрактами
  static RpcServiceContract _createContract({
    required String serviceName,
    required List<IExtensionTestContract> extensions,
    bool isClient = false,
    RpcEndpoint? endpoint,
  }) {
    // Проверка наличия эндпоинта для клиентского контракта
    if (isClient && endpoint == null) {
      throw ArgumentError('Для клиентского контракта необходим endpoint');
    }

    // Создаем композитный контракт
    final contract = _CompositeServiceContract(
      serviceName: serviceName,
    );

    // Регистрируем все расширения
    for (final extension in extensions) {
      contract.addSubContract(extension);
    }

    return contract;
  }

  /// Создает тестовое окружение со всеми необходимыми субконтрактами
  static ({
    RpcEndpoint clientEndpoint,
    RpcEndpoint serverEndpoint,
    RpcServiceContract clientContract,
    RpcServiceContract serverContract,
    Map<Type, IExtensionTestContract> clientExtensions,
    Map<Type, IExtensionTestContract> serverExtensions,
  }) setupTestEnvironment({
    required List<
            ({
              Type type,
              IExtensionTestContract Function(RpcEndpoint) clientFactory,
              IExtensionTestContract Function() serverFactory,
            })>
        extensionFactories,
  }) {
    // Создаем пару эндпоинтов
    final endpoints = TestFixtureUtils.createEndpointPair();
    final clientEndpoint = endpoints.client;
    final serverEndpoint = endpoints.server;

    final clientExtensions = <Type, IExtensionTestContract>{};
    final serverExtensions = <Type, IExtensionTestContract>{};

    // Создаем все расширения через фабрики
    for (final factory in extensionFactories) {
      final clientExtension = factory.clientFactory(clientEndpoint);
      final serverExtension = factory.serverFactory();

      print(
          'Debug: Регистрируем сервис с именем: ${serverExtension.serviceName}');

      clientExtensions[factory.type] = clientExtension;
      serverExtensions[factory.type] = serverExtension;

      // Регистрируем каждый серверный контракт напрямую
      serverEndpoint.registerServiceContract(serverExtension);

      // ВАЖНО: Теперь регистрируем и клиентские контракты тоже
      clientEndpoint.registerServiceContract(clientExtension);

      // ВАЖНО: Дополнительно регистрируем методы напрямую для серверного контракта
      for (final method in serverExtension.methods) {
        print(
            'Debug: Явная регистрация метода ${method.methodName} типа ${method.methodType}');
        final methodName = method.methodName;

        // Получаем обработчики напрямую из контракта
        dynamic handler;
        dynamic argumentParser;
        dynamic responseParser;

        try {
          // Получение handler из контракта
          handler = serverExtension.getMethodHandler(methodName);
          print(
              'Debug: Handler для метода $methodName: ${handler != null ? "найден" : "не найден"}');

          // Получение argumentParser из контракта
          argumentParser = serverExtension.getMethodArgumentParser(methodName);
          print(
              'Debug: ArgumentParser для метода $methodName: ${argumentParser != null ? "найден" : "не найден"}');

          // Получение responseParser из контракта
          responseParser = serverExtension.getMethodResponseParser(methodName);
          print(
              'Debug: ResponseParser для метода $methodName: ${responseParser != null ? "найден" : "не найден"}');
        } catch (e) {
          print('Debug: Ошибка при получении обработчиков: $e');
        }

        if (handler == null || argumentParser == null) {
          print(
              'Debug: Пропускаем метод ${method.methodName} из-за отсутствия обязательных параметров');
          continue;
        }

        // При отсутствующем responseParser для streaming методов создадим пустую функцию
        if (responseParser == null &&
            (method.methodType == RpcMethodType.serverStreaming ||
                method.methodType == RpcMethodType.bidirectional)) {
          print(
              'Debug: Создание пустого responseParser для метода ${method.methodName}');
          responseParser = (dynamic json) => json;
        }

        // Явная регистрация метода в зависимости от его типа
        try {
          switch (method.methodType) {
            case RpcMethodType.unary:
              serverEndpoint
                  .unaryRequest(
                    serviceName: serverExtension.serviceName,
                    methodName: methodName,
                  )
                  .register(
                    handler: handler,
                    requestParser: argumentParser,
                    responseParser: responseParser,
                  );
              break;
            case RpcMethodType.serverStreaming:
              serverEndpoint
                  .serverStreaming(
                    serviceName: serverExtension.serviceName,
                    methodName: methodName,
                  )
                  .register(
                    handler: handler,
                    requestParser: argumentParser,
                    responseParser: responseParser,
                  );
              break;
            case RpcMethodType.clientStreaming:
              serverEndpoint
                  .clientStreaming(
                    serviceName: serverExtension.serviceName,
                    methodName: methodName,
                  )
                  .register(
                    handler: handler,
                    requestParser: argumentParser,
                  );
              break;
            case RpcMethodType.bidirectional:
              serverEndpoint
                  .bidirectionalStreaming(
                    serviceName: serverExtension.serviceName,
                    methodName: methodName,
                  )
                  .register(
                    handler: handler,
                    requestParser: argumentParser,
                    responseParser: responseParser,
                  );
              break;
          }
          print('Debug: Метод ${method.methodName} успешно зарегистрирован');
        } catch (e) {
          print(
              'Debug: Ошибка при регистрации метода ${method.methodName}: $e');
        }
      }
    }

    // Создаем композитный серверный контракт (для организации в тестах)
    final serverContract = _createContract(
      serviceName: 'test_composite_server',
      extensions: serverExtensions.values.toList(),
      isClient: false,
    );

    // Создаем композитный клиентский контракт
    final clientContract = _createContract(
      serviceName: 'test_composite_client',
      extensions: clientExtensions.values.toList(),
      isClient: true,
      endpoint: clientEndpoint,
    );

    return (
      clientEndpoint: clientEndpoint,
      serverEndpoint: serverEndpoint,
      clientContract: clientContract,
      serverContract: serverContract,
      clientExtensions: clientExtensions,
      serverExtensions: serverExtensions,
    );
  }

  /// Универсальный метод для создания тестового окружения со стандартными субконтрактами
  /// плюс дополнительными расширениями
  static ({
    RpcEndpoint clientEndpoint,
    RpcEndpoint serverEndpoint,
    TestFixtureBaseContract baseClientContract,
    TestFixtureBaseContract baseServerContract,
    Map<Type, IExtensionTestContract> clientExtensions,
    Map<Type, IExtensionTestContract> serverExtensions,
  }) setupTestEnvironmentWithBase({
    required List<
            ({
              Type type,
              IExtensionTestContract Function(RpcEndpoint) clientFactory,
              IExtensionTestContract Function() serverFactory,
            })>
        extensionFactories,
  }) {
    // Создаем пару эндпоинтов
    final endpoints = TestFixtureUtils.createEndpointPair();
    final clientEndpoint = endpoints.client;
    final serverEndpoint = endpoints.server;

    // Создаем базовые контракты с правильными настройками регистрации
    final contracts = TestFixtureUtils.createTestContracts(
      clientEndpoint,
      serverEndpoint,
      // Важно! Клиентский контракт НЕ регистрируем на эндпоинте
      registerClientContract: false,
    );

    final baseClientContract = contracts.client;
    final baseServerContract = contracts.server;

    final clientExtensions = <Type, IExtensionTestContract>{};
    final serverExtensions = <Type, IExtensionTestContract>{};

    // Создаем все расширения через фабрики
    for (final factory in extensionFactories) {
      final clientExtension = factory.clientFactory(clientEndpoint);
      final serverExtension = factory.serverFactory();

      // Добавляем расширения в базовые контракты
      baseClientContract.addSubContract(clientExtension);
      baseServerContract.addSubContract(serverExtension);

      // Сохраняем ссылки на расширения для доступа в тестах
      clientExtensions[factory.type] = clientExtension;
      serverExtensions[factory.type] = serverExtension;
    }

    return (
      clientEndpoint: clientEndpoint,
      serverEndpoint: serverEndpoint,
      baseClientContract: baseClientContract,
      baseServerContract: baseServerContract,
      clientExtensions: clientExtensions,
      serverExtensions: serverExtensions,
    );
  }
}

/// Композитный контракт, содержащий множество субконтрактов
class _CompositeServiceContract extends RpcServiceContract {
  _CompositeServiceContract({
    required String serviceName,
  }) : super(serviceName);
}

/// Удобная обертка для получения расширения из мапы расширений по типу
extension ExtensionAccessor on Map<Type, IExtensionTestContract> {
  /// Получить расширение по его типу
  T get<T extends IExtensionTestContract>() {
    final extension = this[T];
    if (extension == null) {
      throw StateError('Расширение типа $T не найдено');
    }
    return extension as T;
  }
}
