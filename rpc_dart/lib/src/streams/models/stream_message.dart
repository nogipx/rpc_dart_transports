// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Обертка для сообщений, передаваемых через стрим-менеджер
class StreamMessage<T extends IRpcSerializableMessage>
    implements IRpcSerializableMessage {
  /// Оригинальное сообщение
  final T message;

  /// ID клиентского стрима, который отправил сообщение
  final String streamId;

  /// Метка времени создания сообщения
  final DateTime timestamp;

  /// Дополнительные метаданные
  final Map<String, dynamic>? metadata;

  /// Создает новую обертку сообщения
  StreamMessage(
      {required this.message,
      required this.streamId,
      DateTime? timestamp,
      this.metadata})
      : timestamp = timestamp ?? DateTime.now();

  @override
  Map<String, dynamic> toJson() {
    return {
      'message': message.toJson(),
      'streamId': streamId,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Создает StreamMessage из JSON
  ///
  /// [json] - JSON-представление сообщения
  /// [messageFromJson] - функция для создания экземпляра сообщения из JSON
  static StreamMessage<T> fromJson<T extends IRpcSerializableMessage>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) messageFromJson,
  ) {
    return StreamMessage<T>(
      message: messageFromJson(json['message'] as Map<String, dynamic>),
      streamId: json['streamId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
