// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_metric.dart';

/// Тип операции для измерения латентности
enum RpcLatencyOperationType {
  /// Вызов метода
  methodCall,

  /// Обработка запроса
  requestProcessing,

  /// Сериализация
  serialization,

  /// Десериализация
  deserialization,

  /// Передача данных
  transport,

  /// Взаимодействие с сетью
  network,

  /// Обработка на промежуточном ПО
  middleware,

  /// Неизвестный тип операции
  unknown;

  static RpcLatencyOperationType fromJson(String json) {
    return values.firstWhere(
      (e) => e.name == json,
      orElse: () => unknown,
    );
  }
}

/// Метрика для отслеживания задержки/времени выполнения операций
class RpcLatencyMetric extends IRpcSerializableMessage {
  /// Уникальный идентификатор метрики
  final String id;

  /// ID трассировки, к которой относится эта метрика
  final String? traceId;

  /// Временная метка создания метрики
  final int timestamp;

  /// Тип операции, для которой измеряется задержка
  final RpcLatencyOperationType operationType;

  /// Название операции
  final String operation;

  /// Имя метода (если применимо)
  final String? method;

  /// Имя сервиса (если применимо)
  final String? service;

  /// Время начала операции (timestamp)
  final int startTime;

  /// Время окончания операции (timestamp)
  final int endTime;

  /// Длительность операции в миллисекундах
  int get durationMs => endTime - startTime;

  /// Идентификатор запроса
  final String? requestId;

  /// Идентификатор клиента
  final String? clientId;

  /// Успешность операции
  final bool success;

  /// Информация об ошибке (если операция не успешна)
  final Map<String, dynamic>? error;

  /// Дополнительные метаданные
  final Map<String, dynamic>? metadata;

  const RpcLatencyMetric({
    required this.id,
    this.traceId,
    required this.timestamp,
    required this.operationType,
    required this.operation,
    this.method,
    this.service,
    required this.startTime,
    required this.endTime,
    this.requestId,
    this.clientId,
    required this.success,
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
      'operation_type': operationType.name,
      'operation': operation,
      if (method != null) 'method': method,
      if (service != null) 'service': service,
      'start_time': startTime,
      'end_time': endTime,
      'duration_ms': durationMs,
      if (requestId != null) 'request_id': requestId,
      if (clientId != null) 'client_id': clientId,
      'success': success,
      if (error != null) 'error': error,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Создание из JSON
  factory RpcLatencyMetric.fromJson(Map<String, dynamic> json) {
    final operationTypeString = json['operation_type'] as String;
    final operationType = RpcLatencyOperationType.fromJson(operationTypeString);

    return RpcLatencyMetric(
      id: json['id'] as String,
      traceId: json['trace_id'] as String?,
      timestamp: json['timestamp'] as int,
      operationType: operationType,
      operation: json['operation'] as String,
      method: json['method'] as String?,
      service: json['service'] as String?,
      startTime: json['start_time'] as int,
      endTime: json['end_time'] as int,
      requestId: json['request_id'] as String?,
      clientId: json['client_id'] as String?,
      success: json['success'] as bool,
      error: json['error'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
