// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_metric.dart';

/// Метрика для отслеживания использования ресурсов
class RpcResourceMetric implements IRpcSerializableMessage {
  /// Использование памяти в байтах
  final int? memoryUsage;

  /// Использование процессора (процент от 0 до 100)
  final double? cpuUsage;

  /// Количество активных соединений
  final int? activeConnections;

  /// Количество активных потоков
  final int? activeStreams;

  /// Количество запросов в секунду
  final double? requestsPerSecond;

  /// Сетевой трафик (входящий) в байтах
  final int? networkInBytes;

  /// Сетевой трафик (исходящий) в байтах
  final int? networkOutBytes;

  /// Размер очереди запросов
  final int? queueSize;

  /// Дополнительные метрики ресурсов
  final Map<String, dynamic>? additionalMetrics;

  const RpcResourceMetric({
    this.memoryUsage,
    this.cpuUsage,
    this.activeConnections,
    this.activeStreams,
    this.requestsPerSecond,
    this.networkInBytes,
    this.networkOutBytes,
    this.queueSize,
    this.additionalMetrics,
  });

  /// Преобразование в JSON
  @override
  Map<String, dynamic> toJson() => {
        if (memoryUsage != null) 'memory_usage': memoryUsage,
        if (cpuUsage != null) 'cpu_usage': cpuUsage,
        if (activeConnections != null) 'active_connections': activeConnections,
        if (activeStreams != null) 'active_streams': activeStreams,
        if (requestsPerSecond != null) 'requests_per_second': requestsPerSecond,
        if (networkInBytes != null) 'network_in_bytes': networkInBytes,
        if (networkOutBytes != null) 'network_out_bytes': networkOutBytes,
        if (queueSize != null) 'queue_size': queueSize,
        if (additionalMetrics != null) 'additional_metrics': additionalMetrics,
      };

  /// Создание из JSON
  factory RpcResourceMetric.fromJson(Map<String, dynamic> json) {
    return RpcResourceMetric(
      memoryUsage: json['memory_usage'] as int?,
      cpuUsage: json['cpu_usage'] as double?,
      activeConnections: json['active_connections'] as int?,
      activeStreams: json['active_streams'] as int?,
      requestsPerSecond: json['requests_per_second'] as double?,
      networkInBytes: json['network_in_bytes'] as int?,
      networkOutBytes: json['network_out_bytes'] as int?,
      queueSize: json['queue_size'] as int?,
      additionalMetrics: json['additional_metrics'] as Map<String, dynamic>?,
    );
  }
}
