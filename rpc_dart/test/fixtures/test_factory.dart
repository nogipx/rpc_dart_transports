// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';
import 'test_contract.dart';

/// Интерфейс для расширяемых тестовых контрактов
abstract class IExtensionTestContract extends RpcServiceContract {
  // Пустой интерфейс, просто для типизации
  IExtensionTestContract(String serviceName) : super(serviceName);
}

/// Класс для сборки тестового контракта с расширениями
class TestContractFactory {
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

      clientExtensions[factory.type] = clientExtension;
      serverExtensions[factory.type] = serverExtension;
    }

    // Создаем сервисные контракты
    final serverContract = _createContract(
      serviceName: 'test_composite_server',
      extensions: serverExtensions.values.toList(),
      isClient: false,
    );

    final clientContract = _createContract(
      serviceName: 'test_composite_client',
      extensions: clientExtensions.values.toList(),
      isClient: true,
      endpoint: clientEndpoint,
    );

    // Регистрируем ТОЛЬКО серверный контракт
    serverEndpoint.registerServiceContract(serverContract);

    // Клиентский контракт НЕ регистрируем на эндпоинте

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
