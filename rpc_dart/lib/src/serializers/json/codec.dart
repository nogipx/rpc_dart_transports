part of '../_index.dart';

/// JSON сериализатор - конвертирует через JSON для удобства
/// Для моделей, которые уже имеют toJson/fromJson
class RpcJsonCodec<T extends IRpcSerializable> implements IRpcCodec<T> {
  final T Function(Map<String, dynamic>) _fromJson;

  @override
  RpcCodecType get format => RpcCodecType.json;

  /// Создает JSON сериализатор
  /// [fromJson] - функция для создания объекта из JSON (например, MyModel.fromJson)
  RpcJsonCodec(this._fromJson);

  @override
  Uint8List serialize(T message) {
    // Используем встроенную сериализацию через JSON
    return (message as IRpcSerializable).serialize();
  }

  @override
  T deserialize(Uint8List bytes) {
    // Используем статический хелпер из миксина
    return RpcJsonSerializable.fromBytes<T>(bytes, _fromJson);
  }
}
