// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Контекст вызова метода
///
/// Содержит информацию о вызове метода, включая ID сообщения,
/// метаданные и полезную нагрузку.
/// Контекст полностью иммутабельный, любые изменения создают новый экземпляр.
class RpcMethodContext implements IRpcSerializableMessage, IRpcContext {
  /// Уникальный идентификатор сообщения
  final String messageId;

  /// Метаданные сообщения (устаревшие, используйте headerMetadata)
  final Map<String, dynamic>? _metadata;

  /// Заголовочные метаданные (отправляются в начале RPC)
  final Map<String, dynamic>? _headerMetadata;

  /// Трейлерные метаданные (отправляются в конце RPC, только с сервера клиенту)
  final Map<String, dynamic>? _trailerMetadata;

  /// Полезная нагрузка (тело запроса)
  final dynamic payload;

  /// Имя сервиса
  final String? serviceName;

  /// Имя метода
  final String? methodName;

  /// Создает новый контекст вызова метода
  const RpcMethodContext({
    required this.messageId,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? headerMetadata,
    Map<String, dynamic>? trailerMetadata,
    required this.payload,
    this.serviceName,
    this.methodName,
  })  : _metadata = metadata,
        _headerMetadata = headerMetadata ?? metadata,
        _trailerMetadata = trailerMetadata;

  /// Создает контекст из сообщения
  factory RpcMethodContext.fromMessage(RpcMessage message) {
    return RpcMethodContext(
      messageId: message.id,
      payload: message.payload,
      serviceName: message.service,
      methodName: message.method,
      metadata: message.metadata,
      headerMetadata: message.metadata,
      trailerMetadata: message.trailerMetadata,
    );
  }

  /// Создает контекст из JSON-представления
  static RpcMethodContext fromJson(Map<String, dynamic> json) {
    return RpcMethodContext(
      messageId: json['messageId'] as String,
      payload: json['payload'],
      serviceName: json['serviceName'] as String?,
      methodName: json['methodName'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      headerMetadata: json['headerMetadata'] as Map<String, dynamic>?,
      trailerMetadata: json['trailerMetadata'] as Map<String, dynamic>?,
    );
  }

  /// Получает метаданные сообщения (устаревшие, используйте headerMetadata)
  @override
  Map<String, dynamic>? get metadata => UnmodifiableMapView(_metadata ?? {});

  /// Получает заголовочные метаданные
  @override
  Map<String, dynamic>? get headerMetadata =>
      UnmodifiableMapView(_headerMetadata ?? _metadata ?? {});

  /// Получает трейлерные метаданные
  @override
  Map<String, dynamic>? get trailerMetadata =>
      _trailerMetadata != null ? UnmodifiableMapView(_trailerMetadata!) : null;

  /// Создает строковое представление контекста
  @override
  String toString() => 'MethodContext(messageId: $messageId, '
      'serviceName: $serviceName, methodName: $methodName)';

  /// Создает новый экземпляр контекста с обновленными заголовочными метаданными
  RpcMethodContext withHeaderMetadata(Map<String, dynamic> newMetadata) {
    final headers = Map<String, dynamic>.from(headerMetadata ?? {})
      ..addAll(newMetadata);

    return RpcMethodContext(
      messageId: messageId,
      metadata:
          _metadata, // Сохраняем старые метаданные для обратной совместимости
      headerMetadata: headers,
      trailerMetadata: _trailerMetadata != null
          ? Map<String, dynamic>.from(_trailerMetadata!)
          : null,
      payload: payload,
      serviceName: serviceName,
      methodName: methodName,
    );
  }

  /// Создает новый экземпляр контекста с обновленными трейлерными метаданными
  RpcMethodContext withTrailerMetadata(Map<String, dynamic> newMetadata) {
    final trailers = Map<String, dynamic>.from(trailerMetadata ?? {})
      ..addAll(newMetadata);

    return RpcMethodContext(
      messageId: messageId,
      metadata: _metadata,
      headerMetadata: _headerMetadata,
      trailerMetadata: trailers,
      payload: payload,
      serviceName: serviceName,
      methodName: methodName,
    );
  }

  /// Создает новый экземпляр контекста с обновленной полезной нагрузкой
  RpcMethodContext withPayload(dynamic newPayload) {
    return RpcMethodContext(
      messageId: messageId,
      metadata: _metadata,
      headerMetadata: _headerMetadata,
      trailerMetadata: _trailerMetadata,
      payload: newPayload,
      serviceName: serviceName,
      methodName: methodName,
    );
  }

  /// Реализация метода toJson для IRpcSerializableMessage
  /// Делегирует сериализацию к payload, если это возможно
  @override
  Map<String, dynamic> toJson() {
    // Создаем базовый JSON с полями контекста
    final Map<String, dynamic> json = {
      'messageId': messageId,
      if (serviceName != null) 'serviceName': serviceName,
      if (methodName != null) 'methodName': methodName,
    };

    // Добавляем метаданные, если они есть
    if (_metadata != null) {
      json['metadata'] = _metadata;
    }
    if (_headerMetadata != null) {
      json['headerMetadata'] = _headerMetadata;
    }
    if (_trailerMetadata != null) {
      json['trailerMetadata'] = _trailerMetadata;
    }

    // Добавляем payload
    if (payload != null) {
      if (payload is IRpcSerializableMessage) {
        // Если payload сам является сериализуемым, объединяем его JSON с нашим
        final payloadJson = (payload as IRpcSerializableMessage).toJson();
        json['payload'] = payloadJson;
      } else if (payload is Map<String, dynamic>) {
        // Если payload - уже Map, просто используем его
        json['payload'] = payload;
      } else {
        // Для других типов, преобразуем в строку
        json['payload'] = payload.toString();
      }
    }

    return json;
  }
}
