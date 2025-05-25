import 'dart:typed_data';
export 'cbor/cbor.dart';

/// Формат сериализации для RPC сообщений
enum RpcSerializationFormat {
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
  /// Сериализует объект в байты
  Uint8List serialize();

  /// Возвращает формат сериализации (по умолчанию JSON для обратной совместимости)
  RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

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
