// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_contract.dart';

/// Контракт для трассировки
abstract class _RpcTracingContract extends OldRpcServiceContract {
  // Константы для имен методов
  static const methodTraceEvent = 'traceEvent';

  _RpcTracingContract() : super('tracing');

  @override
  void setup() {
    addUnaryRequestMethod<RpcMetric, RpcNull>(
      methodName: methodTraceEvent,
      handler: (metric) => traceEvent(metric as RpcMetric<RpcTraceMetric>),
      argumentParser: RpcMetric.fromJson,
      responseParser: RpcNull.fromJson,
    );

    super.setup();
  }

  /// Метод для отправки метрик трассировки
  Future<RpcNull> traceEvent(RpcMetric<RpcTraceMetric> event);
}

class _TracingClient extends _RpcTracingContract {
  final RpcEndpoint _endpoint;

  _TracingClient(this._endpoint);

  @override
  Future<RpcNull> traceEvent(RpcMetric<RpcTraceMetric> event) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: _RpcTracingContract.methodTraceEvent,
        )
        .call(
          request: event,
          responseParser: RpcNull.fromJson,
        );
  }
}
