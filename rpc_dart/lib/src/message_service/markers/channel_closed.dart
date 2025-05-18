// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Маркер закрытия канала связи
class RpcChannelClosedMarker extends RpcServiceMarker {
  /// Идентификатор потока (опционально)
  final String? streamId;

  /// Причина закрытия (опционально)
  final String? reason;

  /// Конструктор
  const RpcChannelClosedMarker({
    this.streamId,
    this.reason,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.channelClosed;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['_channelClosed'] = true; // для обратной совместимости

    if (streamId != null) {
      baseJson['_streamId'] = streamId;
    }

    if (reason != null) {
      baseJson['reason'] = reason;
    }

    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcChannelClosedMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.channelClosed.name ||
        json['_channelClosed'] != true) {
      throw FormatException('Неверный формат маркера закрытия канала');
    }

    return RpcChannelClosedMarker(
      streamId: json['_streamId'] as String?,
      reason: json['reason'] as String?,
    );
  }
}
