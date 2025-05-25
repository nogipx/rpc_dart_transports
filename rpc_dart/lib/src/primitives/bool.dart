// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Обертка для булевого значения
class RpcBool extends RpcPrimitiveMessage<bool> {
  /// Создает новый объект RpcBool
  ///
  /// [value] - булево значение, которое будет храниться в объекте
  ///
  /// RpcBool используется для представления булевых значений в контексте RPC
  /// и обеспечивает единообразную сериализацию/десериализацию таких значений
  /// в различных форматах.
  const RpcBool(super.value);

  /// Создает RpcBool из бинарных данных
  static RpcBool fromBytes(Uint8List bytes) {
    return CborCodec.decode(bytes);
  }

  /// Сериализует в бинарный формат (1 байт: 1 или 0)
  @override
  Uint8List serialize() {
    return CborCodec.encode(value);
  }

  @override
  String toString() => value.toString();
}
