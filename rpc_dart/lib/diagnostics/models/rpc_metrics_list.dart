// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/diagnostics.dart';
import 'package:rpc_dart/rpc_dart.dart';

/// Простая обертка для списка метрик, которая реализует IRpcSerializableMessage
class RpcMetricsList implements IRpcSerializableMessage {
  final List<RpcMetric> metrics;

  RpcMetricsList(this.metrics);

  dynamic get payload => this;

  @override
  Map<String, dynamic> toJson() {
    return {
      'metrics': metrics.map((m) => m.toJson()).toList(),
    };
  }

  factory RpcMetricsList.fromJson(Map<String, dynamic> json) {
    final List metricsList = json['metrics'] as List;
    return RpcMetricsList(
      metricsList
          .map((item) => RpcMetric.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
