// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'router_models.dart';

/// Глобальная шина сообщений для связи между изолированными endpoint'ами
///
/// Эта шина решает проблему изолированности P2P стримов:
/// - Каждый endpoint регистрирует свои P2P стримы в шине
/// - Роутер отправляет сообщения через шину
/// - Шина доставляет сообщения в правильный endpoint/стрим
class GlobalMessageBus {
  static final GlobalMessageBus _instance = GlobalMessageBus._internal();
  factory GlobalMessageBus() => _instance;
  GlobalMessageBus._internal();

  /// Зарегистрированные P2P стримы: clientId -> StreamController
  final Map<String, StreamController<RouterMessage>> _clientStreams = {};

  /// Зарегистрированные endpoint'ы: endpointId -> info
  final Map<String, EndpointInfo> _endpoints = {};

  final RpcLogger _logger = RpcLogger('GlobalMessageBus');

  /// Регистрирует P2P стрим клиента
  void registerClientStream(
    String clientId,
    StreamController<RouterMessage> streamController,
    String endpointId,
  ) {
    _logger.info('Регистрация P2P стрима: $clientId в endpoint $endpointId');

    // Удаляем старый стрим если есть
    final oldStream = _clientStreams.remove(clientId);
    if (oldStream != null && !oldStream.isClosed) {
      oldStream.close();
      _logger.debug('Старый стрим для $clientId закрыт');
    }

    _clientStreams[clientId] = streamController;
    _logger.debug(
        'P2P стрим для $clientId зарегистрирован, всего стримов: ${_clientStreams.length}');
  }

  /// Отключает P2P стрим клиента
  void unregisterClientStream(String clientId) {
    final streamController = _clientStreams.remove(clientId);
    if (streamController != null) {
      if (!streamController.isClosed) {
        streamController.close();
      }
      _logger.info(
          'P2P стрим для $clientId отключен, осталось стримов: ${_clientStreams.length}');
    }
  }

  /// Регистрирует endpoint в шине
  void registerEndpoint(String endpointId, EndpointInfo info) {
    _endpoints[endpointId] = info;
    _logger.debug(
        'Endpoint $endpointId зарегистрирован, всего endpoints: ${_endpoints.length}');
  }

  /// Отключает endpoint
  void unregisterEndpoint(String endpointId) {
    final info = _endpoints.remove(endpointId);
    if (info != null) {
      _logger.debug(
          'Endpoint $endpointId отключен, осталось endpoints: ${_endpoints.length}');

      // Отключаем все стримы этого endpoint'а
      final clientsToRemove = <String>[];
      for (final entry in _clientStreams.entries) {
        if (info.clientIds.contains(entry.key)) {
          clientsToRemove.add(entry.key);
        }
      }

      for (final clientId in clientsToRemove) {
        unregisterClientStream(clientId);
      }
    }
  }

  /// Отправляет сообщение конкретному клиенту
  bool sendToClient(String clientId, RouterMessage message) {
    final streamController = _clientStreams[clientId];
    if (streamController != null && !streamController.isClosed) {
      try {
        streamController.add(message);
        _logger
            .debug('Сообщение доставлено клиенту $clientId: ${message.type}');
        return true;
      } catch (e) {
        _logger.warning(
            'Ошибка отправки сообщения клиенту $clientId: $e (автоматически удаляем)');
        // Автоматически удаляем битый стрим
        unregisterClientStream(clientId);
        return false;
      }
    } else {
      if (streamController != null && streamController.isClosed) {
        _logger.debug(
            'Клиент $clientId имеет закрытый стрим (автоматически удаляем)');
        // Автоматически удаляем закрытые стримы
        unregisterClientStream(clientId);
      } else {
        _logger.debug('Клиент $clientId не найден');
      }
      return false;
    }
  }

  /// Отправляет broadcast сообщение всем клиентам
  int sendBroadcast(RouterMessage message, {String? excludeClientId}) {
    int sentCount = 0;
    final clientIds = _clientStreams.keys.toList();

    _logger.debug(
        'Отправка broadcast сообщения ${clientIds.length} клиентам (исключая $excludeClientId)');

    for (final clientId in clientIds) {
      if (clientId != excludeClientId) {
        if (sendToClient(clientId, message)) {
          sentCount++;
        }
      }
    }

    _logger.debug('Broadcast доставлен $sentCount получателям');
    return sentCount;
  }

  /// Получает список всех зарегистрированных клиентов
  List<String> getRegisteredClientIds() {
    return _clientStreams.keys.toList();
  }

  /// Проверяет, зарегистрирован ли клиент в шине
  bool isClientRegistered(String clientId) {
    final streamController = _clientStreams[clientId];
    return streamController != null && !streamController.isClosed;
  }

  /// Получает статистику шины
  GlobalMessageBusStats getStats() {
    return GlobalMessageBusStats(
      activeClients: _clientStreams.length,
      activeEndpoints: _endpoints.length,
      clientIds: _clientStreams.keys.toList(),
      endpointIds: _endpoints.keys.toList(),
    );
  }

  /// Очищает все стримы (для тестирования)
  void clear() {
    _logger.warning('Очистка всех стримов');

    // Закрываем все стримы
    for (final entry in _clientStreams.entries) {
      if (!entry.value.isClosed) {
        entry.value.close();
      }
    }

    _clientStreams.clear();
    _endpoints.clear();

    _logger.info('Шина очищена');
  }
}

/// Информация о зарегистрированном endpoint'е
class EndpointInfo {
  final String endpointId;
  final String address;
  final DateTime connectedAt;
  final Set<String> clientIds;

  EndpointInfo({
    required this.endpointId,
    required this.address,
    required this.connectedAt,
    Set<String>? clientIds,
  }) : clientIds = clientIds ?? <String>{};

  void addClient(String clientId) {
    clientIds.add(clientId);
  }

  void removeClient(String clientId) {
    clientIds.remove(clientId);
  }
}

/// Статистика глобальной шины сообщений
class GlobalMessageBusStats {
  final int activeClients;
  final int activeEndpoints;
  final List<String> clientIds;
  final List<String> endpointIds;

  const GlobalMessageBusStats({
    required this.activeClients,
    required this.activeEndpoints,
    required this.clientIds,
    required this.endpointIds,
  });

  @override
  String toString() {
    return 'GlobalMessageBusStats('
        'activeClients: $activeClients, '
        'activeEndpoints: $activeEndpoints, '
        'clientIds: $clientIds, '
        'endpointIds: $endpointIds'
        ')';
  }
}
