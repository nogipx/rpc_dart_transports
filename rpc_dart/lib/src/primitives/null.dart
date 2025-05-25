// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Обертка для null
class RpcNull extends RpcPrimitiveMessage<void> {
  const RpcNull() : super(null);

  /// Создает RpcNull из JSON (в любом случае возвращает RpcNull)
  factory RpcNull.fromJson(Map<String, dynamic> json) {
    return const RpcNull();
  }

  /// Создает RpcNull из бинарных данных
  static RpcNull fromBytes(Uint8List bytes) {
    return const RpcNull();
  }

  /// Сериализует в бинарный формат (пустой массив)
  @override
  Uint8List serialize() {
    return Uint8List(0); // Пустой массив для null
  }

  @override
  String toString() => null.toString();
}
