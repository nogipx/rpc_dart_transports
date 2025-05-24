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

  /// Создает RpcBool из JSON
  factory RpcBool.fromJson(Map<String, dynamic> json) {
    try {
      final v = json['v'];
      if (v == null) return const RpcBool(false);
      if (v is bool) return RpcBool(v);

      // Преобразование числовых значений
      if (v is num) return RpcBool(v != 0);

      // Преобразование строковых значений
      final vStr = v.toString().toLowerCase().trim();
      if (vStr == 'true' || vStr == '1') return const RpcBool(true);
      if (vStr == 'false' || vStr == '0') return const RpcBool(false);

      // Для всех других случаев
      return const RpcBool(false);
    } catch (e) {
      return const RpcBool(false);
    }
  }

  /// Создает RpcBool из бинарных данных
  static RpcBool fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return const RpcBool(false);
    // В бинарном представлении true = 1, false = 0
    return RpcBool(bytes[0] != 0);
  }

  /// Сериализует в бинарный формат (1 байт: 1 или 0)
  @override
  Uint8List serialize() {
    return Uint8List.fromList([value ? 1 : 0]);
  }

  @override
  String toString() => 'RpcBool(${value})';
}
