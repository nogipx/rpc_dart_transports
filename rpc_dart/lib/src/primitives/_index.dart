// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';
import 'package:rpc_dart/rpc_dart.dart';

part 'bool.dart';
part 'null.dart';
part 'num.dart';
part 'string.dart';

typedef RpcMessageProducer = String Function(String);

/// Базовый класс для всех примитивных типов сообщений
abstract class RpcPrimitiveMessage<T> implements IRpcSerializable {
  final T value;

  const RpcPrimitiveMessage(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RpcPrimitiveMessage<T> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  /// Возвращает бинарный формат сериализации
  @override
  RpcSerializationFormat getFormat() => RpcSerializationFormat.binary;

  /// Сериализует примитивное значение в чисто бинарном формате
  @override
  Uint8List serialize();

  /// Преобразует в Map для обратной совместимости
  Map<String, dynamic> toJson() => {'v': value};

  RpcException _comparisonException({
    required String type,
    required String op,
  }) =>
      RpcException(
        'Operation "$op" of $type with primitive type is prohibited. '
        'Use value for comparison.',
      );

  RpcException _unsupportedOperand({
    required String type,
    required String op,
    required Object other,
  }) =>
      RpcException(
        'Unsupported operand type: ${other.runtimeType}',
      );
}
