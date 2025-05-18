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

  /// Создает новый экземпляр сообщения с обновленной полезной нагрузкой
  RpcMessage withPayload(dynamic newPayload);

  /// Создает новый экземпляр сообщения с обновленными заголовочными метаданными
  RpcMessage withHeaderMetadata(Map<String, dynamic> newMetadata);

  /// Создает новый экземпляр сообщения с обновленными трейлерными метаданными
  RpcMessage withTrailerMetadata(Map<String, dynamic> newMetadata);
}

/// Класс, представляющий сообщение протокола
final class RpcMessage extends IRpcSerializableMessage implements IRpcContext {
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

  /// Создает новый экземпляр сообщения с обновленной полезной нагрузкой
  @override
  RpcMessage withPayload(dynamic newPayload) {
    return RpcMessage(
      type: type,
      messageId: messageId,
      serviceName: serviceName,
      methodName: methodName,
      payload: newPayload,
      headerMetadata: headerMetadata,
      trailerMetadata: trailerMetadata,
      debugLabel: debugLabel,
    );
  }

  /// Создает новый экземпляр сообщения с обновленными заголовочными метаданными
  @override
  RpcMessage withHeaderMetadata(Map<String, dynamic> newMetadata) {
    final headers = Map<String, dynamic>.from(headerMetadata ?? {})
      ..addAll(newMetadata);

    return RpcMessage(
      type: type,
      messageId: messageId,
      serviceName: serviceName,
      methodName: methodName,
      payload: payload,
      headerMetadata: headers,
      trailerMetadata: trailerMetadata,
      debugLabel: debugLabel,
    );
  }

  /// Создает новый экземпляр сообщения с обновленными трейлерными метаданными
  @override
  RpcMessage withTrailerMetadata(Map<String, dynamic> newMetadata) {
    final trailers = Map<String, dynamic>.from(trailerMetadata ?? {})
      ..addAll(newMetadata);

    return RpcMessage(
      type: type,
      messageId: messageId,
      serviceName: serviceName,
      methodName: methodName,
      payload: payload,
      headerMetadata: headerMetadata,
      trailerMetadata: trailers,
      debugLabel: debugLabel,
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
