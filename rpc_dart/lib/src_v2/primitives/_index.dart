// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

part 'bool.dart';
part 'null.dart';
part 'num.dart';
part 'string.dart';

typedef RpcMessageProducer = String Function(String);

/// Базовый класс для всех примитивных типов сообщений
abstract class RpcPrimitiveMessage<T> extends IRpcSerializableMessage {
  final T value;

  const RpcPrimitiveMessage(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RpcPrimitiveMessage<T> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  RpcUnsupportedOperationException _comparisonException({
    required String type,
    required String op,
  }) =>
      RpcUnsupportedOperationException(
        operation: op,
        type: type,
        details: {
          'hint': 'Operation "$op" of $type with primitive type is prohibited. '
              'Use value for comparison.',
        },
      );

  RpcUnsupportedOperationException _unsupportedOperand({
    required String type,
    required String op,
    required Object other,
  }) =>
      // throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
      RpcUnsupportedOperationException(
        type: type,
        operation: op,
        details: {
          'hint': 'Unsupported operand type: ${other.runtimeType}',
        },
      );
}
