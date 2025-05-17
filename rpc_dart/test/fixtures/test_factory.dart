// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

typedef ContractFactory<T extends RpcServiceContract> = ({
  Type type,
  T Function(RpcEndpoint) clientFactory,
  T Function() serverFactory,
});

typedef TestEnvironment = ({
  RpcEndpoint clientEndpoint,
  RpcEndpoint serverEndpoint,
  RpcServiceContract clientContract,
  RpcServiceContract serverContract,
  Map<Type, RpcServiceContract> clientContracts,
  Map<Type, RpcServiceContract> serverContracts,
  IRpcMethodRegistry clientRegistry,
  IRpcMethodRegistry serverRegistry,
});

/// Фабрика для создания тестового окружения с явной регистрацией методов
class TestFactory {
  /// Создает тестовое окружение с регистрацией методов
  ///
  /// Регистрирует только явно переданные контракты, без автоматических добавлений
  static TestEnvironment setupTestEnvironment({
    required List<ContractFactory> contractFactories,
  }) {
    // Создаем реестры и транспорты
    final clientRegistry = RpcMethodRegistry();
    final serverRegistry = RpcMethodRegistry();
    final (clientTransport, serverTransport) = _createConnectedTransports();

    // Создаем эндпоинты
    final clientEndpoint = RpcEndpoint(
      transport: clientTransport,
      debugLabel: 'client',
      methodRegistry: clientRegistry,
    );

    final serverEndpoint = RpcEndpoint(
      transport: serverTransport,
      debugLabel: 'server',
      methodRegistry: serverRegistry,
    );

    final clientContracts = <Type, RpcServiceContract>{};
    final serverContracts = <Type, RpcServiceContract>{};

    // Создаем контракты через фабрики
    for (final factory in contractFactories) {
      final clientContract = factory.clientFactory(clientEndpoint);
      final serverContract = factory.serverFactory();

      clientContracts[factory.type] = clientContract;
      serverContracts[factory.type] = serverContract;

      // Регистрируем контракты
      serverRegistry.registerContract(serverContract);
      clientRegistry.registerContract(clientContract); // Только для структуры
    }

    // Создаем композитные контракты
    final clientContract = _CompositeServiceContract(
      serviceName: 'fixture_contract',
      contracts: clientContracts.values.toList(),
    );

    final serverContract = _CompositeServiceContract(
      serviceName: 'fixture_contract',
      contracts: serverContracts.values.toList(),
    );

    return (
      clientEndpoint: clientEndpoint,
      serverEndpoint: serverEndpoint,
      clientContract: clientContract,
      serverContract: serverContract,
      clientContracts: clientContracts,
      serverContracts: serverContracts,
      clientRegistry: clientRegistry,
      serverRegistry: serverRegistry,
    );
  }

  /// Создает пару соединенных транспортов для тестирования
  static (MemoryTransport, MemoryTransport) _createConnectedTransports() {
    final clientTransport = MemoryTransport('client');
    final serverTransport = MemoryTransport('server');

    clientTransport.connect(serverTransport);
    serverTransport.connect(clientTransport);

    return (clientTransport, serverTransport);
  }

  /// Выводит отладочную информацию о методах в registry
  static void debugPrintRegisteredMethods(
      IRpcMethodRegistry registry, String label) {
    final methods = registry.getAllMethods();

    print('\n=== Методы в registry: $label (${methods.length}) ===');
    for (final method in methods) {
      print(
          '${method.serviceName}.${method.methodName} (${method.methodType})');
      print('  • Handler: ${method.handler != null ? 'Есть' : 'Нет!'}');
      print(
          '  • ArgParser: ${method.argumentParser != null ? 'Есть' : 'Нет!'}');
      print(
          '  • RespParser: ${method.responseParser != null ? 'Есть' : 'Нет!'}');
      print(
          '  • Implementation: ${method.implementation != null ? 'Есть' : 'Нет!'}');
    }
    print('=====================================\n');
  }

  /// Выводит информацию о зарегистрированных контрактах
  static void debugPrintRegisteredContracts(
      IRpcMethodRegistry registry, String label) {
    final contracts = registry.getAllContracts();

    print('\n=== Контракты в registry: $label (${contracts.length}) ===');
    for (final entry in contracts.entries) {
      final contractName = entry.key;
      final contract = entry.value;

      print('$contractName (${contract.runtimeType})');
      print('  • Методов: ${contract.methods.length}');

      if (contract is RpcServiceContract) {
        final subContracts = contract.getSubContracts();
        print('  • Субконтрактов: ${subContracts.length}');
        for (final subContract in subContracts) {
          print(
              '    - ${subContract.serviceName} (${subContract.methods.length} методов)');
        }
      }
    }
    print('=====================================\n');
  }
}

/// Композитный контракт, содержащий множество других контрактов
class _CompositeServiceContract extends RpcServiceContract {
  final List<RpcServiceContract> _contracts;

  _CompositeServiceContract({
    required String serviceName,
    required List<RpcServiceContract> contracts,
  })  : _contracts = contracts,
        super(serviceName);

  @override
  void setup() {
    for (final contract in _contracts) {
      addSubContract(contract);
    }
    super.setup();
  }
}

/// Удобная обертка для получения контракта из мапы контрактов по типу
extension ContractAccessor on Map<Type, RpcServiceContract> {
  /// Получить контракт по его типу
  T get<T extends RpcServiceContract>() {
    final contract = this[T];
    if (contract == null) {
      throw StateError('Контракт типа $T не найден');
    }
    return contract as T;
  }
}
