part of '../_index.dart';

/// Миксин для CBOR сериализации
mixin CborRpcSerializable implements IRpcSerializable {
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
  RpcCodecType codec() => RpcCodecType.cbor;

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
