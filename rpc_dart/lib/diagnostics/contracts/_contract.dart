// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/diagnostics.dart';
import 'package:rpc_dart/rpc_dart.dart';

/// Базовый контракт диагностического сервиса
///
/// Определяет методы для отправки различных типов метрик на сервер
abstract class RpcDiagnosticServiceContract extends RpcServiceContract {
  RpcDiagnosticServiceContract() : super('diagnostics');

  // Константы для имен методов
  static const methodSendMetrics = 'sendMetrics';
  static const methodTraceEvent = 'traceEvent';
  static const methodLatencyMetric = 'latencyMetric';
  static const methodStreamMetric = 'streamMetric';
  static const methodErrorMetric = 'errorMetric';
  static const methodResourceMetric = 'resourceMetric';
  static const methodRegisterClient = 'registerClient';
  static const methodPing = 'ping';

  @override
  void setup() {
    // Регистрация методов
    addUnaryRequestMethod<RpcMetricsList, RpcNull>(
      methodName: methodSendMetrics,
      handler: (metricsList) => sendMetrics(metricsList.metrics),
      argumentParser: RpcMetricsList.fromJson,
      responseParser: RpcNull.fromJson,
    );

    addUnaryRequestMethod<RpcMetric, RpcNull>(
      methodName: methodTraceEvent,
      handler: (metric) => traceEvent(metric as RpcMetric<RpcTraceMetric>),
      argumentParser: RpcMetric.fromJson,
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

    addUnaryRequestMethod<RpcClientIdentity, RpcNull>(
      methodName: methodRegisterClient,
      handler: registerClient,
      argumentParser: RpcClientIdentity.fromJson,
      responseParser: RpcNull.fromJson,
    );

    addUnaryRequestMethod<RpcNull, RpcBool>(
      methodName: methodPing,
      handler: ping,
      argumentParser: RpcNull.fromJson,
      responseParser: RpcBool.fromJson,
    );

    super.setup();
  }

  /// Метод для отправки пакета метрик различного типа
  Future<RpcNull> sendMetrics(List<RpcMetric> metrics);

  /// Метод для отправки метрик трассировки
  Future<RpcNull> traceEvent(RpcMetric<RpcTraceMetric> event);

  /// Метод для отправки метрик задержки
  Future<RpcNull> latencyMetric(RpcMetric<RpcLatencyMetric> metric);

  /// Метод для отправки метрик стриминга
  Future<RpcNull> streamMetric(RpcMetric<RpcStreamMetric> metric);

  /// Метод для отправки метрик ошибок
  Future<RpcNull> errorMetric(RpcMetric<RpcErrorMetric> metric);

  /// Метод для отправки метрик ресурсов
  Future<RpcNull> resourceMetric(RpcMetric<RpcResourceMetric> metric);

  /// Метод для регистрации клиента в диагностической системе
  Future<RpcNull> registerClient(RpcClientIdentity clientIdentity);

  /// Метод для проверки доступности диагностического сервера
  Future<RpcBool> ping(RpcNull _);
}

/// Клиентская реализация контракта диагностического сервиса
class DiagnosticClientContract extends RpcDiagnosticServiceContract {
  final RpcEndpoint _endpoint;

  DiagnosticClientContract(this._endpoint) {
    _endpoint.registerServiceContract(this);
  }

  @override
  Future<RpcNull> sendMetrics(List<RpcMetric> metrics) {
    final metricsList = RpcMetricsList(metrics);
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: RpcDiagnosticServiceContract.methodSendMetrics,
        )
        .call(
          request: metricsList,
          responseParser: RpcNull.fromJson,
        );
  }

  @override
  Future<RpcNull> traceEvent(RpcMetric<RpcTraceMetric> event) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: RpcDiagnosticServiceContract.methodTraceEvent,
        )
        .call(
          request: event,
          responseParser: RpcNull.fromJson,
        );
  }

  @override
  Future<RpcNull> latencyMetric(RpcMetric<RpcLatencyMetric> metric) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: RpcDiagnosticServiceContract.methodLatencyMetric,
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
          methodName: RpcDiagnosticServiceContract.methodStreamMetric,
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
          methodName: RpcDiagnosticServiceContract.methodErrorMetric,
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
          methodName: RpcDiagnosticServiceContract.methodResourceMetric,
        )
        .call(
          request: metric,
          responseParser: RpcNull.fromJson,
        );
  }

  @override
  Future<RpcNull> registerClient(RpcClientIdentity clientIdentity) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: RpcDiagnosticServiceContract.methodRegisterClient,
        )
        .call(
          request: clientIdentity,
          responseParser: RpcNull.fromJson,
        );
  }

  @override
  Future<RpcBool> ping(RpcNull _) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: RpcDiagnosticServiceContract.methodPing,
        )
        .call(
          request: _,
          responseParser: RpcBool.fromJson,
        );
  }
}

/// Серверная реализация контракта диагностического сервиса
class DiagnosticServerContract extends RpcDiagnosticServiceContract {
  final void Function(List<RpcMetric>) _onSendMetrics;
  final void Function(RpcMetric<RpcTraceMetric>) _onTraceEvent;
  final void Function(RpcMetric<RpcLatencyMetric>) _onLatencyMetric;
  final void Function(RpcMetric<RpcStreamMetric>) _onStreamMetric;
  final void Function(RpcMetric<RpcErrorMetric>) _onErrorMetric;
  final void Function(RpcMetric<RpcResourceMetric>) _onResourceMetric;
  final void Function(RpcClientIdentity) _onRegisterClient;
  final Future<bool> Function() _onPing;

  DiagnosticServerContract({
    required void Function(List<RpcMetric>) onSendMetrics,
    required void Function(RpcMetric<RpcTraceMetric>) onTraceEvent,
    required void Function(RpcMetric<RpcLatencyMetric>) onLatencyMetric,
    required void Function(RpcMetric<RpcStreamMetric>) onStreamMetric,
    required void Function(RpcMetric<RpcErrorMetric>) onErrorMetric,
    required void Function(RpcMetric<RpcResourceMetric>) onResourceMetric,
    required void Function(RpcClientIdentity) onRegisterClient,
    required Future<bool> Function() onPing,
  })  : _onSendMetrics = onSendMetrics,
        _onTraceEvent = onTraceEvent,
        _onLatencyMetric = onLatencyMetric,
        _onStreamMetric = onStreamMetric,
        _onErrorMetric = onErrorMetric,
        _onResourceMetric = onResourceMetric,
        _onRegisterClient = onRegisterClient,
        _onPing = onPing;

  @override
  Future<RpcNull> sendMetrics(List<RpcMetric> metrics) async {
    _onSendMetrics(metrics);
    return RpcNull();
  }

  @override
  Future<RpcNull> traceEvent(RpcMetric<RpcTraceMetric> event) async {
    _onTraceEvent(event);
    return RpcNull();
  }

  @override
  Future<RpcNull> latencyMetric(RpcMetric<RpcLatencyMetric> metric) async {
    _onLatencyMetric(metric);
    return RpcNull();
  }

  @override
  Future<RpcNull> streamMetric(RpcMetric<RpcStreamMetric> metric) async {
    _onStreamMetric(metric);
    return RpcNull();
  }

  @override
  Future<RpcNull> errorMetric(RpcMetric<RpcErrorMetric> metric) async {
    _onErrorMetric(metric);
    return RpcNull();
  }

  @override
  Future<RpcNull> resourceMetric(RpcMetric<RpcResourceMetric> metric) async {
    _onResourceMetric(metric);
    return RpcNull();
  }

  @override
  Future<RpcNull> registerClient(RpcClientIdentity clientIdentity) async {
    _onRegisterClient(clientIdentity);
    return RpcNull();
  }

  @override
  Future<RpcBool> ping(RpcNull _) async {
    final result = await _onPing();
    return RpcBool(result);
  }
}
