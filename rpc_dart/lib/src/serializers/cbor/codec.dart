part of '../_index.dart';

/// CBOR сериализатор для RPC сообщений
class RpcCborCodec<T extends IRpcSerializable> implements IRpcCodec<T> {
  RpcLogger get _logger => RpcLogger('RpcCborCodec');

  final T Function(Map<String, dynamic>) _fromCbor;

  @override
  RpcCodecType get format => RpcCodecType.cbor;

  /// Создает CBOR сериализатор
  /// [fromCbor] - функция для создания объекта из CBOR Map
  RpcCborCodec(this._fromCbor);

  @override
  Uint8List serialize(T message) {
    // Если объект поддерживает CBOR сериализацию
    if (message is CborRpcSerializable) {
      return message.serialize();
    }

    try {
      final json = (message as dynamic).toJson();
      return CborCodec.encode(json);
    } on NoSuchMethodError catch (_) {
      _logger.warning('Метод toJson() не найден.');
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
