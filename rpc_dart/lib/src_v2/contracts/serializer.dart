part of '_index.dart';

/// Базовый binary сериализатор - работает напрямую с байтами
/// Для protobuf, msgpack и других binary форматов
class RpcBinarySerializer<T extends IRpcSerializable>
    implements IRpcSerializer<T> {
  final T Function(Uint8List) _fromBytes;

  /// Создает binary сериализатор
  /// [fromBytes] - функция для десериализации из байтов (например, MyModel.fromBuffer)
  RpcBinarySerializer({
    required T Function(Uint8List) fromBytes,
  }) : _fromBytes = fromBytes;

  @override
  Uint8List serialize(T message) {
    // Просто вызываем serialize() - модель сама знает как себя сериализовать
    return message.serialize();
  }

  @override
  T deserialize(Uint8List bytes) {
    return _fromBytes(bytes);
  }
}

/// JSON сериализатор - конвертирует через JSON для удобства
/// Для моделей, которые уже имеют toJson/fromJson
class RpcJsonSerializer<T extends IRpcJsonSerializable>
    implements IRpcSerializer<T> {
  final T Function(Map<String, dynamic>) _fromJson;

  /// Создает JSON сериализатор
  /// [fromJson] - функция для создания объекта из JSON (например, MyModel.fromJson)
  RpcJsonSerializer(this._fromJson);

  @override
  Uint8List serialize(T message) {
    // Используем встроенную сериализацию через JSON
    return (message as IRpcSerializable).serialize();
  }

  @override
  T deserialize(Uint8List bytes) {
    // Используем статический хелпер из миксина
    return JsonRpcSerializable.fromBytes<T>(bytes, _fromJson);
  }
}

/// Фабрика для создания сериализаторов
/// Упрощает создание правильного типа сериализатора
class RpcSerializerFactory {
  /// Создает JSON сериализатор для модели с toJson/fromJson
  static RpcJsonSerializer<T> json<T extends IRpcJsonSerializable>(
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return RpcJsonSerializer<T>(fromJson);
  }

  /// Создает binary сериализатор для protobuf, msgpack и других binary форматов
  static RpcBinarySerializer<T> binary<T extends IRpcSerializable>(
    T Function(Uint8List) fromBytes,
  ) {
    return RpcBinarySerializer<T>(fromBytes: fromBytes);
  }

  /// Создает protobuf сериализатор (специализированный binary)
  static RpcBinarySerializer<T> protobuf<T extends IRpcSerializable>(
    T Function(Uint8List) fromBuffer,
  ) {
    return RpcBinarySerializer<T>(fromBytes: fromBuffer);
  }
}
