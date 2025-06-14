// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import '../router_models.dart';
import '../models/_index.dart';
import '../interfaces/router_interface.dart';

/// Обработчик прямых RPC методов роутера
///
/// Отвечает за обработку unary методов: register, ping, getOnlineClients.
/// Выделен из RouterResponderContract для улучшения читаемости.
class RouterRpcHandler {
  final IRouterContract _routerImpl;
  final RpcLogger? _logger;

  RouterRpcHandler({
    required IRouterContract routerImpl,
    RpcLogger? logger,
  })  : _routerImpl = routerImpl,
        _logger = logger?.child('RpcHandler');

  /// Регистрирует нового клиента
  Future<RouterRegisterResponse> handleRegister(
    RouterRegisterRequest request, {
    RpcContext? context,
  }) async {
    try {
      final clientId = _routerImpl.generateClientId();

      _logger?.info('Предварительная регистрация клиента: $clientId (${request.clientName})');

      // Создаем временный контроллер для начальной регистрации
      // Он будет заменен при установке P2P соединения
      final tempController = StreamController<RouterMessage>();

      final success = await _routerImpl.registerClient(
        clientId,
        tempController,
        clientName: request.clientName,
        groups: request.groups,
        metadata: request.metadata,
      );

      if (!success) {
        await tempController.close();
        return RouterRegisterResponse(
          clientId: '',
          success: false,
          errorMessage: 'Ошибка регистрации клиента в роутере',
        );
      }

      _logger?.info('Клиент предварительно зарегистрирован: $clientId, ожидается P2P соединение');

      return RouterRegisterResponse(
        clientId: clientId,
        success: success,
      );
    } catch (e, stackTrace) {
      _logger?.error('Ошибка регистрации клиента: $e', error: e, stackTrace: stackTrace);
      return RouterRegisterResponse(
        clientId: '',
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Обрабатывает ping запрос
  Future<RouterPongResponse> handlePing(
    RpcInt clientTimestamp, {
    RpcContext? context,
  }) async {
    final serverTimestamp = DateTime.now().millisecondsSinceEpoch;

    _logger?.debug('Ping получен, timestamp: ${clientTimestamp.value}');

    return RouterPongResponse(
      timestamp: clientTimestamp.value,
      serverTimestamp: serverTimestamp,
    );
  }

  /// Получает список онлайн клиентов
  Future<RouterClientsList> handleGetOnlineClients(
    RouterGetOnlineClientsRequest request, {
    RpcContext? context,
  }) async {
    _logger?.info('Запрос списка онлайн клиентов');
    _logger?.debug('Фильтры: groups=${request.groups}, metadata=${request.metadata}');

    try {
      final clients = _routerImpl.getActiveClients(
        groups: request.groups,
        metadata: request.metadata,
      );

      _logger?.info('Найдено клиентов: ${clients.length}');
      for (final client in clients) {
        _logger?.debug('  - ${client.clientName} (${client.clientId}) в группах: ${client.groups}');
      }

      return RouterClientsList(clients);
    } catch (e, stackTrace) {
      _logger?.error('Ошибка получения списка клиентов: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
