import 'dart:typed_data';

/// Абстракция для сериализации/десериализации сообщений
abstract interface class RpcSerializer {
  const RpcSerializer();

  /// Сериализует объект в бинарные данные
  ///
  /// [message] - объект для сериализации
  /// Возвращает сериализованные данные как Uint8List
  Uint8List serialize(dynamic message);

  /// Десериализует бинарные данные в объект
  ///
  /// [data] - данные для десериализации
  /// Возвращает десериализованный объект
  dynamic deserialize(Uint8List data);
}
