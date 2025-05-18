// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Маркер инициализации клиентского стриминга
class RpcClientStreamingMarker extends RpcServiceMarker {
  /// Идентификатор потока
  final String streamId;

  /// Дополнительные параметры (опционально)
  final Map<String, dynamic>? parameters;

  /// Конструктор
  const RpcClientStreamingMarker({
    required this.streamId,
    this.parameters,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.clientStreamingInit;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['_clientStreaming'] = true; // для обратной совместимости
    baseJson['_streamId'] = streamId;

    // Добавляем дополнительные параметры, если они есть
    if (parameters != null) {
      baseJson.addAll(parameters!);
    }

    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcClientStreamingMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.clientStreamingInit.name ||
        json['_clientStreaming'] != true ||
        json['_streamId'] == null) {
      throw FormatException(
          'Неверный формат маркера инициализации клиентского стриминга');
    }

    // Копируем все параметры кроме служебных
    final Map<String, dynamic> parameters = {};
    json.forEach((key, value) {
      if (!key.startsWith('_')) {
        parameters[key] = value;
      }
    });

    return RpcClientStreamingMarker(
      streamId: json['_streamId'] as String,
      parameters: parameters.isNotEmpty ? parameters : null,
    );
  }
}
