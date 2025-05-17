// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_contract.dart';

/// Контракт для работы с логами
abstract class _RpcLoggingContract extends RpcServiceContract {
  // Константы для имен методов
  static const methodLogMetric = 'logMetric';
  static const methodStreamLogs = 'streamLogs';

  _RpcLoggingContract() : super('logging');

  @override
  void setup() {
    addUnaryRequestMethod<RpcMetric, RpcNull>(
      methodName: methodLogMetric,
      handler: (metric) => logMetric(metric as RpcMetric<RpcLogMetric>),
      argumentParser: RpcMetric.fromJson,
      responseParser: RpcNull.fromJson,
    );

    addClientStreamingMethod<RpcMetric<RpcLogMetric>, RpcNull>(
      methodName: methodStreamLogs,
      handler: logsStream,
      argumentParser: (json) =>
          RpcMetric.fromJson(json) as RpcMetric<RpcLogMetric>,
      responseParser: RpcNull.fromJson,
    );

    super.setup();
  }

  /// Метод для отправки лога
  Future<RpcNull> logMetric(RpcMetric<RpcLogMetric> metric);

  /// Метод для отправки логов через стриминг
  ClientStreamingBidiStream<RpcMetric<RpcLogMetric>, RpcNull> logsStream();
}

class _LoggingClient extends _RpcLoggingContract {
  final RpcEndpoint _endpoint;

  _LoggingClient(this._endpoint);

  @override
  Future<RpcNull> logMetric(RpcMetric<RpcLogMetric> metric) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: _RpcLoggingContract.methodLogMetric,
        )
        .call(
          request: metric,
          responseParser: RpcNull.fromJson,
        );
  }

  @override
  ClientStreamingBidiStream<RpcMetric<RpcLogMetric>, RpcNull> logsStream() {
    return _endpoint
        .clientStreaming(
          serviceName: serviceName,
          methodName: _RpcLoggingContract.methodStreamLogs,
        )
        .call(responseParser: RpcNull.fromJson);
  }
}
