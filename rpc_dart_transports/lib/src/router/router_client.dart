// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'router_models.dart';
import 'connections/rpc_client.dart';
import 'connections/p2p_connection.dart';
import 'connections/event_subscription.dart';

/// Программный интерфейс для работы с роутером
///
/// Предоставляет удобный API для:
/// - Регистрации в роутере
/// - Прямых запросов к роутеру (ping, getClients, etc.)
/// - P2P сообщений между клиентами
/// - Подписки на события роутера
class RouterClient {
  static const String _serviceName = 'router';

  /// ID клиента, полученный при регистрации
  String? _clientId;

  /// RPC клиент для прямых вызовов
  late final RouterRpcClient _rpcClient;

  /// P2P соединение
  RouterP2PConnection? _p2pConnection;

  /// Подписка на события
  late final RouterEventSubscription _eventSubscription;

  final RpcLogger? _logger;

  RouterClient({
    required RpcCallerEndpoint callerEndpoint,
    RpcLogger? logger,
    Duration heartbeatInterval = const Duration(seconds: 20),
  }) : _logger = logger?.child('RouterClient') {
    // Инициализируем компоненты
    _rpcClient = RouterRpcClient(
      callerEndpoint: callerEndpoint,
      serviceName: _serviceName,
      logger: _logger,
    );

    _eventSubscription = RouterEventSubscription(
      callerEndpoint: callerEndpoint,
      serviceName: _serviceName,
      logger: _logger,
    );
  }

  /// Получает ID клиента (если зарегистрирован)
  String? get clientId => _clientId;

  /// Проверяет, зарегистрирован ли клиент
  bool get isRegistered => _clientId != null;

  /// Стрим событий роутера
  Stream<RouterEvent> get events => _eventSubscription.events;

  // === ПРЯМЫЕ RPC ЗАПРОСЫ К РОУТЕРУ ===

  /// Регистрирует клиента в роутере
  Future<String> register({
    String? clientName,
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) async {
    _clientId = await _rpcClient.register(
      clientName: clientName,
      groups: groups,
      metadata: metadata,
    );
    return _clientId!;
  }

  /// Пингует роутер
  Future<Duration> ping() async {
    return _rpcClient.ping();
  }

  /// Получает список онлайн клиентов
  Future<List<RouterClientInfo>> getOnlineClients({
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) async {
    return _rpcClient.getOnlineClients(
      groups: groups,
      metadata: metadata,
    );
  }

  /// Обновляет метаданные клиента
  Future<bool> updateMetadata(Map<String, dynamic> metadata) async {
    if (!isRegistered) {
      throw StateError('Клиент должен быть зарегистрирован');
    }

    if (_p2pConnection != null && _p2pConnection!.isInitialized) {
      final updateMessage = RouterMessage.updateMetadata(
        metadata: metadata,
        senderId: _clientId,
      );

      _p2pConnection!.sendMessage(updateMessage);
      _logger?.debug('Обновление метаданных отправлено через P2P: $metadata');
      return true;
    } else {
      _logger?.warning(
          'P2P не инициализировано, updateMetadata недоступен. Используйте initializeP2P()');
      return false;
    }
  }

  /// Отправляет heartbeat
  Future<void> heartbeat() async {
    if (!isRegistered) {
      throw StateError('Клиент должен быть зарегистрирован');
    }

    if (_p2pConnection != null && _p2pConnection!.isInitialized) {
      _p2pConnection!.sendHeartbeat();
    } else {
      _logger?.warning(
          'P2P не инициализировано, heartbeat недоступен. Используйте initializeP2P()');
    }
  }

  // === P2P СООБЩЕНИЯ ===

  /// Инициализирует P2P соединение
  Future<void> initializeP2P({
    void Function(RouterMessage message)? onP2PMessage,
    bool enableAutoHeartbeat = true,
    bool filterRouterHeartbeats = true,
  }) async {
    if (_clientId == null) {
      throw StateError(
          'Клиент должен быть зарегистрирован перед инициализацией P2P');
    }

    _logger?.info('Инициализация P2P соединения для клиента: $_clientId');

    // Создаем новое P2P соединение
    _p2pConnection = RouterP2PConnection(
      callerEndpoint: _rpcClient.callerEndpoint,
      serviceName: _serviceName,
      clientId: _clientId,
      logger: _logger,
    );

    await _p2pConnection!.initialize(
      onP2PMessage: onP2PMessage,
      enableAutoHeartbeat: enableAutoHeartbeat,
      filterRouterHeartbeats: filterRouterHeartbeats,
    );
  }

  /// Отправляет unicast сообщение
  Future<void> sendUnicast(
      String targetId, Map<String, dynamic> payload) async {
    _ensureP2PInitialized();

    final message = RouterMessage.unicast(
      targetId: targetId,
      payload: payload,
      senderId: _clientId,
    );

    _p2pConnection!.sendMessage(message);
    _logger?.debug('Отправлен unicast: $_clientId -> $targetId');
  }

  /// Отправляет multicast сообщение
  Future<void> sendMulticast(
      String groupName, Map<String, dynamic> payload) async {
    _logger?.debug(
        'Отправляем multicast в группу "$groupName" от клиента $_clientId');
    _ensureP2PInitialized();

    final message = RouterMessage.multicast(
      groupName: groupName,
      payload: payload,
      senderId: _clientId,
    );

    _p2pConnection!.sendMessage(message);
    _logger?.debug(
        'Multicast сообщение отправлено: $_clientId -> группа $groupName');
  }

  /// Отправляет broadcast сообщение
  Future<void> sendBroadcast(Map<String, dynamic> payload) async {
    _ensureP2PInitialized();

    final message = RouterMessage.broadcast(
      payload: payload,
      senderId: _clientId,
    );

    _p2pConnection!.sendMessage(message);
    _logger?.debug('Отправлен broadcast от $_clientId');
  }

  /// Отправляет произвольное P2P сообщение
  Future<void> sendP2PMessage(RouterMessage message) async {
    _ensureP2PInitialized();
    _p2pConnection!.sendMessage(message);
    _logger?.debug('Отправлено P2P сообщение: ${message.type}');
  }

  /// Отправляет request с ожиданием response
  Future<Map<String, dynamic>> sendRequest(
    String targetId,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _ensureP2PInitialized();

    return _p2pConnection!.sendRequest(
      targetId,
      payload,
      timeout: timeout,
    );
  }

  // === СОБЫТИЯ РОУТЕРА ===

  /// Подписывается на события роутера
  Future<void> subscribeToEvents() async {
    await _eventSubscription.subscribe();
  }

  /// Отписывается от событий роутера
  Future<void> unsubscribeFromEvents() async {
    await _eventSubscription.unsubscribe();
  }

  // === ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ===

  void _ensureP2PInitialized() {
    if (_p2pConnection == null || !_p2pConnection!.isInitialized) {
      _logger?.error('P2P соединение не инициализировано');
      throw StateError(
          'P2P соединение не инициализировано. Вызовите initializeP2P()');
    }
  }

  /// Закрывает все соединения
  Future<void> dispose() async {
    _logger?.info('Закрытие RouterClient...');

    // Закрываем P2P соединение
    if (_p2pConnection != null) {
      await _p2pConnection!.dispose();
      _p2pConnection = null;
    }

    // Отписываемся от событий
    await _eventSubscription.dispose();

    _logger?.info('RouterClient закрыт');
  }
}

/// Расширения для RouterMessage для удобного создания
extension RouterMessageExtensions on RouterMessage {
  /// Создает request сообщение
  static RouterMessage request({
    required String targetId,
    required String requestId,
    required Map<String, dynamic> payload,
    String? senderId,
    int? timeoutMs,
  }) {
    return RouterMessage(
      type: RouterMessageType.request,
      senderId: senderId,
      targetId: targetId,
      payload: {
        'requestId': requestId,
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
        ...payload,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает response сообщение
  static RouterMessage response({
    required String targetId,
    required String requestId,
    required Map<String, dynamic> payload,
    String? senderId,
    bool success = true,
    String? errorMessage,
  }) {
    return RouterMessage(
      type: RouterMessageType.response,
      senderId: senderId,
      targetId: targetId,
      payload: {
        'requestId': requestId,
        ...payload,
      },
      success: success,
      errorMessage: errorMessage,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
