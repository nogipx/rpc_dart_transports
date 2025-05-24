// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:convert';

import 'package:rpc_dart/rpc_dart.dart';

part 'rpc_error_metric.dart';
part 'rpc_latency_metric.dart';
part 'rpc_resource_metric.dart';
part 'rpc_stream_metric.dart';
part 'rpc_trace_metric.dart';

/// Типы метрик для RpcMetric
enum RpcMetricType {
  trace,
  latency,
  stream,
  error,
  resource,
  log,
  unknown;

  static RpcMetricType fromJson(String json) {
    return values.firstWhere(
      (e) => e.name == json,
      orElse: () => unknown,
    );
  }
}

/// Базовый класс для всех метрик в RPC Dart
///
/// Содержит общие поля для всех типов метрик и типизированное поле контента,
/// которое зависит от типа метрики
class RpcMetric<T> extends IRpcSerializableMessage {
  /// Уникальный идентификатор метрики
  final String id;

  /// Временная метка создания метрики
  final int timestamp;

  /// Тип метрики (trace, latency, stream, error, resource)
  final RpcMetricType metricType;

  /// Идентификатор клиента, который сгенерировал метрику
  final String clientId;

  /// Тип содержимого метрики, зависит от metricType
  final T content;

  const RpcMetric({
    required this.id,
    required this.timestamp,
    required this.metricType,
    required this.clientId,
    required this.content,
  });

  /// Преобразование в JSON
  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = {
      'id': id,
      'timestamp': timestamp,
      'metric_type': metricType.name,
      'client_id': clientId,
    };

    // Добавляем content в зависимости от его типа
    if (content is Map<String, dynamic>) {
      result['content'] = content;
    } else if (content != null) {
      // Предполагаем, что контент имеет метод toJson()
      try {
        result['content'] = (content as dynamic).toJson();
      } catch (e) {
        // В случае ошибки пытаемся сериализовать напрямую
        result['content'] = content;
      }
    }

    return result;
  }

  /// Преобразование в строку JSON
  String toJsonString() => jsonEncode(toJson());

  /// Фабричный метод для создания метрики нужного типа из JSON
  static RpcMetric fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final timestamp = json['timestamp'] as int;
    final metricTypeString = json['metric_type'] as String;
    final clientId = json['client_id'] as String;
    final contentJson = json['content'];

    final metricType = RpcMetricType.fromJson(metricTypeString);

    return switch (metricType) {
      RpcMetricType.trace => RpcMetric<RpcTraceMetric>(
          id: id,
          timestamp: timestamp,
          metricType: metricType,
          clientId: clientId,
          content: RpcTraceMetric.fromJson(contentJson),
        ),
      RpcMetricType.latency => RpcMetric<RpcLatencyMetric>(
          id: id,
          timestamp: timestamp,
          metricType: metricType,
          clientId: clientId,
          content: RpcLatencyMetric.fromJson(contentJson),
        ),
      RpcMetricType.stream => RpcMetric<RpcStreamMetric>(
          id: id,
          timestamp: timestamp,
          metricType: metricType,
          clientId: clientId,
          content: RpcStreamMetric.fromJson(contentJson),
        ),
      RpcMetricType.error => RpcMetric<RpcErrorMetric>(
          id: id,
          timestamp: timestamp,
          metricType: metricType,
          clientId: clientId,
          content: RpcErrorMetric.fromJson(contentJson),
        ),
      RpcMetricType.resource => RpcMetric<RpcResourceMetric>(
          id: id,
          timestamp: timestamp,
          metricType: metricType,
          clientId: clientId,
          content: RpcResourceMetric.fromJson(contentJson),
        ),
      RpcMetricType.log => RpcMetric<RpcLoggerMetric>(
          id: id,
          timestamp: timestamp,
          metricType: metricType,
          clientId: clientId,
          content: RpcLoggerMetric.fromJson(contentJson),
        ),
      _ => throw ArgumentError('Неизвестный тип метрики: $metricType'),
    };
  }

  /// Создает метрику из строки JSON
  static RpcMetric fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return fromJson(json);
  }

  /// Создает метрику трассировки
  static RpcMetric<RpcTraceMetric> trace({
    required String id,
    required int timestamp,
    required String clientId,
    required RpcTraceMetric content,
  }) {
    return RpcMetric<RpcTraceMetric>(
      id: id,
      timestamp: timestamp,
      metricType: RpcMetricType.trace,
      clientId: clientId,
      content: content,
    );
  }

  /// Создает метрику задержки
  static RpcMetric<RpcLatencyMetric> latency({
    required String id,
    required int timestamp,
    required String clientId,
    required RpcLatencyMetric content,
  }) {
    return RpcMetric<RpcLatencyMetric>(
      id: id,
      timestamp: timestamp,
      metricType: RpcMetricType.latency,
      clientId: clientId,
      content: content,
    );
  }

  /// Создает метрику стрима
  static RpcMetric<RpcStreamMetric> stream({
    required String id,
    required int timestamp,
    required String clientId,
    required RpcStreamMetric content,
  }) {
    return RpcMetric<RpcStreamMetric>(
      id: id,
      timestamp: timestamp,
      metricType: RpcMetricType.stream,
      clientId: clientId,
      content: content,
    );
  }

  /// Создает метрику ошибки
  static RpcMetric<RpcErrorMetric> error({
    required String id,
    required int timestamp,
    required String clientId,
    required RpcErrorMetric content,
  }) {
    return RpcMetric<RpcErrorMetric>(
      id: id,
      timestamp: timestamp,
      metricType: RpcMetricType.error,
      clientId: clientId,
      content: content,
    );
  }

  /// Создает метрику ресурсов
  static RpcMetric<RpcResourceMetric> resource({
    required String id,
    required int timestamp,
    required String clientId,
    required RpcResourceMetric content,
  }) {
    return RpcMetric<RpcResourceMetric>(
      id: id,
      timestamp: timestamp,
      metricType: RpcMetricType.resource,
      clientId: clientId,
      content: content,
    );
  }

  /// Создает метрику лога
  static RpcMetric<RpcLoggerMetric> log({
    required String id,
    required int timestamp,
    required String clientId,
    required RpcLoggerMetric content,
  }) {
    return RpcMetric<RpcLoggerMetric>(
      id: id,
      timestamp: timestamp,
      metricType: RpcMetricType.log,
      clientId: clientId,
      content: content,
    );
  }
}
