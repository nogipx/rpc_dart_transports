part of '_contract.dart';

/// Клиентская реализация контракта диагностического сервиса
final class _DiagnosticClientContract extends _RpcDiagnosticServiceContract {
  final RpcEndpoint _endpoint;

  _DiagnosticClientContract(this._endpoint)
      : super(
          metrics: _MetricsClient(_endpoint),
          logging: _LoggingClient(_endpoint),
          tracing: _TracingClient(_endpoint),
          clientManagement: _ClientManagementClient(_endpoint),
        ) {
    _endpoint.registerServiceContract(this);
  }
}
