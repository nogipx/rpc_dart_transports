import 'dart:convert';
import 'package:rpc_dart/rpc_dart.dart';
import 'cbor/cbor.dart';

part 'cbor/mixin.dart';
part 'cbor/codec.dart';

part 'json/mixin.dart';
part 'json/codec.dart';

part 'protobuf/mixin.dart';
part 'protobuf/codec.dart';

/// Формат сериализации для RPC сообщений
enum RpcCodecType {
  /// JSON формат (через utf8)
  json,

  /// Бинарный формат (включая protobuf, msgpack и т.д.)
  binary,

  /// CBOR формат (Concise Binary Object Representation)
  cbor
}

/// Основной интерфейс для всех RPC сообщений - работает с байтами
/// Все типы запросов и ответов должны реализовывать этот интерфейс
/// Это базовый интерфейс для binary сериализации (protobuf, msgpack, etc.)
abstract interface class IRpcSerializable {
  /// Возвращает формат сериализации (по умолчанию JSON для обратной совместимости)
  RpcCodecType get codec => RpcCodecType.json;

  /// Сериализует объект в байты
  Uint8List serialize();

  /// Десериализует объект из байтов - должен быть статическим методом
  /// static T fromBytes(Uint8List bytes);
}

/// Интерфейс для кодирования и декодирования сообщений.
///
/// Позволяет абстрагироваться от конкретного формата сериализации (JSON, Protocol Buffers,
/// MessagePack и др.). Реализации должны обеспечивать корректное преобразование объектов
/// в байты и обратно.
abstract class IRpcCodec<T> {
  /// Сериализует объект типа T в последовательность байтов.
  ///
  /// [message] Объект для сериализации.
  /// Возвращает байтовое представление объекта.
  Uint8List serialize(T message);

  /// Десериализует последовательность байтов в объект типа T.
  ///
  /// [bytes] Байты для десериализации.
  /// Возвращает объект, воссозданный из байтов.
  T deserialize(Uint8List bytes);

  RpcCodecType get format;
}
