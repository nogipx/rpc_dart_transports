// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:uuid/uuid.dart';

import 'package:rpc_dart/rpc_dart.dart';

import '../router_models.dart';
import '../interfaces/router_interface.dart';
import '../router_stats.dart';

/// Основная реализация роутера
///
/// Обеспечивает stateless маршрутизацию сообщений между различными
/// клиентами через двунаправленные стримы. Роутер не хранит состояние
/// и минимизирует потребление ресурсов.
final class RouterResponderImpl implements IRouterContract {
  /// Активные клиентские соединения: clientId -> StreamController
  final Map<String, StreamController<RouterMessage>> _clientStreams = {};

  /// Информация о клиентах: clientId -> RouterClientInfo
  final Map<String, RouterClientInfo> _clientsInfo = {};

  /// Активные запросы: requestId -> Completer
  final Map<String, Completer<RouterMessage>> _activeRequests = {};

  /// Дистрибьютор для системных событий роутера
  late final StreamDistributor<RouterEvent> _eventDistributor;

  /// UUID генератор для создания уникальных ID
  static const Uuid _uuid = Uuid();

  /// Логгер для отладки роутера
  final RpcLogger? _logger;

  /// Время старта роутера
  final DateTime _startTime = DateTime.now();

  RouterResponderImpl({RpcLogger? logger}) : _logger = logger?.child('RouterResponder') {
    // Инициализируем дистрибьютор событий
    _eventDistributor = StreamDistributor<RouterEvent>(
      config: StreamDistributorConfig(
        enableAutoCleanup: true,
        inactivityThreshold: Duration(minutes: 5),
        cleanupInterval: Duration(minutes: 1),
        autoRemoveOnCancel: true,
      ),
      logger: _logger?.child('EventDistributor'),
    );

    _logger?.info('RouterResponder создан');
  }

  // === IRouter implementation ===

  @override
  RouterStats get stats => RouterStats(
        activeClients: _clientStreams.length,
        clientIds: _clientStreams.keys.toList(),
        startTime: _startTime,
      );

  @override
  Future<void> dispose() async {
    _logger?.info('Закрытие роутера...');

    // Закрываем все клиентские соединения
    final clientIds = _clientStreams.keys.toList();
    for (final clientId in clientIds) {
      disconnectClient(clientId);
    }

    // Закрываем дистрибьютор событий
    await _eventDistributor.dispose();

    _logger?.info('Роутер закрыт');
  }

  // === IRouterClientManager implementation ===

  @override
  RouterClientInfo? getClientInfo(String clientId) {
    return _clientsInfo[clientId];
  }

  @override
  List<RouterClientInfo> getActiveClients({
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) {
    var clients = _clientsInfo.values.where(
        (client) => client.status == ClientStatus.online || client.status == ClientStatus.idle);

    // Применяем фильтры если есть
    if (groups != null && groups.isNotEmpty) {
      clients = clients.where((client) => groups.any((group) => client.groups.contains(group)));
    }

    if (metadata != null && metadata.isNotEmpty) {
      clients = clients.where((client) {
        return metadata.entries.every((entry) => client.metadata[entry.key] == entry.value);
      });
    }

    return clients.toList();
  }

  @override
  bool isClientOnline(String clientId) {
    final clientInfo = _clientsInfo[clientId];
    return clientInfo != null &&
        (clientInfo.status == ClientStatus.online || clientInfo.status == ClientStatus.idle);
  }

  @override
  void disconnectClient(String clientId, {String? reason}) {
    final streamController = _clientStreams.remove(clientId);
    final clientInfo = _clientsInfo.remove(clientId);

    if (streamController != null) {
      streamController.close();
      _logger?.info('Клиент отключен: $clientId${reason != null ? ' ($reason)' : ''}');

      // Уведомляем подписчиков об отключении клиента
      emitEvent(RouterEvent.clientDisconnected(
        clientId: clientId,
        reason: reason,
      ));
    }
  }

  @override
  void updateClientActivity(String clientId) {
    final clientInfo = _clientsInfo[clientId];
    if (clientInfo != null) {
      _clientsInfo[clientId] = clientInfo.copyWith(
        lastActivity: DateTime.now(),
        status: ClientStatus.online,
      );
    }
  }

  @override
  bool updateClientMetadata(String clientId, Map<String, dynamic> metadata) {
    final clientInfo = _clientsInfo[clientId];
    if (clientInfo != null) {
      _clientsInfo[clientId] = clientInfo.copyWith(metadata: metadata);

      emitEvent(RouterEvent.clientCapabilitiesUpdated(
        clientId: clientId,
        metadata: metadata,
      ));

      _logger?.debug('Метаданные клиента $clientId обновлены');
      return true;
    }
    return false;
  }

  // === IRouterMessageSender implementation ===

  @override
  bool sendToClient(String clientId, RouterMessage message) {
    final streamController = _clientStreams[clientId];
    if (streamController != null && !streamController.isClosed) {
      streamController.add(message);
      updateClientActivity(clientId);
      _logger?.debug('Сообщение отправлено клиенту $clientId: ${message.type}');
      return true;
    } else {
      _logger?.warning('Клиент $clientId не найден или отключен');
      return false;
    }
  }

  @override
  int sendToGroup(String groupName, RouterMessage message, {String? excludeClientId}) {
    int sentCount = 0;

    for (final clientInfo in _clientsInfo.values) {
      if (clientInfo.groups.contains(groupName) && clientInfo.clientId != excludeClientId) {
        if (sendToClient(clientInfo.clientId, message)) {
          sentCount++;
        }
      }
    }

    _logger?.debug('Multicast сообщение отправлено группе $groupName: $sentCount получателей');
    return sentCount;
  }

  @override
  int sendBroadcast(RouterMessage message, {String? excludeClientId}) {
    int sentCount = 0;

    for (final clientId in _clientStreams.keys) {
      if (clientId != excludeClientId) {
        if (sendToClient(clientId, message)) {
          sentCount++;
        }
      }
    }

    _logger?.debug('Broadcast сообщение отправлено: $sentCount получателей');
    return sentCount;
  }

  @override
  void handleRequest(RouterMessage message, String senderId) {
    final targetId = message.targetId;
    final requestId = message.payload?['requestId'] as String?;

    if (targetId == null || requestId == null) {
      _logger?.warning('Request сообщение без targetId или requestId от $senderId');
      return;
    }

    // Пересылаем запрос целевому клиенту
    final forwardedMessage = message.copyWith(senderId: senderId);
    sendToClient(targetId, forwardedMessage);

    // Сохраняем информацию о запросе для таймаута
    final timeout = message.payload?['timeoutMs'] as int?;
    if (timeout != null) {
      Timer(Duration(milliseconds: timeout), () {
        if (_activeRequests.containsKey(requestId)) {
          _activeRequests.remove(requestId);

          // Отправляем ошибку таймаута отправителю
          final timeoutResponse = RouterMessage.response(
            targetId: senderId,
            requestId: requestId,
            payload: {},
            senderId: 'router',
            success: false,
            errorMessage: 'Request timeout',
          );
          sendToClient(senderId, timeoutResponse);
        }
      });
    }

    _logger?.debug('Request переслан: $senderId -> $targetId (requestId: $requestId)');
  }

  @override
  void handleResponse(RouterMessage message, String senderId) {
    final targetId = message.targetId;
    if (targetId == null) {
      _logger?.warning('Response сообщение без targetId от $senderId');
      return;
    }

    // Пересылаем ответ целевому клиенту
    final forwardedMessage = message.copyWith(senderId: senderId);
    sendToClient(targetId, forwardedMessage);

    _logger?.debug('Response переслан: $senderId -> $targetId');
  }

  // === IRouterEventManager implementation ===

  @override
  Stream<RouterEvent> subscribeToEvents() {
    final subscriberId = 'events_${_uuid.v4()}';
    return _eventDistributor.createClientStreamWithId(
      subscriberId,
      onCancel: () {
        _logger?.debug('Отмена подписки на события: $subscriberId');
      },
    );
  }

  @override
  void emitEvent(RouterEvent event) {
    _eventDistributor.publish(event);
    _logger?.debug('Событие роутера отправлено: ${event.type}');
  }

  // === IRouterContract implementation ===

  @override
  Future<bool> registerClient(
    String clientId,
    StreamController<RouterMessage> streamController, {
    String? clientName,
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Сохраняем стрим клиента
      _clientStreams[clientId] = streamController;

      final now = DateTime.now();
      final clientInfo = RouterClientInfo(
        clientId: clientId,
        clientName: clientName,
        groups: groups ?? [],
        connectedAt: now,
        lastActivity: now,
        metadata: metadata ?? {},
        status: ClientStatus.online,
      );

      _clientsInfo[clientId] = clientInfo;

      _logger?.info('Клиент зарегистрирован: $clientId (${clientInfo.clientName})');

      // Уведомляем подписчиков о новом клиенте
      emitEvent(RouterEvent.clientConnected(
        clientId: clientId,
        clientName: clientInfo.clientName,
        capabilities: clientInfo.groups,
      ));

      return true;
    } catch (e, stackTrace) {
      _logger?.error('Ошибка регистрации клиента: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  @override
  void unregisterClient(String clientId, {String? reason}) {
    disconnectClient(clientId, reason: reason);
  }

  @override
  void handleIncomingMessage(RouterMessage message, String senderId) {
    // Обновляем активность клиента
    updateClientActivity(senderId);

    switch (message.type) {
      case RouterMessageType.unicast:
        _handleUnicast(message, senderId);
        break;
      case RouterMessageType.multicast:
        _handleMulticast(message, senderId);
        break;
      case RouterMessageType.broadcast:
        _handleBroadcast(message, senderId);
        break;
      case RouterMessageType.request:
        handleRequest(message, senderId);
        break;
      case RouterMessageType.response:
        handleResponse(message, senderId);
        break;
      case RouterMessageType.heartbeat:
        _handleHeartbeat(message, senderId);
        break;
      case RouterMessageType.updateMetadata:
        _handleUpdateMetadata(message, senderId);
        break;
      case RouterMessageType.error:
        _logger?.warning('Ошибка от клиента $senderId: ${message.errorMessage}');
        break;
    }
  }

  // === Вспомогательные методы ===

  /// Обрабатывает unicast сообщение
  void _handleUnicast(RouterMessage message, String senderId) {
    final targetId = message.targetId;
    if (targetId == null) {
      _logger?.warning('Unicast сообщение без targetId от $senderId');
      return;
    }

    final forwardedMessage = message.copyWith(senderId: senderId);
    final sent = sendToClient(targetId, forwardedMessage);

    if (!sent) {
      // Отправляем error сообщение отправителю если целевой клиент не найден
      final errorMessage = RouterMessage(
        type: RouterMessageType.error,
        targetId: senderId,
        errorMessage: 'Клиент $targetId не найден или отключен',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      sendToClient(senderId, errorMessage);
      _logger?.warning('Unicast не доставлен - клиент $targetId не найден');
    } else {
      _logger?.debug('Unicast переслан: $senderId -> $targetId');
    }
  }

  /// Обрабатывает multicast сообщение
  void _handleMulticast(RouterMessage message, String senderId) {
    final groupName = message.groupName;
    if (groupName == null) {
      _logger?.warning('Multicast сообщение без groupName от $senderId');
      return;
    }

    final forwardedMessage = message.copyWith(senderId: senderId);
    final sentCount = sendToGroup(groupName, forwardedMessage, excludeClientId: senderId);

    _logger?.debug('Multicast переслан: $senderId -> группа $groupName ($sentCount получателей)');
  }

  /// Обрабатывает broadcast сообщение
  void _handleBroadcast(RouterMessage message, String senderId) {
    final forwardedMessage = message.copyWith(senderId: senderId);
    final sentCount = sendBroadcast(forwardedMessage, excludeClientId: senderId);

    _logger?.debug('Broadcast переслан: $senderId -> все ($sentCount получателей)');
  }

  /// Обрабатывает heartbeat сообщение
  void _handleHeartbeat(RouterMessage message, String senderId) {
    _logger?.debug('Heartbeat от клиента: $senderId');
    updateClientActivity(senderId);
  }

  /// Обрабатывает обновление метаданных клиента
  void _handleUpdateMetadata(RouterMessage message, String senderId) {
    _logger?.debug('Обновление метаданных от клиента: $senderId');

    final metadata = message.payload?['metadata'] as Map<String, dynamic>?;
    if (metadata == null) {
      _logger?.warning('Сообщение updateMetadata без метаданных от клиента: $senderId');
      return;
    }

    final success = updateClientMetadata(senderId, metadata);
    if (success) {
      _logger?.info('Метаданные обновлены для клиента: $senderId');
    } else {
      _logger?.warning('Не удалось обновить метаданные для клиента: $senderId');
    }
  }

  /// Генерирует уникальный ID клиента
  String generateClientId() {
    return 'client_${_uuid.v4()}';
  }

  @override
  bool replaceClientStream(String clientId, StreamController<RouterMessage> newStreamController) {
    if (!_clientsInfo.containsKey(clientId)) {
      return false; // Клиент не зарегистрирован
    }

    // Закрываем старый стрим если есть
    final oldStream = _clientStreams[clientId];
    oldStream?.close();

    // Устанавливаем новый стрим
    _clientStreams[clientId] = newStreamController;

    _logger?.debug('Стрим заменен для клиента: $clientId');
    return true;
  }

  @override
  void removeClientStream(String clientId) {
    final streamController = _clientStreams.remove(clientId);
    if (streamController != null) {
      streamController.close();
      _logger?.debug('Стрим удален для клиента: $clientId');
    }
  }
}
