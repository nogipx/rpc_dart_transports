// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Маркер трейлеров (завершающие метаданные)
class RpcTrailersMarker extends RpcServiceMarker {
  /// Завершающие метаданные
  final Map<String, dynamic> trailers;

  /// Конструктор
  const RpcTrailersMarker({
    required this.trailers,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.trailers;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['trailers'] = trailers;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcTrailersMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.trailers.name) {
      throw FormatException('Неверный формат маркера трейлеров');
    }

    return RpcTrailersMarker(
      trailers: json['trailers'] as Map<String, dynamic>,
    );
  }
}
