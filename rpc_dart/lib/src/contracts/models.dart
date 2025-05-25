part of '_index.dart';

/// Миксин для автоматической сериализации JSON -> байты
/// Позволяет разработчикам использовать привычные toJson/fromJson методы
/// и автоматически получать binary сериализацию через JSON
mixin _JsonRpcSerializable on IRpcJsonSerializable implements IRpcSerializable {
  @override
  Uint8List serialize() {
    final json = toJson();
    final jsonString = jsonEncode(json);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Переопределяем метод для указания формата сериализации
  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

  /// Статический хелпер для десериализации из байтов через JSON
  static T fromBytes<T extends IRpcJsonSerializable>(
    Uint8List bytes,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final jsonString = utf8.decode(bytes);
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return fromJson(json);
    } catch (e) {
      if (jsonString.startsWith('Instance of ')) {
        throw FormatException(
          'Получена строка представления объекта вместо JSON: $jsonString. '
          'Убедитесь, что объект правильно сериализуется в JSON перед отправкой.',
        );
      }
      rethrow;
    }
  }
}

/// Миксин для бинарной сериализации данных
/// Используется для прямой бинарной сериализации
mixin BinarySerializable implements IRpcSerializable {
  /// Переопределяем метод для указания формата сериализации
  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.binary;
}

/// Миксин для protobuf моделей (готовим почву для будущего)
/// Позволит использовать protobuf сериализацию
mixin ProtobufRpcSerializable implements IRpcSerializable {
  /// Конвертирует в protobuf байты - реализация будет в наследниках
  Uint8List toBuffer();

  @override
  Uint8List serialize() => toBuffer();

  /// Переопределяем метод для указания формата сериализации
  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.binary;

  /// Статический хелпер для десериализации protobuf
  static T fromBytes<T extends IRpcSerializable>(
    Uint8List bytes,
    T Function(Uint8List) fromBuffer,
  ) {
    return fromBuffer(bytes);
  }
}

/// Типы RPC методов
enum RpcMethodType {
  unary,
  serverStream,
  clientStream,
  bidirectional,
}

/// Регистрация метода в контракте
class RpcMethodRegistration {
  final String name;
  final RpcMethodType type;
  final Function handler;
  final String description;
  final dynamic Function(Uint8List) requestDeserializer;
  final Uint8List Function(dynamic)? responseSerializer;

  const RpcMethodRegistration({
    required this.name,
    required this.type,
    required this.handler,
    required this.description,
    required this.requestDeserializer,
    this.responseSerializer,
  });
}

/// Исключение для RpcEndpoint
class RpcException implements Exception {
  final String message;

  RpcException(this.message);

  @override
  String toString() => 'RpcException: $message';
}

/// Интерфейс для middleware
abstract class IRpcMiddleware {
  Future<dynamic> processRequest(
    String serviceName,
    String methodName,
    dynamic request,
  );

  Future<dynamic> processResponse(
    String serviceName,
    String methodName,
    dynamic response,
  );
}
