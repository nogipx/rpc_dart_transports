// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Обертка для строкового значения
class RpcString extends RpcPrimitiveMessage<String> {
  const RpcString(super.value);

  /// Создает RpcString из бинарных данных
  static RpcString fromBytes(Uint8List bytes) {
    return RpcString(CborCodec.decode(bytes));
  }

  /// Сериализует в бинарный формат (UTF-8 байты)
  @override
  Uint8List serialize() {
    return CborCodec.encode(value);
  }

  @override
  String toString() => value;
}
