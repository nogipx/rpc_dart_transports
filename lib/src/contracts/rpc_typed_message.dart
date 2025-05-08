/// Интерфейс для типизированных сообщений
abstract interface class RpcSerializableMessage {
  /// Преобразует сообщение в JSON
  Map<String, dynamic> toJson();
}
