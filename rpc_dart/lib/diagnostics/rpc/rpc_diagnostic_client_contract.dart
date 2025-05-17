// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_contract.dart';

/// Клиентская реализация контракта диагностического сервиса
final class RpcDiagnosticClientContract extends _RpcDiagnosticServiceContract {
  final RpcEndpoint _endpoint;

  RpcDiagnosticClientContract(this._endpoint)
      : super(
          metrics: _MetricsClient(_endpoint),
          logging: _LoggingClient(_endpoint),
          tracing: _TracingClient(_endpoint),
          clientManagement: _ClientManagementClient(_endpoint),
        ) {
    _endpoint.registerServiceContract(this);
  }
}
