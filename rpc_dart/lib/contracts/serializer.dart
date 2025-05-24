part of '_index.dart';

/// Сериализатор с автоматическим envelope
class RpcSerializer<T extends IRpcSerializableMessage>
    implements IRpcSerializer<T> {
  final T Function(Map<String, dynamic>) _fromJson;

  RpcSerializer({
    required T Function(Map<String, dynamic>) fromJson,
  }) : _fromJson = fromJson;

  @override
  Uint8List serialize(T message) {
    final messageJson = message.toJson();
    final jsonString = jsonEncode(messageJson);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  @override
  T deserialize(Uint8List bytes) {
    final jsonString = utf8.decode(bytes);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    if (json.containsKey('payload')) {
      return _fromJson(json['payload']);
    } else {
      return _fromJson(json);
    }
  }
}
