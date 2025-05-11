// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'message_types.dart';

/// Класс, представляющий сообщение протокола
final class RpcMessage {
  /// Тип сообщения
  final RpcMessageType type;

  /// Уникальный идентификатор сообщения
  final String id;

  /// Имя сервиса (опционально)
  final String? service;

  /// Имя метода (опционально)
  final String? method;

  /// Полезная нагрузка сообщения
  final dynamic payload;

  /// Метаданные сообщения (заголовки)
  final Map<String, dynamic>? metadata;

  /// Трейлерные метаданные сообщения (отправляются в конце)
  final Map<String, dynamic>? trailerMetadata;

  /// Метка для отладки
  final String? debugLabel;

  /// Создает новое сообщение
  const RpcMessage({
    required this.type,
    required this.id,
    this.service,
    this.method,
    this.payload,
    this.metadata,
    this.trailerMetadata,
    this.debugLabel,
  });

  /// Создает сообщение из JSON-объекта
  factory RpcMessage.fromJson(Map<String, dynamic> json) {
    return RpcMessage(
      type: RpcMessageType.values[json['type'] as int],
      id: json['id'] as String,
      service: json['service'] as String?,
      method: json['method'] as String?,
      payload: json['payload'],
      metadata: json['metadata'] as Map<String, dynamic>?,
      trailerMetadata: json['trailerMetadata'] as Map<String, dynamic>?,
      debugLabel: json['debugLabel'] as String?,
    );
  }

  /// Преобразует сообщение в JSON-объект
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'id': id,
      if (service != null) 'service': service,
      if (method != null) 'method': method,
      if (payload != null) 'payload': payload,
      if (metadata != null) 'metadata': metadata,
      if (trailerMetadata != null) 'trailerMetadata': trailerMetadata,
      if (debugLabel != null) 'debugLabel': debugLabel,
    };
  }

  @override
  String toString() {
    return 'Message{debugLabel: $debugLabel, type: $type, id: $id, service: $service, method: $method, '
        'hasMetadata: ${metadata != null}, hasTrailerMetadata: ${trailerMetadata != null}}';
  }
}
