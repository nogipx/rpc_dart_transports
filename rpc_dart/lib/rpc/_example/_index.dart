import 'dart:convert';
import 'dart:typed_data';

import 'package:rpc_dart/logger.dart';
import 'package:rpc_dart/rpc/_index.dart';

part 'in_memory_example.dart';
part 'isolate_example.dart';
part 'stream_types_example.dart';

void main() async {
  // Запускаем все примеры
  await runStreamTypesExample();
}
