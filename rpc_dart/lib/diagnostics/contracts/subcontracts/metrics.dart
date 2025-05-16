part of '../_contract.dart';

/// Контракт для отправки метрик различных типов
abstract class _RpcMetricsContract extends RpcServiceContract {
  // Константы для имен методов
  static const methodSendMetrics = 'sendMetrics';
  static const methodLatencyMetric = 'latencyMetric';
  static const methodStreamMetric = 'streamMetric';
  static const methodErrorMetric = 'errorMetric';
  static const methodResourceMetric = 'resourceMetric';

  _RpcMetricsContract() : super('metrics');

  @override
  void setup() {
    addUnaryRequestMethod<RpcMetricsList, RpcNull>(
      methodName: methodSendMetrics,
      handler: (metricsList) => sendMetrics(metricsList.metrics),
      argumentParser: RpcMetricsList.fromJson,
      responseParser: RpcNull.fromJson,
    );

    addUnaryRequestMethod<RpcMetric, RpcNull>(
      methodName: methodLatencyMetric,
      handler: (metric) => latencyMetric(metric as RpcMetric<RpcLatencyMetric>),
      argumentParser: RpcMetric.fromJson,
      responseParser: RpcNull.fromJson,
    );

    addUnaryRequestMethod<RpcMetric, RpcNull>(
      methodName: methodStreamMetric,
      handler: (metric) => streamMetric(metric as RpcMetric<RpcStreamMetric>),
      argumentParser: RpcMetric.fromJson,
      responseParser: RpcNull.fromJson,
    );

    addUnaryRequestMethod<RpcMetric, RpcNull>(
      methodName: methodErrorMetric,
      handler: (metric) => errorMetric(metric as RpcMetric<RpcErrorMetric>),
      argumentParser: RpcMetric.fromJson,
      responseParser: RpcNull.fromJson,
    );

    addUnaryRequestMethod<RpcMetric, RpcNull>(
      methodName: methodResourceMetric,
      handler: (metric) =>
          resourceMetric(metric as RpcMetric<RpcResourceMetric>),
      argumentParser: RpcMetric.fromJson,
      responseParser: RpcNull.fromJson,
    );

    super.setup();
  }

  /// Метод для отправки пакета метрик различного типа
  Future<RpcNull> sendMetrics(List<RpcMetric> metrics);

  /// Метод для отправки метрик задержки
  Future<RpcNull> latencyMetric(RpcMetric<RpcLatencyMetric> metric);

  /// Метод для отправки метрик стриминга
  Future<RpcNull> streamMetric(RpcMetric<RpcStreamMetric> metric);

  /// Метод для отправки метрик ошибок
  Future<RpcNull> errorMetric(RpcMetric<RpcErrorMetric> metric);

  /// Метод для отправки метрик ресурсов
  Future<RpcNull> resourceMetric(RpcMetric<RpcResourceMetric> metric);
}

// Клиентские реализации контрактов
class _MetricsClient extends _RpcMetricsContract {
  final RpcEndpoint _endpoint;

  _MetricsClient(this._endpoint);

  @override
  Future<RpcNull> sendMetrics(List<RpcMetric> metrics) {
    final metricsList = RpcMetricsList(metrics);
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: _RpcMetricsContract.methodSendMetrics,
        )
        .call(
          request: metricsList,
          responseParser: RpcNull.fromJson,
        );
  }

  @override
  Future<RpcNull> latencyMetric(RpcMetric<RpcLatencyMetric> metric) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: _RpcMetricsContract.methodLatencyMetric,
        )
        .call(
          request: metric,
          responseParser: RpcNull.fromJson,
        );
  }

  @override
  Future<RpcNull> streamMetric(RpcMetric<RpcStreamMetric> metric) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: _RpcMetricsContract.methodStreamMetric,
        )
        .call(
          request: metric,
          responseParser: RpcNull.fromJson,
        );
  }

  @override
  Future<RpcNull> errorMetric(RpcMetric<RpcErrorMetric> metric) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: _RpcMetricsContract.methodErrorMetric,
        )
        .call(
          request: metric,
          responseParser: RpcNull.fromJson,
        );
  }

  @override
  Future<RpcNull> resourceMetric(RpcMetric<RpcResourceMetric> metric) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: _RpcMetricsContract.methodResourceMetric,
        )
        .call(
          request: metric,
          responseParser: RpcNull.fromJson,
        );
  }
}
