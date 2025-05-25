part of '_index.dart';

/// Базовый binary сериализатор - работает напрямую с байтами
/// Для protobuf, msgpack и других binary форматов
class RpcBinarySerializer<T extends IRpcSerializable>
    implements IRpcSerializer<T> {
  final T Function(Uint8List) _fromBytes;

  @override
  RpcSerializationFormat get format => RpcSerializationFormat.binary;

  /// Создает binary сериализатор
  /// [fromBytes] - функция для десериализации из байтов (например, MyModel.fromBuffer)
  RpcBinarySerializer(this._fromBytes);

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

  @override
  RpcSerializationFormat get format => RpcSerializationFormat.json;

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
    return _JsonRpcSerializable.fromBytes<T>(bytes, _fromJson);
  }
}

/// Сериализатор, который просто передает данные как есть без преобразования
class RpcPassthroughSerializer<T> implements IRpcSerializer<T> {
  const RpcPassthroughSerializer();

  T fromBytes(Uint8List bytes) => utf8.decode(bytes) as T;

  Uint8List toBytes(T data) => utf8.encode(data.toString());

  @override
  T deserialize(Uint8List data) => fromBytes(data);

  @override
  Uint8List serialize(T data) => toBytes(data);

  @override
  RpcSerializationFormat get format => RpcSerializationFormat.binary;
}
