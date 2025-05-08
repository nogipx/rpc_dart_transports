import 'dart:convert';
import 'dart:typed_data';
import 'serializer.dart';

/// Реализация сериализатора, использующего JSON
class JsonSerializer implements RpcSerializer {
  const JsonSerializer();

  /// Стандартный кодек JSON
  static final JsonCodec _jsonCodec = const JsonCodec();

  /// Кодек для кодирования/декодирования UTF-8
  static final Utf8Codec _utf8Codec = const Utf8Codec();

  @override
  Uint8List serialize(dynamic message) {
    final jsonString = _jsonCodec.encode(message);
    return Uint8List.fromList(_utf8Codec.encode(jsonString));
  }

  @override
  dynamic deserialize(Uint8List data) {
    final jsonString = _utf8Codec.decode(data);
    return _jsonCodec.decode(jsonString);
  }
}
