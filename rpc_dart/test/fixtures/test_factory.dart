// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

class EndpointPair {
  final RpcEndpoint client;
  final RpcEndpoint server;

  EndpointPair({required this.client, required this.server});
}

class TestEnvironment<Client extends RpcServiceContract,
    Server extends RpcServiceContract> {
  final RpcEndpoint clientEndpoint;
  final RpcEndpoint serverEndpoint;
  final Client clientContract;
  final Server serverContract;

  TestEnvironment({
    required this.clientEndpoint,
    required this.serverEndpoint,
    required this.clientContract,
    required this.serverContract,
  });
}

/// Фабрика для создания тестового окружения с явной регистрацией методов
class TestFactory {
  /// Создает тестовое окружение с регистрацией методов
  ///
  /// Регистрирует только явно переданные контракты, без автоматических добавлений
  static TestEnvironment<Client, Server> setupTestContract<
      Client extends RpcServiceContract, Server extends RpcServiceContract>({
    required Client Function(RpcEndpoint) clientFactory,
    required Server Function() serverFactory,
    EndpointPair? endpointPair,
  }) {
    // Создаем транспорты и эндпоинты
    final endpoints = endpointPair ??
        createEndpointPair(
          clientLabel: 'client',
          serverLabel: 'server',
        );

    // Создаем контракты через фабрики
    final clientContract = clientFactory(endpoints.client);
    final serverContract = serverFactory();

    // Регистрируем контракты непосредственно в эндпоинтах
    endpoints.client.registerServiceContract(clientContract);
    endpoints.server.registerServiceContract(serverContract);

    return TestEnvironment(
      clientEndpoint: endpoints.client,
      serverEndpoint: endpoints.server,
      clientContract: clientContract,
      serverContract: serverContract,
    );
  }

  static EndpointPair createEndpointPair({
    required String clientLabel,
    required String serverLabel,
  }) {
    final clientTransport = MemoryTransport('client');
    final serverTransport = MemoryTransport('server');

    clientTransport.connect(serverTransport);
    serverTransport.connect(clientTransport);

    return EndpointPair(
      client: RpcEndpoint(
        transport: clientTransport,
        debugLabel: clientLabel,
      ),
      server: RpcEndpoint(
        transport: serverTransport,
        debugLabel: serverLabel,
      ),
    );
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
