part of '_index.dart';

/// Основной интерфейс для всех RPC сообщений - работает с байтами
/// Все типы запросов и ответов должны реализовывать этот интерфейс
/// Это базовый интерфейс для binary сериализации (protobuf, msgpack, etc.)
abstract interface class IRpcSerializable {
  /// Сериализует объект в байты
  Uint8List serialize();

  /// Десериализует объект из байтов - должен быть статическим методом
  /// static T fromBytes(Uint8List bytes);
}

/// Интерфейс для моделей, которые могут конвертироваться в JSON
/// Более удобный интерфейс для пользовательских моделей
abstract interface class IRpcJsonSerializable {
  /// Конвертирует модель в JSON Map
  Map<String, dynamic> toJson();

  /// Создает модель из JSON Map - должен быть статическим методом
  /// static T fromJson(Map<String, dynamic> json);
}

/// Миксин для автоматической сериализации JSON -> байты
/// Позволяет разработчикам использовать привычные toJson/fromJson методы
/// и автоматически получать binary сериализацию через JSON
mixin JsonRpcSerializable on IRpcJsonSerializable implements IRpcSerializable {
  @override
  Uint8List serialize() {
    final json = toJson();
    final jsonString = jsonEncode(json);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Статический хелпер для десериализации из байтов через JSON
  static T fromBytes<T extends IRpcJsonSerializable>(
    Uint8List bytes,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final jsonString = utf8.decode(bytes);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return fromJson(json);
  }
}

/// Миксин для protobuf моделей (готовим почву для будущего)
/// Позволит использовать protobuf сериализацию
mixin ProtobufRpcSerializable implements IRpcSerializable {
  /// Конвертирует в protobuf байты - реализация будет в наследниках
  Uint8List toBuffer();

  @override
  Uint8List serialize() => toBuffer();

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
  final Type requestType;
  final Type responseType;

  const RpcMethodRegistration({
    required this.name,
    required this.type,
    required this.handler,
    required this.description,
    required this.requestType,
    required this.responseType,
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
