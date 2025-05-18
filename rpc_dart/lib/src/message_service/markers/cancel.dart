// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Маркер отмены операции в стиле gRPC
class RpcCancelMarker extends RpcServiceMarker {
  /// Идентификатор операции для отмены
  final String operationId;

  /// Причина отмены (опционально)
  final String? reason;

  /// Дополнительные данные (опционально)
  final Map<String, dynamic>? details;

  /// Конструктор
  const RpcCancelMarker({
    required this.operationId,
    this.reason,
    this.details,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.cancel;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['operationId'] = operationId;
    if (reason != null) {
      baseJson['reason'] = reason;
    }
    if (details != null) {
      baseJson['details'] = details;
    }
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcCancelMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.cancel.name) {
      throw FormatException('Неверный формат маркера отмены');
    }

    return RpcCancelMarker(
      operationId: json['operationId'] as String,
      reason: json['reason'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}
