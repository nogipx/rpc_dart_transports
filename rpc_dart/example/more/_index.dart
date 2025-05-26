// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/src/_index.dart';

part 'in_memory_example.dart';
part 'isolate_example.dart';
part 'stream_types_example.dart';
part 'unary_example.dart';

void main() async {
  // await runInMemoryExample();
  await runIsolateExample();
  // await runStreamTypesExample();
  // await runUnaryExample();
}
