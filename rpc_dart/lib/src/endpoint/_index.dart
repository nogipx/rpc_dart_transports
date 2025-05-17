// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:rpc_dart/rpc_dart.dart';

part 'impl/method_context.dart';
part 'impl/rpc_engine.dart';
part 'impl/rpc_endpoint_registry_impl.dart';
part 'impl/rpc_method_registry.dart';

part 'interfaces/i_rpc_engine.dart';
part 'interfaces/i_rpc_endpoint.dart';
part 'interfaces/i_rpc_method_registry.dart';

part 'rpc_endpoint.dart';

final _random = Random();
String _defaultUniqueIdGenerator([String? prefix]) {
  // Текущее время в миллисекундах + случайное число
  return '${prefix != null ? '${prefix}_' : ''}${DateTime.now().toUtc().toIso8601String()}_${_random.nextInt(1000000)}';
}

typedef RpcUniqueIdGenerator = String Function([String? prefix]);
