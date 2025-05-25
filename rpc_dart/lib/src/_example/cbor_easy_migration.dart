import 'dart:convert';
import 'dart:typed_data';
import '../contracts/_index.dart';

/// Пример простой миграции с JSON на CBOR
void main() {
  print('Демонстрация простой миграции с JSON на CBOR');
  print('=============================================');

  // Создаем пример существующей модели
  final user = User(
    id: 12345,
    name: 'Иван Петров',
    email: 'ivan@example.com',
    isActive: true,
    tags: ['admin', 'developer'],
    metadata: {
      'lastLogin': '2023-06-15',
      'preferences': {
        'theme': 'dark',
        'notifications': true,
      }
    },
  );

  // Сериализуем в JSON
  final jsonBytes = user.serialize();
  final jsonString = utf8.decode(jsonBytes);

  print('JSON (${jsonBytes.length} байт):');
  print(jsonString);

  // Создаем JSON сериализатор
  final jsonSerializer = RpcJsonSerializer<User>(User.fromJson);

  // 1. Используем extension метод для быстрой сериализации в CBOR
  final cborBytes1 = user.toCborBytes();
  print('\nCBOR через extension (${cborBytes1.length} байт):');

  // 2. Используем автоматический конвертер для создания CBOR сериализатора
  final cborSerializer = CborConverter.fromJsonFactory<User>(User.fromJson);
  final cborBytes2 = cborSerializer.serialize(user);
  print('CBOR через конвертер (${cborBytes2.length} байт):');

  // 3. Конвертируем существующий JSON сериализатор в CBOR
  final cborSerializer2 = CborConverter.fromJsonSerializer(jsonSerializer);
  final cborBytes3 = cborSerializer2.serialize(user);
  print(
      'CBOR через конвертированный сериализатор (${cborBytes3.length} байт):');

  // Сравниваем размеры
  final jsonSize = jsonBytes.length;
  final cborSize = cborBytes1.length;
  final savings = jsonSize - cborSize;
  final percentage = (savings / jsonSize * 100).toStringAsFixed(2);

  print('\nCBOR сэкономил $savings байт ($percentage% от JSON)');

  // Десериализуем обратно
  final deserializedUser = cborSerializer.deserialize(cborBytes2);

  print('\nУспешно десериализовано:');
  print('ID: ${deserializedUser.id}');
  print('Имя: ${deserializedUser.name}');
  print('Email: ${deserializedUser.email}');
  print('Активен: ${deserializedUser.isActive}');
  print('Теги: ${deserializedUser.tags.join(', ')}');
  print('Метаданные: ${deserializedUser.metadata}');

  // Демонстрация обновления существующей модели с JsonToCborSerializable
  final enhancedUser = EnhancedUser(
    id: 12345,
    name: 'Иван Петров',
    email: 'ivan@example.com',
    isActive: true,
    tags: ['admin', 'developer'],
    metadata: {
      'lastLogin': '2023-06-15',
      'preferences': {
        'theme': 'dark',
        'notifications': true,
      }
    },
  );

  // EnhancedUser автоматически поддерживает и JSON, и CBOR
  print('\nEnhancedUser с автоматической поддержкой CBOR:');
  print('Формат: ${enhancedUser.getFormat().name}');
  final enhancedBytes = enhancedUser.serialize();
  print('Размер: ${enhancedBytes.length} байт');
}

/// Существующая модель с поддержкой JSON
class User implements IRpcJsonSerializable, IRpcSerializable {
  final int id;
  final String name;
  final String email;
  final bool isActive;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
    required this.tags,
    required this.metadata,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'isActive': isActive,
        'tags': tags,
        'metadata': metadata,
      };

  @override
  Uint8List serialize() {
    final jsonString = jsonEncode(toJson());
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  static User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      isActive: json['isActive'] as bool,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }
}

/// Улучшенная модель с поддержкой и JSON, и CBOR
class EnhancedUser
    with JsonToCborSerializable
    implements IRpcJsonSerializable, IRpcSerializable {
  final int id;
  final String name;
  final String email;
  final bool isActive;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  EnhancedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
    required this.tags,
    required this.metadata,
  });

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'isActive': isActive,
        'tags': tags,
        'metadata': metadata,
      };

  @override
  Uint8List serialize() {
    // Автоматически используем правильный формат
    if (getFormat() == RpcSerializationFormat.cbor) {
      return toCborBytes(); // Использует extension метод
    } else {
      final jsonString = jsonEncode(toJson());
      return Uint8List.fromList(utf8.encode(jsonString));
    }
  }

  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.cbor;

  static EnhancedUser fromJson(Map<String, dynamic> json) {
    return EnhancedUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      isActive: json['isActive'] as bool,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }
}
