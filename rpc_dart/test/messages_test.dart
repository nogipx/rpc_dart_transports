import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Message', () {
    test('should create message with all properties', () {
      // Arrange & Act
      final message = RpcMessage(
        type: RpcMessageType.request,
        messageId: '123',
        serviceName: 'TestService',
        methodName: 'testMethod',
        payload: {'data': 'test'},
        headerMetadata: {'header': 'value'},
      );

      // Assert
      expect(message.type, equals(RpcMessageType.request));
      expect(message.messageId, equals('123'));
      expect(message.serviceName, equals('TestService'));
      expect(message.methodName, equals('testMethod'));
      expect(message.payload, equals({'data': 'test'}));
      expect(message.headerMetadata, equals({'header': 'value'}));
    });

    test('should create message with minimum required properties', () {
      // Arrange & Act
      final message =
          RpcMessage(type: RpcMessageType.ping, messageId: 'ping-123');

      // Assert
      expect(message.type, equals(RpcMessageType.ping));
      expect(message.messageId, equals('ping-123'));
      expect(message.serviceName, isNull);
      expect(message.methodName, isNull);
      expect(message.payload, isNull);
      expect(message.headerMetadata, isNull);
    });

    test('should convert to and from JSON', () {
      // Arrange
      final originalMessage = RpcMessage(
        type: RpcMessageType.response,
        messageId: '456',
        payload: {'result': 42},
        headerMetadata: {'server': 'test-server'},
      );

      // Act
      final json = originalMessage.toJson();
      final recreatedMessage = RpcMessage.fromJson(json);

      // Assert
      expect(recreatedMessage.type, equals(originalMessage.type));
      expect(recreatedMessage.messageId, equals(originalMessage.messageId));
      expect(recreatedMessage.payload, equals(originalMessage.payload));
      expect(recreatedMessage.headerMetadata,
          equals(originalMessage.headerMetadata));
    });

    test('should include only non-null properties in JSON', () {
      // Arrange
      final message = RpcMessage(
          type: RpcMessageType.error,
          messageId: '789',
          payload: 'Error message');

      // Act
      final json = message.toJson();

      // Assert
      expect(json.containsKey('type'), isTrue);
      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('payload'), isTrue);
      expect(json.containsKey('serviceName'), isFalse);
      expect(json.containsKey('methodName'), isFalse);
      expect(json.containsKey('headerMetadata'), isFalse);
    });
  });
}
