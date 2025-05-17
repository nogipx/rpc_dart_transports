// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async' show Timer;
import 'dart:math' show Random;

import 'package:rpc_dart/diagnostics.dart';
import 'package:rpc_dart/diagnostics/rpc_diagnostic_service.dart';
import 'package:rpc_dart/rpc_dart.dart';

part 'subcontracts/metrics.dart';
part 'subcontracts/logging.dart';
part 'subcontracts/tracing.dart';
part 'subcontracts/client_management.dart';

part 'diagnostic_client_contract.dart';
part 'diagnostic_server_contract.dart';

part '../i_rpc_diagnostic_service.dart';
part '../rpc_diagnostic_client.dart';

/// Базовый контракт диагностического сервиса
///
/// Объединяет все подконтракты в один интерфейс
abstract base class _RpcDiagnosticServiceContract extends RpcServiceContract {
  final _RpcMetricsContract metrics;
  final _RpcLoggingContract logging;
  final _RpcTracingContract tracing;
  final _RpcClientManagementContract clientManagement;

  _RpcDiagnosticServiceContract({
    required this.metrics,
    required this.logging,
    required this.tracing,
    required this.clientManagement,
  }) : super('rpc_diagnostics');

  @override
  void setup() {
    addSubContract(metrics);
    addSubContract(logging);
    addSubContract(tracing);
    addSubContract(clientManagement);

    super.setup();
  }
}
