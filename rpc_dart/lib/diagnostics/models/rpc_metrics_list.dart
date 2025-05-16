import 'package:rpc_dart/diagnostics.dart';
import 'package:rpc_dart/rpc_dart.dart';

/// Простая обертка для списка метрик, которая реализует IRpcSerializableMessage
class RpcMetricsList implements IRpcSerializableMessage {
  final List<RpcMetric> metrics;

  RpcMetricsList(this.metrics);

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
