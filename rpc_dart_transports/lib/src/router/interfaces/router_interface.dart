// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import '../router_models.dart';
import '../router_stats.dart';

/// Базовый интерфейс для всех роутеров
abstract interface class IRouter {
  /// Статистика роутера
  RouterStats get stats;

  /// Освободить ресурсы роутера
  Future<void> dispose();
}

/// Интерфейс для управления клиентами роутера
abstract interface class IRouterClientManager {
  /// Получить информацию о клиенте по ID
  RouterClientInfo? getClientInfo(String clientId);

  /// Получить список всех активных клиентов
  List<RouterClientInfo> getActiveClients({
    List<String>? groups,
    Map<String, dynamic>? metadata,
  });

  /// Проверить онлайн ли клиент
  bool isClientOnline(String clientId);

  /// Отключить клиента
  void disconnectClient(String clientId, {String? reason});

  /// Обновить время последней активности клиента
  void updateClientActivity(String clientId);

  /// Обновить метаданные клиента
  bool updateClientMetadata(String clientId, Map<String, dynamic> metadata);
}

/// Интерфейс для отправки P2P сообщений
abstract interface class IRouterMessageSender {
  /// Отправить сообщение конкретному клиенту
  bool sendToClient(String clientId, RouterMessage message);

  /// Отправить сообщение группе клиентов
  int sendToGroup(String groupName, RouterMessage message, {String? excludeClientId});

  /// Отправить broadcast сообщение всем клиентам
  int sendBroadcast(RouterMessage message, {String? excludeClientId});

  /// Обработать request-response сообщение
  void handleRequest(RouterMessage message, String senderId);

  /// Обработать response сообщение
  void handleResponse(RouterMessage message, String senderId);
}

/// Интерфейс для событий роутера
abstract interface class IRouterEventManager {
  /// Подписаться на события роутера
  Stream<RouterEvent> subscribeToEvents();

  /// Отправить событие всем подписчикам
  void emitEvent(RouterEvent event);
}

/// Полный интерфейс роутера, объединяющий все компоненты
abstract interface class IRouterContract
    implements IRouter, IRouterClientManager, IRouterMessageSender, IRouterEventManager {
  /// Обработчик регистрации клиента
  Future<bool> registerClient(
    String clientId,
    StreamController<RouterMessage> streamController, {
    String? clientName,
    List<String>? groups,
    Map<String, dynamic>? metadata,
  });

  /// Обработчик отключения клиента
  void unregisterClient(String clientId, {String? reason});

  /// Обработать входящее P2P сообщение от клиента
  void handleIncomingMessage(RouterMessage message, String senderId);

  /// Генерирует уникальный ID клиента
  String generateClientId();

  /// Заменяет стрим контроллер для клиента (для P2P соединений)
  bool replaceClientStream(String clientId, StreamController<RouterMessage> newStreamController);

  /// Удаляет стрим клиента без полного отключения
  void removeClientStream(String clientId);
}
