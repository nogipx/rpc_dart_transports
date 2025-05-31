// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import '../router_models.dart';
import '../models/_index.dart';

/// RPC клиент роутера
///
/// Отвечает за прямые RPC вызовы к роутеру (register, ping, getOnlineClients).
/// Выделен из RouterClient для улучшения читаемости.
class RouterRpcClient {
  final RpcCallerEndpoint _callerEndpoint;
  final String _serviceName;
  final RpcLogger? _logger;

  /// Получает доступ к калер endpoint для других компонентов
  RpcCallerEndpoint get callerEndpoint => _callerEndpoint;

  RouterRpcClient({
    required RpcCallerEndpoint callerEndpoint,
    required String serviceName,
    RpcLogger? logger,
  })  : _callerEndpoint = callerEndpoint,
        _serviceName = serviceName,
        _logger = logger?.child('RpcClient');

  /// Регистрирует клиента в роутере
  Future<String> register({
    String? clientName,
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) async {
    _logger?.info('Регистрация клиента: $clientName');

    final request = RouterRegisterRequest(
      clientName: clientName,
      groups: groups,
      metadata: metadata,
    );

    final response =
        await _callerEndpoint.unaryRequest<RouterRegisterRequest, RouterRegisterResponse>(
      serviceName: _serviceName,
      methodName: 'register',
      requestCodec: RpcCodec<RouterRegisterRequest>((json) => RouterRegisterRequest.fromJson(json)),
      responseCodec:
          RpcCodec<RouterRegisterResponse>((json) => RouterRegisterResponse.fromJson(json)),
      request: request,
    );

    if (!response.success) {
      throw Exception('Ошибка регистрации: ${response.errorMessage}');
    }

    _logger?.info('Клиент зарегистрирован с ID: ${response.clientId}');
    return response.clientId;
  }

  /// Пингует роутер
  Future<Duration> ping() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final response = await _callerEndpoint.unaryRequest<RpcInt, RouterPongResponse>(
      serviceName: _serviceName,
      methodName: 'ping',
      requestCodec: RpcCodec<RpcInt>((json) => RpcInt.fromJson(json)),
      responseCodec: RpcCodec<RouterPongResponse>((json) => RouterPongResponse.fromJson(json)),
      request: RpcInt(timestamp),
    );

    final latency = Duration(milliseconds: response.serverTimestamp - timestamp);
    _logger?.debug('Ping: ${latency.inMilliseconds}ms');

    return latency;
  }

  /// Получает список онлайн клиентов
  Future<List<RouterClientInfo>> getOnlineClients({
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) async {
    _logger?.debug('Запрос списка онлайн клиентов (фильтры: groups=$groups, metadata=$metadata)');

    try {
      final request = RouterGetOnlineClientsRequest(
        groups: groups,
        metadata: metadata,
      );

      _logger?.debug('Отправляем unary запрос getOnlineClients');
      final response =
          await _callerEndpoint.unaryRequest<RouterGetOnlineClientsRequest, RouterClientsList>(
        serviceName: _serviceName,
        methodName: 'getOnlineClients',
        requestCodec: RpcCodec<RouterGetOnlineClientsRequest>(
            (json) => RouterGetOnlineClientsRequest.fromJson(json)),
        responseCodec: RpcCodec<RouterClientsList>((json) => RouterClientsList.fromJson(json)),
        request: request,
      );

      _logger?.info('Получен список из ${response.clients.length} клиентов');
      for (final client in response.clients) {
        _logger?.debug('  - ${client.clientName} (${client.clientId}) в группах: ${client.groups}');
      }

      return response.clients;
    } catch (e, stackTrace) {
      _logger?.error('Ошибка получения списка клиентов: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
