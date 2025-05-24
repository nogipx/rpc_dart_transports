// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

// Импортируем части контракта
part 'subcontracts/unary_tests.dart';
part 'subcontracts/client_streaming_tests.dart';
part 'subcontracts/server_streaming_tests.dart';
part 'subcontracts/bidirectional_tests.dart';
part 'subcontracts/transport_tests.dart';
part 'subcontracts/serialization_tests.dart';

/// Базовое тестовое сообщение
class TestMessage extends IRpcSerializableMessage {
  final String data;
  const TestMessage(this.data);

  @override
  Map<String, dynamic> toJson() => {'data': data};

  factory TestMessage.fromJson(Map<String, dynamic> json) {
    return TestMessage(json['data'] as String? ?? '');
  }

  @override
  String toString() => 'TestMessage(data: $data)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestMessage && other.data == data;
  }

  @override
  int get hashCode => data.hashCode;
}

/// Базовый контракт для тестов
/// Объединяет все группы тестов в единый интерфейс
abstract base class TestFixtureBaseContract extends OldRpcServiceContract {
  final UnaryTestsSubcontract unaryTests;
  final ClientStreamingTestsSubcontract clientStreamingTests;
  final ServerStreamingTestsSubcontract serverStreamingTests;
  final BidirectionalTestsSubcontract bidirectionalTests;
  final TransportTestsSubcontract transportTests;
  final SerializationTestsSubcontract serializationTests;

  TestFixtureBaseContract()
      : unaryTests = UnaryTestsServer(),
        clientStreamingTests = ClientStreamingTestsServer(),
        serverStreamingTests = ServerStreamingTestsServer(),
        bidirectionalTests = BidirectionalTestsServer(),
        transportTests = TransportTestsServer(),
        serializationTests = SerializationTestsServer(),
        super('test_fixture');

  @override
  void setup() {
    addSubContract(unaryTests);
    addSubContract(clientStreamingTests);
    addSubContract(serverStreamingTests);
    addSubContract(bidirectionalTests);
    addSubContract(transportTests);
    addSubContract(serializationTests);

    super.setup();
  }
}

/// Серверная реализация тестового контракта
/// Используется в тестах для обработки запросов
final class TestFixtureServerContract extends TestFixtureBaseContract {
  final RpcEndpoint _endpoint;

  TestFixtureServerContract(this._endpoint) : super() {
    _endpoint.registerServiceContract(this);
  }
}

/// Клиентская реализация тестового контракта
/// Используется в тестах для отправки запросов
final class TestFixtureClientContract extends TestFixtureBaseContract {
  final RpcEndpoint _endpoint;

  TestFixtureClientContract(this._endpoint, {bool shouldRegister = true})
      : super() {
    if (shouldRegister) {
      _endpoint.registerServiceContract(this);
    }
  }
}

/// Утилиты для создания тестового окружения
class TestFixtureUtils {
  /// Создает пару эндпоинтов для тестирования (клиент и сервер)
  static ({
    RpcEndpoint client,
    RpcEndpoint server,
  }) createEndpointPair({
    String clientLabel = 'client',
    String serverLabel = 'server',
  }) {
    // Создаем транспорты
    final clientTransport = MemoryTransport(clientLabel);
    final serverTransport = MemoryTransport(serverLabel);

    // Соединяем транспорты
    clientTransport.connect(serverTransport);
    serverTransport.connect(clientTransport);

    // Создаем эндпоинты
    final clientEndpoint = RpcEndpoint(
      transport: clientTransport,
      debugLabel: clientLabel,
    );

    final serverEndpoint = RpcEndpoint(
      transport: serverTransport,
      debugLabel: serverLabel,
    );

    return (client: clientEndpoint, server: serverEndpoint);
  }

  /// Создает и регистрирует тестовый контракт
  static ({
    TestFixtureClientContract client,
    TestFixtureServerContract server,
  }) createTestContracts(
    RpcEndpoint clientEndpoint,
    RpcEndpoint serverEndpoint, {
    bool registerClientContract = false,
  }) {
    // Создаем серверный контракт
    final serverContract = TestFixtureServerContract(serverEndpoint);

    // Создаем клиентский контракт
    final clientContract = TestFixtureClientContract(
      clientEndpoint,
      shouldRegister: registerClientContract,
    );

    return (client: clientContract, server: serverContract);
  }

  /// Создает полное тестовое окружение с эндпоинтами и контрактами
  static ({
    RpcEndpoint clientEndpoint,
    RpcEndpoint serverEndpoint,
    TestFixtureClientContract clientContract,
    TestFixtureServerContract serverContract,
  }) setupTestEnvironment({bool registerClientContract = false}) {
    final endpoints = createEndpointPair();
    final contracts = createTestContracts(
      endpoints.client,
      endpoints.server,
      registerClientContract: registerClientContract,
    );

    return (
      clientEndpoint: endpoints.client,
      serverEndpoint: endpoints.server,
      clientContract: contracts.client,
      serverContract: contracts.server,
    );
  }

  /// Очищает тестовое окружение
  static Future<void> tearDown(
    RpcEndpoint clientEndpoint,
    RpcEndpoint serverEndpoint,
  ) async {
    await clientEndpoint.close();
    await serverEndpoint.close();
  }
}
