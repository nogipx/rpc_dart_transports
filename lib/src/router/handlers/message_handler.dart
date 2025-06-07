// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import '../router_models.dart';
import '../interfaces/router_interface.dart';

/// Обработчик сообщений роутера
///
/// Содержит всю логику маршрутизации и обработки различных типов сообщений.
/// Выделен из основного RouterResponderImpl для улучшения читаемости.
class RouterMessageHandler {
  final IRouterClientManager _clientManager;
  final IRouterMessageSender _messageSender;
  final RpcLogger? _logger;

  /// Активные запросы: requestId -> Completer
  final Map<String, Completer<RouterMessage>> _activeRequests = {};

  RouterMessageHandler({
    required IRouterClientManager clientManager,
    required IRouterMessageSender messageSender,
    RpcLogger? logger,
  })  : _clientManager = clientManager,
        _messageSender = messageSender,
        _logger = logger?.child('MessageHandler');

  /// Обрабатывает входящее сообщение от клиента
  void handleIncomingMessage(RouterMessage message, String senderId) {
    // Обновляем активность клиента
    _clientManager.updateClientActivity(senderId);

    switch (message.type) {
      case RouterMessageType.unicast:
        handleUnicast(message, senderId);
        break;
      case RouterMessageType.multicast:
        handleMulticast(message, senderId);
        break;
      case RouterMessageType.broadcast:
        handleBroadcast(message, senderId);
        break;
      case RouterMessageType.request:
        handleRequest(message, senderId);
        break;
      case RouterMessageType.response:
        handleResponse(message, senderId);
        break;
      case RouterMessageType.heartbeat:
        handleHeartbeat(message, senderId);
        break;
      case RouterMessageType.updateMetadata:
        handleUpdateMetadata(message, senderId);
        break;
      case RouterMessageType.error:
        _logger
            ?.warning('Ошибка от клиента $senderId: ${message.errorMessage}');
        break;
    }
  }

  /// Обрабатывает unicast сообщение
  void handleUnicast(RouterMessage message, String senderId) {
    final targetId = message.targetId;
    if (targetId == null) {
      _logger?.warning('Unicast сообщение без targetId от $senderId');
      return;
    }

    final forwardedMessage = message.copyWith(senderId: senderId);
    final sent = _messageSender.sendToClient(targetId, forwardedMessage);

    if (!sent) {
      // Отправляем error сообщение отправителю если целевой клиент не найден
      final errorMessage = RouterMessage(
        type: RouterMessageType.error,
        targetId: senderId,
        errorMessage: 'Клиент $targetId не найден или отключен',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _messageSender.sendToClient(senderId, errorMessage);
      _logger?.warning('Unicast не доставлен - клиент $targetId не найден');
    } else {
      _logger?.debug('Unicast переслан: $senderId -> $targetId');
    }
  }

  /// Обрабатывает multicast сообщение
  void handleMulticast(RouterMessage message, String senderId) {
    final groupName = message.groupName;
    if (groupName == null) {
      _logger?.warning('Multicast сообщение без groupName от $senderId');
      return;
    }

    final forwardedMessage = message.copyWith(senderId: senderId);
    final sentCount = _messageSender.sendToGroup(groupName, forwardedMessage,
        excludeClientId: senderId);

    _logger?.debug(
        'Multicast переслан: $senderId -> группа $groupName ($sentCount получателей)');
  }

  /// Обрабатывает broadcast сообщение
  void handleBroadcast(RouterMessage message, String senderId) {
    final forwardedMessage = message.copyWith(senderId: senderId);
    final sentCount = _messageSender.sendBroadcast(forwardedMessage,
        excludeClientId: senderId);

    _logger?.debug(
        'Broadcast переслан: $senderId -> все ($sentCount получателей)');
  }

  /// Обрабатывает request сообщение
  void handleRequest(RouterMessage message, String senderId) {
    final targetId = message.targetId;
    final requestId = message.payload?['requestId'] as String?;

    if (targetId == null || requestId == null) {
      _logger?.warning(
          'Request сообщение без targetId или requestId от $senderId');
      return;
    }

    // Пересылаем запрос целевому клиенту
    final forwardedMessage = message.copyWith(senderId: senderId);
    _messageSender.sendToClient(targetId, forwardedMessage);

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
          _messageSender.sendToClient(senderId, timeoutResponse);
        }
      });
    }

    _logger?.debug(
        'Request переслан: $senderId -> $targetId (requestId: $requestId)');
  }

  /// Обрабатывает response сообщение
  void handleResponse(RouterMessage message, String senderId) {
    final targetId = message.targetId;
    if (targetId == null) {
      _logger?.warning('Response сообщение без targetId от $senderId');
      return;
    }

    // Пересылаем ответ целевому клиенту
    final forwardedMessage = message.copyWith(senderId: senderId);
    _messageSender.sendToClient(targetId, forwardedMessage);

    _logger?.debug('Response переслан: $senderId -> $targetId');
  }

  /// Обрабатывает heartbeat сообщение
  void handleHeartbeat(RouterMessage message, String senderId) {
    _logger?.debug('Heartbeat от клиента: $senderId');
    _clientManager.updateClientActivity(senderId);
  }

  /// Обрабатывает обновление метаданных клиента
  void handleUpdateMetadata(RouterMessage message, String senderId) {
    _logger?.debug('Обновление метаданных от клиента: $senderId');

    final metadata = message.payload?['metadata'] as Map<String, dynamic>?;
    if (metadata == null) {
      _logger?.warning(
          'Сообщение updateMetadata без метаданных от клиента: $senderId');
      return;
    }

    final success = _clientManager.updateClientMetadata(senderId, metadata);
    if (success) {
      _logger?.info('Метаданные обновлены для клиента: $senderId');
    } else {
      _logger?.warning('Не удалось обновить метаданные для клиента: $senderId');
    }
  }

  /// Очищает ресурсы обработчика
  void dispose() {
    // Отменяем все активные запросы
    _activeRequests.clear();
    _logger?.debug('MessageHandler disposed');
  }
}
