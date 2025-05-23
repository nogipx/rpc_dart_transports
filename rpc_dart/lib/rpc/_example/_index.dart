import 'dart:convert';
import 'dart:typed_data';

import 'package:rpc_dart/logger.dart';
import 'package:rpc_dart/rpc/_index.dart';

part 'in_memory_example.dart';
part 'isolate_example.dart';
part 'stream_types_example.dart';
part 'unary_example.dart';
part 'multiplex_example.dart';

void main() async {
  // await runInMemoryExample();
  // await runIsolateExample();
  // await runStreamTypesExample();
  // await runUnaryExample();
  await runMultiplexExample();
}
