// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_metric.dart';

/// Перечисление типов событий потока
enum RpcStreamMetricEventType {
  /// Открытие потока
  open,

  /// Данные отправлены через поток
  data,

  /// Поток закрыт
  close,

  /// Произошла ошибка в потоке
  error,

  /// Достигнуто ограничение скорости потока
  rateLimit,

  /// Поток приостановлен
  pause,

  /// Поток возобновлен
  resume,

  /// Неизвестный тип события
  unknown;

  static RpcStreamMetricEventType fromJson(String json) {
    return values.firstWhere(
      (e) => e.name == json,
      orElse: () => unknown,
    );
  }
}

/// Метрика для отслеживания работы RPC-стримов
///
/// Используется для отслеживания создания и работы стримов,
/// количества сообщений и пропускной способности.
class RpcStreamMetric implements IRpcSerializableMessage {
  /// Уникальный идентификатор метрики
  final String id;

  /// ID трассировки, к которой относится эта метрика
  final String? traceId;

  /// Временная метка создания метрики
  final int timestamp;

  /// Идентификатор потока
  final String streamId;

  /// Тип события потока
  final RpcStreamMetricEventType eventType;

  /// Направление потока (входящий/исходящий)
  final String direction;

  /// Метод, связанный с событием, если применимо
  final String? method;

  /// Количество данных в байтах
  final int? dataSize;

  /// Количество сообщений, отправленных через поток
  final int? messageCount;

  /// Скорость передачи данных (байт/сек)
  final double? throughput;

  /// Длительность активности потока (для закрытых потоков)
  final int? duration;

  /// Информация об ошибке, если событие типа error
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
      'trace_id': traceId,
      'timestamp': timestamp,
      'stream_id': streamId,
      'event_type': eventType.name,
      'direction': direction,
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
    final eventType = RpcStreamMetricEventType.fromJson(eventTypeString);

    return RpcStreamMetric(
      id: json['id'] as String,
      traceId: json['trace_id'] as String?,
      timestamp: json['timestamp'] as int,
      streamId: json['stream_id'] as String,
      eventType: eventType,
      direction: json['direction'] as String,
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
