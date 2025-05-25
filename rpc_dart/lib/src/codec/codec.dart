part of '_index.dart';

/// CBOR сериализатор для RPC сообщений
class RpcCodec<T extends IRpcSerializable> implements IRpcCodec<T> {
  final T Function(Map<String, dynamic> json)? _fromJson;

  /// Создает CBOR сериализатор
  /// [fromCbor] - функция для создания объекта из CBOR Map
  RpcCodec(this._fromJson);

  @override
  Uint8List serialize(T message) {
    return CborCodec.encode(message.toJson());
  }

  @override
  T deserialize(Uint8List bytes) {
    final decoded = CborCodec.decode(bytes);
    final json = (decoded as Map<dynamic, dynamic>).cast<String, dynamic>();

    return _fromJson!(json);
  }

  /// Статический хелпер для десериализации CBOR
  static T fromBytes<T extends IRpcSerializable>({
    required Uint8List bytes,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    final decoded = CborCodec.decode(bytes);
    if (decoded is! Map<dynamic, dynamic>) {
      throw FormatException(
        'Expected Map from CBOR, got ${decoded.runtimeType}',
      );
    }

    // Преобразуем ключи в строки
    final Map<String, dynamic> cborMap = {};
    decoded.forEach((key, value) {
      cborMap[key.toString()] = value;
    });

    return fromJson(cborMap);
  }
}
