// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Обертка для null
class RpcNull extends RpcPrimitiveMessage<void> {
  const RpcNull() : super(null);

  /// Создает RpcNull из бинарных данных
  static RpcNull fromBytes(Uint8List bytes) {
    return CborCodec.decode(bytes);
  }

  /// Сериализует в бинарный формат (пустой массив)
  @override
  Uint8List serialize() {
    return CborCodec.encode(null);
  }

  @override
  String toString() => null.toString();
}
