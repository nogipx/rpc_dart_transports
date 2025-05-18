// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Маркер завершения клиентского стрима
class RpcClientStreamEndMarker extends RpcServiceMarker {
  /// Конструктор
  const RpcClientStreamEndMarker();

  @override
  RpcMarkerType get markerType => RpcMarkerType.clientStreamEnd;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['_clientStreamEnd'] = true;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcClientStreamEndMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.clientStreamEnd.name ||
        json['_clientStreamEnd'] != true) {
      throw FormatException(
          'Неверный формат маркера завершения клиентского стрима');
    }
    return const RpcClientStreamEndMarker();
  }
}
