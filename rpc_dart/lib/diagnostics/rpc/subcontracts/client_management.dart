// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_contract.dart';

/// Контракт для управления клиентами
abstract class _RpcClientManagementContract extends OldRpcServiceContract {
  // Константы для имен методов
  static const methodRegisterClient = 'registerClient';
  static const methodPing = 'ping';

  _RpcClientManagementContract() : super('client_management');

  @override
  void setup() {
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

  /// Метод для регистрации клиента в диагностической системе
  Future<RpcNull> registerClient(RpcClientIdentity clientIdentity);

  /// Метод для проверки доступности диагностического сервера
  Future<RpcBool> ping(RpcNull _);
}

class _ClientManagementClient extends _RpcClientManagementContract {
  final RpcEndpoint _endpoint;

  _ClientManagementClient(this._endpoint);

  @override
  Future<RpcNull> registerClient(RpcClientIdentity clientIdentity) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: _RpcClientManagementContract.methodRegisterClient,
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
          methodName: _RpcClientManagementContract.methodPing,
        )
        .call(
          request: _,
          responseParser: RpcBool.fromJson,
        );
  }
}
