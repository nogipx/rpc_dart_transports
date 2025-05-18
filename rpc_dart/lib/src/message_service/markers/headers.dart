// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Маркер заголовков (начальные метаданные)
class RpcHeadersMarker extends RpcServiceMarker {
  /// Метаданные запроса
  final Map<String, dynamic> headers;

  /// Конструктор
  const RpcHeadersMarker({
    required this.headers,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.headers;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['headers'] = headers;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcHeadersMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.headers.name) {
      throw FormatException('Неверный формат маркера заголовков');
    }

    return RpcHeadersMarker(
      headers: json['headers'] as Map<String, dynamic>,
    );
  }
}
