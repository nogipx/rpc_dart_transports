// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_metric.dart';

/// Перечисление типов трассировочных событий
enum RpcTraceMetricType {
  /// Начало вызова метода
  methodStart,

  /// Завершение вызова метода
  methodEnd,

  /// Ошибка при вызове метода
  methodError,

  /// Начало выполнения запроса
  requestStart,

  /// Завершение выполнения запроса
  requestEnd,

  /// Ошибка при выполнении запроса
  requestError,

  /// События транспортного уровня
  transport,

  /// Неизвестный тип события
  unknown;

  static RpcTraceMetricType fromJson(String json) {
    return values.firstWhere(
      (e) => e.name == json,
      orElse: () => unknown,
    );
  }
}

/// Метрика для трассировки событий в RPC
///
/// Используется для отслеживания вызовов методов и их выполнения,
/// а также для построения распределенных трассировок.
class RpcTraceMetric implements IRpcSerializableMessage {
  /// Уникальный идентификатор метрики
  final String id;

  /// ID трассировки, к которой относится эта метрика
  final String? traceId;

  /// Временная метка создания метрики
  final int timestamp;

  /// Тип трассировочного события
  final RpcTraceMetricType eventType;

  /// Имя метода
  final String method;

  /// Имя сервиса
  final String service;

  /// Идентификатор запроса
  final String? requestId;

  /// Идентификатор родительского события
  final String? parentId;

  /// Длительность выполнения в миллисекундах (для событий завершения)
  final int? durationMs;

  /// Ошибка, если событие типа Error
  final Map<String, dynamic>? error;

  /// Дополнительные метаданные
  final Map<String, dynamic>? metadata;

  const RpcTraceMetric({
    required this.id,
    this.traceId,
    required this.timestamp,
    required this.eventType,
    required this.method,
    required this.service,
    this.requestId,
    this.parentId,
    this.durationMs,
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
      'event_type': eventType.name,
      'method': method,
      'service': service,
      if (requestId != null) 'request_id': requestId,
      if (parentId != null) 'parent_id': parentId,
      if (durationMs != null) 'duration_ms': durationMs,
      if (error != null) 'error': error,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Создание из JSON
  factory RpcTraceMetric.fromJson(Map<String, dynamic> json) {
    final eventTypeString = json['event_type'] as String;
    final eventType = RpcTraceMetricType.fromJson(eventTypeString);

    return RpcTraceMetric(
      id: json['id'] as String,
      traceId: json['trace_id'] as String?,
      timestamp: json['timestamp'] as int,
      eventType: eventType,
      method: json['method'] as String,
      service: json['service'] as String,
      requestId: json['request_id'] as String?,
      parentId: json['parent_id'] as String?,
      durationMs: json['duration_ms'] as int?,
      error: json['error'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
