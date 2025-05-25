part of '../_index.dart';

/// Миксин для protobuf моделей (готовим почву для будущего)
/// Позволит использовать protobuf сериализацию
mixin ProtobufRpcSerializable implements IRpcSerializable {
  /// Конвертирует в protobuf байты - реализация будет в наследниках
  Uint8List toBuffer();

  @override
  Uint8List serialize() => toBuffer();

  /// Переопределяем метод для указания формата сериализации
  @override
  RpcCodecType get codec => RpcCodecType.binary;

  /// Статический хелпер для десериализации protobuf
  static T fromBytes<T extends IRpcSerializable>(
    Uint8List bytes,
    T Function(Uint8List) fromBuffer,
  ) {
    return fromBuffer(bytes);
  }
}
