// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Обертка для строкового значения
class RpcString extends RpcPrimitiveMessage<String> {
  const RpcString(super.value);

  /// Создает RpcString из JSON
  factory RpcString.fromJson(Map<String, dynamic> json) {
    try {
      final v = json['v'];
      if (v == null) return const RpcString('');
      if (v is String) return RpcString(v);
      return RpcString(v.toString());
    } catch (e) {
      return const RpcString('');
    }
  }

  /// Создает RpcString из бинарных данных
  static RpcString fromBytes(Uint8List bytes) {
    return RpcString(CborCodec.decode(bytes));
  }

  @override
  String toString() => value;
}
