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
  @override
  final String messageId;

  /// Имя сервиса (опционально)
  @override
  final String? serviceName;

  /// Имя метода (опционально)
  @override
  final String? methodName;

  /// Полезная нагрузка сообщения
  @override
  final dynamic payload;

  /// Метаданные сообщения (заголовки)
  @override
  final Map<String, dynamic>? headerMetadata;

  /// Трейлерные метаданные сообщения (отправляются в конце)
  @override
  final Map<String, dynamic>? trailerMetadata;

  /// Метка для отладки
  final String? debugLabel;

  /// Создает новое сообщение
  const RpcMessage({
    required this.type,
    required this.messageId,
    this.serviceName,
    this.methodName,
    this.payload,
    this.headerMetadata,
    this.trailerMetadata,
    this.debugLabel,
  });

  /// Создает сообщение из JSON-объекта
  factory RpcMessage.fromJson(Map<String, dynamic> json) {
    return RpcMessage(
      type: RpcMessageType.fromString(json['type'] as String?),
      messageId: json['id'] as String? ?? '',
      serviceName: json['service'] as String?,
      methodName: json['method'] as String?,
      payload: json['payload'],
      headerMetadata: json['headerMetadata'] as Map<String, dynamic>?,
      trailerMetadata: json['trailerMetadata'] as Map<String, dynamic>?,
      debugLabel: json['debugLabel'] as String?,
    );
  }

  /// Преобразует сообщение в JSON-объект
  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': messageId,
      if (serviceName != null) 'service': serviceName,
      if (methodName != null) 'method': methodName,
      if (payload != null) 'payload': payload,
      if (headerMetadata != null) 'headerMetadata': headerMetadata,
      if (trailerMetadata != null) 'trailerMetadata': trailerMetadata,
      if (debugLabel != null) 'debugLabel': debugLabel,
    };
  }

  @override
  String toString() {
    return 'Message{debugLabel: $debugLabel, type: $type, id: $messageId, service: $serviceName, method: $methodName, '
        'hasTrailerMetadata: ${trailerMetadata != null}, hasHeaderMetadata: ${headerMetadata != null}}';
  }
}
