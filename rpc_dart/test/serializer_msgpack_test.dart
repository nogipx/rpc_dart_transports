import 'dart:typed_data';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Тестовый класс, реализующий IRpcSerializableMessage
class TestMessage extends IRpcSerializableMessage {
  final int id;
  final String name;
  final bool active;

  TestMessage({
    required this.id,
    required this.name,
    this.active = true,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'active': active,
    };
  }

  factory TestMessage.fromJson(Map<String, dynamic> json) {
    return TestMessage(
      id: json['id'] as int,
      name: json['name'] as String,
      active: json['active'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          active == other.active;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ active.hashCode;
}

// Обычный класс с методом toJson, но без интерфейса
class RegularObject {
  final double value;
  final String text;

  RegularObject(this.value, this.text);

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'text': text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegularObject &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          text == other.text;

  @override
  int get hashCode => value.hashCode ^ text.hashCode;
}

void main() {
  group('MsgPackSerializer', () {
    late MsgPackSerializer serializer;

    setUp(() {
      serializer = const MsgPackSerializer();
    });

    test('должен сериализовать и десериализовать примитивные типы', () {
      // Целые числа
      final intValue = 42;
      final serializedInt = serializer.serialize(intValue);
      final deserializedInt = serializer.deserialize(serializedInt);
      expect(deserializedInt, equals(intValue));

      // Строки
      final stringValue = 'Hello, MessagePack!';
      final serializedString = serializer.serialize(stringValue);
      final deserializedString = serializer.deserialize(serializedString);
      expect(deserializedString, equals(stringValue));

      // Булевы значения
      final boolValue = true;
      final serializedBool = serializer.serialize(boolValue);
      final deserializedBool = serializer.deserialize(serializedBool);
      expect(deserializedBool, equals(boolValue));

      // Числа с плавающей точкой
      final doubleValue = 3.14159;
      final serializedDouble = serializer.serialize(doubleValue);
      final deserializedDouble = serializer.deserialize(serializedDouble);
      expect(deserializedDouble, equals(doubleValue));

      // null
      final nullValue = null;
      final serializedNull = serializer.serialize(nullValue);
      final deserializedNull = serializer.deserialize(serializedNull);
      expect(deserializedNull, equals(nullValue));
    });

    test('должен сериализовать и десериализовать коллекции', () {
      // Списки
      final listValue = [1, 2, 3, 'four', 5.0, true];
      final serializedList = serializer.serialize(listValue);
      final deserializedList = serializer.deserialize(serializedList);
      expect(deserializedList, equals(listValue));

      // Карты
      final mapValue = {
        'int': 42,
        'string': 'hello',
        'double': 3.14,
        'bool': true,
        'list': [1, 2, 3],
        'map': {'nested': 'value'}
      };
      final serializedMap = serializer.serialize(mapValue);
      final deserializedMap = serializer.deserialize(serializedMap);
      expect(deserializedMap, equals(mapValue));
    });

    test('должен сериализовать и десериализовать бинарные данные', () {
      final binaryData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final serializedBinary = serializer.serialize(binaryData);
      final deserializedBinary = serializer.deserialize(serializedBinary);

      expect(deserializedBinary, isA<Uint8List>());
      expect(deserializedBinary.length, equals(binaryData.length));

      for (int i = 0; i < binaryData.length; i++) {
        expect(deserializedBinary[i], equals(binaryData[i]));
      }
    });

    test('должен сериализовать IRpcSerializableMessage через toJson', () {
      final message = TestMessage(id: 123, name: 'test message');
      final serialized = serializer.serialize(message);
      final deserialized = serializer.deserialize(serialized);

      expect(deserialized, isA<Map>());
      expect(deserialized['id'], equals(123));
      expect(deserialized['name'], equals('test message'));
      expect(deserialized['active'], isTrue);
    });

    test('должен сериализовать обычный класс с методом toJson', () {
      final object = RegularObject(3.14, 'text value');
      final serialized = serializer.serialize(object);
      final deserialized = serializer.deserialize(serialized);

      expect(deserialized, isA<Map>());
      expect(deserialized['value'], equals(3.14));
      expect(deserialized['text'], equals('text value'));
    });
  });
}
