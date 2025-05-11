import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Message', () {
    test('should create message with all properties', () {
      // Arrange & Act
      final message = RpcMessage(
        type: RpcMessageType.request,
        id: '123',
        service: 'TestService',
        method: 'testMethod',
        payload: {'data': 'test'},
        metadata: {'header': 'value'},
      );

      // Assert
      expect(message.type, equals(RpcMessageType.request));
      expect(message.id, equals('123'));
      expect(message.service, equals('TestService'));
      expect(message.method, equals('testMethod'));
      expect(message.payload, equals({'data': 'test'}));
      expect(message.metadata, equals({'header': 'value'}));
    });

    test('should create message with minimum required properties', () {
      // Arrange & Act
      final message = RpcMessage(type: RpcMessageType.ping, id: 'ping-123');

      // Assert
      expect(message.type, equals(RpcMessageType.ping));
      expect(message.id, equals('ping-123'));
      expect(message.service, isNull);
      expect(message.method, isNull);
      expect(message.payload, isNull);
      expect(message.metadata, isNull);
    });

    test('should convert to and from JSON', () {
      // Arrange
      final originalMessage = RpcMessage(
        type: RpcMessageType.response,
        id: '456',
        payload: {'result': 42},
        metadata: {'server': 'test-server'},
      );

      // Act
      final json = originalMessage.toJson();
      final recreatedMessage = RpcMessage.fromJson(json);

      // Assert
      expect(recreatedMessage.type, equals(originalMessage.type));
      expect(recreatedMessage.id, equals(originalMessage.id));
      expect(recreatedMessage.service, equals(originalMessage.service));
      expect(recreatedMessage.method, equals(originalMessage.method));
      expect(recreatedMessage.payload, equals(originalMessage.payload));
      expect(recreatedMessage.metadata, equals(originalMessage.metadata));
    });

    test('should include only non-null properties in JSON', () {
      // Arrange
      final message = RpcMessage(
          type: RpcMessageType.error, id: '789', payload: 'Error message');

      // Act
      final json = message.toJson();

      // Assert
      expect(json.containsKey('type'), isTrue);
      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('payload'), isTrue);
      expect(json.containsKey('service'), isFalse);
      expect(json.containsKey('method'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('toString should return a readable representation', () {
      // Arrange
      final message = RpcMessage(
        type: RpcMessageType.request,
        id: '123',
        service: 'TestService',
        method: 'testMethod',
      );

      // Act
      final string = message.toString();

      // Assert
      expect(string, contains('type: ${RpcMessageType.request}'));
      expect(string, contains('id: 123'));
      expect(string, contains('service: TestService'));
      expect(string, contains('method: testMethod'));
    });
  });
}
