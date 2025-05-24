import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:rpc_dart/logger.dart';
import 'package:rpc_dart/src_v2/rpc/_index.dart';

part 'in_memory_example.dart';
part 'isolate_example.dart';
part 'stream_types_example.dart';
part 'unary_example.dart';
// multiplex_example.dart убран - мультиплексирование теперь встроено в базовый интерфейс

/// Простой сериализатор строк для использования в примерах
class SimpleStringSerializer implements IRpcSerializer<String> {
  const SimpleStringSerializer();

  @override
  String deserialize(Uint8List bytes) {
    return utf8.decode(bytes);
  }

  @override
  Uint8List serialize(String message) {
    return Uint8List.fromList(utf8.encode(message));
  }
}

void main() async {
  await runInMemoryExample();
  await runIsolateExample();
  await runStreamTypesExample();
  await runUnaryExample();
}
