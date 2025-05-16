// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_metric.dart';

/// Тип события стрима
enum RpcStreamEventType {
  /// Создание стрима
  created,

  /// Закрытие стрима
  closed,

  /// Отправка сообщения
  messageSent,

  /// Получение сообщения
  messageReceived,

  /// Ошибка в стриме
  error,

  /// Обратное давление
  backpressure,

  /// Неизвестный тип события
  unknown;

  static RpcStreamEventType fromJson(String json) {
    return values.firstWhere(
      (e) => e.name == json,
      orElse: () => unknown,
    );
  }
}

/// Направление потока данных
enum RpcStreamDirection {
  /// От клиента к серверу
  clientToServer,

  /// От сервера к клиенту
  serverToClient,

  /// Двунаправленный поток
  bidirectional,

  /// Неизвестное направление
  unknown;

  static RpcStreamDirection fromJson(String json) {
    return values.firstWhere(
      (e) => e.name == json,
      orElse: () => unknown,
    );
  }
}

/// Метрика для отслеживания событий стримов
class RpcStreamMetric implements IRpcSerializableMessage {
  /// Уникальный идентификатор метрики
  final String id;

  /// ID трассировки, к которой относится эта метрика
  final String? traceId;

  /// Временная метка создания метрики
  final int timestamp;

  /// Идентификатор стрима
  final String streamId;

  /// Тип события стрима
  final RpcStreamEventType eventType;

  /// Направление (client_to_server, server_to_client)
  final RpcStreamDirection direction;

  /// Метод, связанный со стримом
  final String? method;

  /// Размер данных в байтах
  final int? dataSize;

  /// Количество сообщений
  final int? messageCount;

  /// Пропускная способность (сообщений в секунду)
  final double? throughput;

  /// Длительность события в миллисекундах
  final int? duration;

  /// Информация об ошибке (если есть)
  final Map<String, dynamic>? error;

  /// Дополнительные метаданные
  final Map<String, dynamic>? metadata;

  const RpcStreamMetric({
    required this.id,
    this.traceId,
    required this.timestamp,
    required this.streamId,
    required this.eventType,
    required this.direction,
    this.method,
    this.dataSize,
    this.messageCount,
    this.throughput,
    this.duration,
    this.error,
    this.metadata,
  });

  /// Преобразование в JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (traceId != null) 'trace_id': traceId,
      'timestamp': timestamp,
      'stream_id': streamId,
      'event_type': eventType.name,
      'direction': direction.name,
      if (method != null) 'method': method,
      if (dataSize != null) 'data_size': dataSize,
      if (messageCount != null) 'message_count': messageCount,
      if (throughput != null) 'throughput': throughput,
      if (duration != null) 'duration': duration,
      if (error != null) 'error': error,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Создание из JSON
  factory RpcStreamMetric.fromJson(Map<String, dynamic> json) {
    final eventTypeString = json['event_type'] as String;
    final eventType = RpcStreamEventType.fromJson(eventTypeString);

    final directionString = json['direction'] as String;
    final direction = RpcStreamDirection.fromJson(directionString);

    return RpcStreamMetric(
      id: json['id'] as String,
      traceId: json['trace_id'] as String?,
      timestamp: json['timestamp'] as int,
      streamId: json['stream_id'] as String,
      eventType: eventType,
      direction: direction,
      method: json['method'] as String?,
      dataSize: json['data_size'] as int?,
      messageCount: json['message_count'] as int?,
      throughput: json['throughput'] as double?,
      duration: json['duration'] as int?,
      error: json['error'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
