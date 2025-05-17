// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../test_contract.dart';

/// Контракт для тестирования сериализации
abstract class SerializationTestsSubcontract extends RpcServiceContract {
  // Константы для имен методов
  static const methodJsonSerialization = 'jsonSerialization';
  static const methodMsgPackSerialization = 'msgPackSerialization';
  static const methodCustomSerialization = 'customSerialization';
  static const methodComplexObject = 'complexObject';

  SerializationTestsSubcontract() : super('serialization_tests');

  @override
  void setup() {
    addUnaryRequestMethod<TestMessage, TestMessage>(
      methodName: methodJsonSerialization,
      handler: jsonSerialization,
      argumentParser: TestMessage.fromJson,
      responseParser: TestMessage.fromJson,
    );

    addUnaryRequestMethod<TestMessage, TestMessage>(
      methodName: methodMsgPackSerialization,
      handler: msgPackSerialization,
      argumentParser: TestMessage.fromJson,
      responseParser: TestMessage.fromJson,
    );

    addUnaryRequestMethod<TestMessage, TestMessage>(
      methodName: methodCustomSerialization,
      handler: customSerialization,
      argumentParser: TestMessage.fromJson,
      responseParser: TestMessage.fromJson,
    );

    addUnaryRequestMethod<TestMessage, TestMessage>(
      methodName: methodComplexObject,
      handler: complexObject,
      argumentParser: TestMessage.fromJson,
      responseParser: TestMessage.fromJson,
    );

    super.setup();
  }

  /// Тестирует JSON сериализацию
  Future<TestMessage> jsonSerialization(TestMessage message);

  /// Тестирует MsgPack сериализацию
  Future<TestMessage> msgPackSerialization(TestMessage message);

  /// Тестирует пользовательскую сериализацию
  Future<TestMessage> customSerialization(TestMessage message);

  /// Тестирует сериализацию сложных объектов
  Future<TestMessage> complexObject(TestMessage message);
}

/// Серверная реализация контракта сериализации
class SerializationTestsServer extends SerializationTestsSubcontract {
  @override
  Future<TestMessage> jsonSerialization(TestMessage message) async {
    return TestMessage('json_serialization:${message.data}');
  }

  @override
  Future<TestMessage> msgPackSerialization(TestMessage message) async {
    return TestMessage('msgpack_serialization:${message.data}');
  }

  @override
  Future<TestMessage> customSerialization(TestMessage message) async {
    return TestMessage('custom_serialization:${message.data}');
  }

  @override
  Future<TestMessage> complexObject(TestMessage message) async {
    // Имитация обработки сложного объекта
    // В реальном сценарии здесь могла бы быть обработка JSON-структуры
    return TestMessage('complex_object_processed:${message.data}');
  }
}

/// Клиентская реализация контракта сериализации
class SerializationTestsClient extends SerializationTestsSubcontract {
  final RpcEndpoint _endpoint;

  SerializationTestsClient(this._endpoint);

  @override
  Future<TestMessage> jsonSerialization(TestMessage message) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: SerializationTestsSubcontract.methodJsonSerialization,
        )
        .call(
          request: message,
          responseParser: TestMessage.fromJson,
        );
  }

  @override
  Future<TestMessage> msgPackSerialization(TestMessage message) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: SerializationTestsSubcontract.methodMsgPackSerialization,
        )
        .call(
          request: message,
          responseParser: TestMessage.fromJson,
        );
  }

  @override
  Future<TestMessage> customSerialization(TestMessage message) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: SerializationTestsSubcontract.methodCustomSerialization,
        )
        .call(
          request: message,
          responseParser: TestMessage.fromJson,
        );
  }

  @override
  Future<TestMessage> complexObject(TestMessage message) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: SerializationTestsSubcontract.methodComplexObject,
        )
        .call(
          request: message,
          responseParser: TestMessage.fromJson,
        );
  }
}
