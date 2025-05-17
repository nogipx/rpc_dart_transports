import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  late JsonSerializer serializer;

  setUp(() {
    serializer = JsonSerializer();
  });

  group('JsonSerializer', () {
    test('should serialize and deserialize primitive types', () {
      // Arrange
      const originalValue = 42;

      // Act
      final serialized = serializer.serialize(originalValue);
      final deserialized = serializer.deserialize(serialized);

      // Assert
      expect(deserialized, equals(originalValue));
    });

    test('should serialize and deserialize maps', () {
      // Arrange
      final originalValue = {'key': 'value', 'number': 42};

      // Act
      final serialized = serializer.serialize(originalValue);
      final deserialized = serializer.deserialize(serialized);

      // Assert
      expect(deserialized, equals(originalValue));
    });

    test('should serialize and deserialize lists', () {
      // Arrange
      final originalValue = [
        1,
        2,
        3,
        'string',
        {'nested': true},
      ];

      // Act
      final serialized = serializer.serialize(originalValue);
      final deserialized = serializer.deserialize(serialized);

      // Assert
      expect(deserialized, equals(originalValue));
    });

    test('should serialize and deserialize complex nested structures', () {
      // Arrange
      final originalValue = {
        'string': 'value',
        'number': 42,
        'boolean': true,
        'null': null,
        'list': [1, 2, 3],
        'nested': {
          'a': 1,
          'b': [4, 5, 6],
          'c': {'d': 'nested value'},
        },
      };

      // Act
      final serialized = serializer.serialize(originalValue);
      final deserialized = serializer.deserialize(serialized);

      // Assert
      expect(deserialized, equals(originalValue));
    });
  });
}
