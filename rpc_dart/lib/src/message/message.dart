// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

/// Общий интерфейс для контекста RPC-операций
abstract interface class IRpcContext {
  /// Уникальный идентификатор сообщения/операции
  String get messageId;

  /// Имя сервиса (опционально)
  String? get serviceName;

  /// Имя метода (опционально)
  String? get methodName;

  /// Полезная нагрузка
  dynamic get payload;

  /// Метаданные сообщения
  Map<String, dynamic>? get metadata;

  /// Заголовочные метаданные
  Map<String, dynamic>? get headerMetadata;

  /// Трейлерные метаданные
  Map<String, dynamic>? get trailerMetadata;
}

/// Класс, представляющий сообщение протокола
final class RpcMessage implements IRpcSerializableMessage, IRpcContext {
  /// Тип сообщения
  final RpcMessageType type;

  /// Уникальный идентификатор сообщения
  final String id;

  /// Имя сервиса (опционально)
  final String? service;

  /// Имя метода (опционально)
  final String? method;

  /// Методы для совместимости с IRpcContext
  @override
  String get messageId => id;

  @override
  String? get serviceName => service;

  @override
  String? get methodName => method;

  @override
  Map<String, dynamic>? get headerMetadata => metadata;

  /// Полезная нагрузка сообщения
  @override
  final dynamic payload;

  /// Метаданные сообщения (заголовки)
  @override
  final Map<String, dynamic>? metadata;

  /// Трейлерные метаданные сообщения (отправляются в конце)
  @override
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
      type: RpcMessageType.fromString(json['type'] as String?),
      id: json['id'] as String? ?? '',
      service: json['service'] as String?,
      method: json['method'] as String?,
      payload: json['payload'],
      metadata: json['metadata'] as Map<String, dynamic>?,
      trailerMetadata: json['trailerMetadata'] as Map<String, dynamic>?,
      debugLabel: json['debugLabel'] as String?,
    );
  }

  /// Преобразует сообщение в JSON-объект
  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
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
