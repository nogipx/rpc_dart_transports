// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../test_contract.dart';

/// Контракт для тестирования транспортов
abstract class TransportTestsSubcontract extends OldRpcServiceContract {
  // Константы для имен методов
  static const methodMemoryTransport = 'memoryTransport';
  static const methodJsonRpcTransport = 'jsonRpcTransport';
  static const methodEncryptedTransport = 'encryptedTransport';
  static const methodProxyTransport = 'proxyTransport';
  static const methodMultihopTransport = 'multihopTransport';

  TransportTestsSubcontract() : super('transport_tests');

  @override
  void setup() {
    addUnaryRequestMethod<TestMessage, TestMessage>(
      methodName: methodMemoryTransport,
      handler: memoryTransport,
      argumentParser: TestMessage.fromJson,
      responseParser: TestMessage.fromJson,
    );

    addUnaryRequestMethod<TestMessage, TestMessage>(
      methodName: methodJsonRpcTransport,
      handler: jsonRpcTransport,
      argumentParser: TestMessage.fromJson,
      responseParser: TestMessage.fromJson,
    );

    addUnaryRequestMethod<TestMessage, TestMessage>(
      methodName: methodEncryptedTransport,
      handler: encryptedTransport,
      argumentParser: TestMessage.fromJson,
      responseParser: TestMessage.fromJson,
    );

    addUnaryRequestMethod<TestMessage, TestMessage>(
      methodName: methodProxyTransport,
      handler: proxyTransport,
      argumentParser: TestMessage.fromJson,
      responseParser: TestMessage.fromJson,
    );

    addUnaryRequestMethod<TestMessage, TestMessage>(
      methodName: methodMultihopTransport,
      handler: multihopTransport,
      argumentParser: TestMessage.fromJson,
      responseParser: TestMessage.fromJson,
    );

    super.setup();
  }

  /// Тестирует транспорт через память
  Future<TestMessage> memoryTransport(TestMessage message);

  /// Тестирует транспорт через JSON-RPC
  Future<TestMessage> jsonRpcTransport(TestMessage message);

  /// Тестирует зашифрованный транспорт
  Future<TestMessage> encryptedTransport(TestMessage message);

  /// Тестирует прокси-транспорт
  Future<TestMessage> proxyTransport(TestMessage message);

  /// Тестирует многоэтапный транспорт
  Future<TestMessage> multihopTransport(TestMessage message);
}

/// Серверная реализация контракта транспортов
class TransportTestsServer extends TransportTestsSubcontract {
  @override
  Future<TestMessage> memoryTransport(TestMessage message) async {
    return TestMessage('memory_transport:${message.data}');
  }

  @override
  Future<TestMessage> jsonRpcTransport(TestMessage message) async {
    return TestMessage('json_rpc_transport:${message.data}');
  }

  @override
  Future<TestMessage> encryptedTransport(TestMessage message) async {
    return TestMessage('encrypted_transport:${message.data}');
  }

  @override
  Future<TestMessage> proxyTransport(TestMessage message) async {
    return TestMessage('proxy_transport:${message.data}');
  }

  @override
  Future<TestMessage> multihopTransport(TestMessage message) async {
    return TestMessage('multihop_transport:${message.data}');
  }
}

/// Клиентская реализация контракта транспортов
class TransportTestsClient extends TransportTestsSubcontract {
  final RpcEndpoint _endpoint;

  TransportTestsClient(this._endpoint);

  @override
  Future<TestMessage> memoryTransport(TestMessage message) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: TransportTestsSubcontract.methodMemoryTransport,
        )
        .call(
          request: message,
          responseParser: TestMessage.fromJson,
        );
  }

  @override
  Future<TestMessage> jsonRpcTransport(TestMessage message) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: TransportTestsSubcontract.methodJsonRpcTransport,
        )
        .call(
          request: message,
          responseParser: TestMessage.fromJson,
        );
  }

  @override
  Future<TestMessage> encryptedTransport(TestMessage message) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: TransportTestsSubcontract.methodEncryptedTransport,
        )
        .call(
          request: message,
          responseParser: TestMessage.fromJson,
        );
  }

  @override
  Future<TestMessage> proxyTransport(TestMessage message) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: TransportTestsSubcontract.methodProxyTransport,
        )
        .call(
          request: message,
          responseParser: TestMessage.fromJson,
        );
  }

  @override
  Future<TestMessage> multihopTransport(TestMessage message) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: TransportTestsSubcontract.methodMultihopTransport,
        )
        .call(
          request: message,
          responseParser: TestMessage.fromJson,
        );
  }
}
