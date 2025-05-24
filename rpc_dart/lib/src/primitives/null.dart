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

  @override
  Map<String, dynamic> toJson() => {'v': null};

  @override
  String toString() => toJson().toString();
}
