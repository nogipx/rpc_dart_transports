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

  /// Метаданные сообщения
  final Map<String, dynamic>? metadata;

  /// Создает новое сообщение
  const RpcMessage({
    required this.type,
    required this.id,
    this.service,
    this.method,
    this.payload,
    this.metadata,
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
    };
  }

  @override
  String toString() {
    return 'Message{type: $type, id: $id, service: $service, method: $method}';
  }
}
