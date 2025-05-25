part of '../_index.dart';

/// Миксин для CBOR сериализации
mixin CborRpcSerializable implements IRpcSerializable, IRpcJsonSerializable {
  /// Преобразует объект в Map для CBOR сериализации
  /// Необходимо реализовать в наследниках
  Map<String, dynamic> toCbor();

  @override
  Uint8List serialize() {
    // Сериализуем через CBOR
    return CborCodec.encode(toCbor());
  }

  /// Переопределяем метод для указания формата сериализации
  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.cbor;

  /// Статический хелпер для десериализации CBOR
  static T fromBytes<T extends IRpcSerializable>(
    Uint8List bytes,
    T Function(Map<String, dynamic>) fromCbor,
  ) {
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

    return fromCbor(cborMap);
  }
}

/// CBOR сериализатор для RPC сообщений
class RpcCborSerializer<T extends IRpcSerializable>
    implements IRpcSerializer<T> {
  final T Function(Map<String, dynamic>) _fromCbor;

  @override
  RpcSerializationFormat get format => RpcSerializationFormat.cbor;

  /// Создает CBOR сериализатор
  /// [fromCbor] - функция для создания объекта из CBOR Map
  RpcCborSerializer(this._fromCbor);

  @override
  Uint8List serialize(T message) {
    // Если объект поддерживает CBOR сериализацию
    if (message is CborRpcSerializable) {
      return message.serialize();
    }

    // Если объект поддерживает JSON сериализацию
    if (message is IRpcJsonSerializable) {
      return CborCodec.encode((message as IRpcJsonSerializable).toJson());
    }

    // Иначе используем обычную бинарную сериализацию
    return message.serialize();
  }

  @override
  T deserialize(Uint8List bytes) {
    // Используем миксин для десериализации
    return CborRpcSerializable.fromBytes<T>(bytes, _fromCbor);
  }
}
