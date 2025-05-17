// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_contract.dart';

/// Серверная реализация контракта диагностического сервиса
final class RpcDiagnosticServerContract extends _RpcDiagnosticServiceContract {
  RpcDiagnosticServerContract({
    required void Function(List<RpcMetric>) onSendMetrics,
    required void Function(RpcMetric<RpcTraceMetric>) onTraceEvent,
    required void Function(RpcMetric<RpcLatencyMetric>) onLatencyMetric,
    required void Function(RpcMetric<RpcStreamMetric>) onStreamMetric,
    required void Function(RpcMetric<RpcErrorMetric>) onErrorMetric,
    required void Function(RpcMetric<RpcResourceMetric>) onResourceMetric,
    required void Function(RpcMetric<RpcLoggerMetric>) onLog,
    required void Function(RpcClientIdentity) onRegisterClient,
    required Future<bool> Function() onPing,
  }) : super(
          metrics: _MetricsServer(
            onSendMetrics: onSendMetrics,
            onLatencyMetric: onLatencyMetric,
            onStreamMetric: onStreamMetric,
            onErrorMetric: onErrorMetric,
            onResourceMetric: onResourceMetric,
          ),
          logging: _LoggingServer(
            onLog: onLog,
          ),
          tracing: _TracingServer(
            onTraceEvent: onTraceEvent,
          ),
          clientManagement: _ClientManagementServer(
            onRegisterClient: onRegisterClient,
            onPing: onPing,
          ),
        );
}

// Серверные реализации контрактов
class _MetricsServer extends _RpcMetricsContract {
  final void Function(List<RpcMetric>) _onSendMetrics;
  final void Function(RpcMetric<RpcLatencyMetric>) _onLatencyMetric;
  final void Function(RpcMetric<RpcStreamMetric>) _onStreamMetric;
  final void Function(RpcMetric<RpcErrorMetric>) _onErrorMetric;
  final void Function(RpcMetric<RpcResourceMetric>) _onResourceMetric;

  _MetricsServer({
    required void Function(List<RpcMetric>) onSendMetrics,
    required void Function(RpcMetric<RpcLatencyMetric>) onLatencyMetric,
    required void Function(RpcMetric<RpcStreamMetric>) onStreamMetric,
    required void Function(RpcMetric<RpcErrorMetric>) onErrorMetric,
    required void Function(RpcMetric<RpcResourceMetric>) onResourceMetric,
  })  : _onSendMetrics = onSendMetrics,
        _onLatencyMetric = onLatencyMetric,
        _onStreamMetric = onStreamMetric,
        _onErrorMetric = onErrorMetric,
        _onResourceMetric = onResourceMetric;

  @override
  Future<RpcNull> sendMetrics(List<RpcMetric> metrics) async {
    _onSendMetrics(metrics);
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
}

class _LoggingServer extends _RpcLoggingContract {
  final void Function(RpcMetric<RpcLoggerMetric>) _onLog;

  _LoggingServer({
    required void Function(RpcMetric<RpcLoggerMetric>) onLog,
  }) : _onLog = onLog;

  @override
  Future<RpcNull> logMetric(RpcMetric<RpcLoggerMetric> metric) async {
    _onLog(metric);
    return RpcNull();
  }

  @override
  ClientStreamingBidiStream<RpcMetric<RpcLoggerMetric>> logsStream() {
    return BidiStreamGenerator<RpcMetric<RpcLoggerMetric>, RpcNull>(
      (userLogsStream) async* {
        await for (final log in userLogsStream) {
          _onLog(log);
        }
        yield RpcNull();
      },
    ).createClientStreaming();
  }
}

class _TracingServer extends _RpcTracingContract {
  final void Function(RpcMetric<RpcTraceMetric>) _onTraceEvent;

  _TracingServer({
    required void Function(RpcMetric<RpcTraceMetric>) onTraceEvent,
  }) : _onTraceEvent = onTraceEvent;

  @override
  Future<RpcNull> traceEvent(RpcMetric<RpcTraceMetric> event) async {
    _onTraceEvent(event);
    return RpcNull();
  }
}

class _ClientManagementServer extends _RpcClientManagementContract {
  final void Function(RpcClientIdentity) _onRegisterClient;
  final Future<bool> Function() _onPing;

  _ClientManagementServer({
    required void Function(RpcClientIdentity) onRegisterClient,
    required Future<bool> Function() onPing,
  })  : _onRegisterClient = onRegisterClient,
        _onPing = onPing;

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
