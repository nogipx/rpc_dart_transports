// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

/// Типы сообщений роутера
enum RouterMessageType {
  /// Регистрация клиента
  register,

  /// Ответ на регистрацию
  registerResponse,

  /// Unicast сообщение (1:1)
  unicast,

  /// Multicast сообщение (1:N по группе)
  multicast,

  /// Broadcast сообщение (1:ALL)
  broadcast,

  /// Ping для проверки соединения
  ping,

  /// Pong ответ на ping
  pong,

  /// Сообщение об ошибке
  error,
}

/// Типы системных событий роутера
enum RouterEventType {
  /// Клиент подключился
  clientConnected,

  /// Клиент отключился
  clientDisconnected,

  /// Клиент обновил свои возможности
  clientCapabilitiesUpdated,

  /// Изменилась топология сети
  topologyChanged,

  /// Статистика роутера
  routerStats,

  /// Информация о производительности
  performanceMetrics,

  /// Предупреждение о проблемах
  healthWarning,
}

/// Сообщение роутера для маршрутизации между клиентами
class RouterMessage implements IRpcSerializable {
  /// Тип сообщения
  final RouterMessageType type;

  /// ID отправителя (устанавливается роутером)
  final String? senderId;

  /// ID получателя (для unicast)
  final String? targetId;

  /// Имя группы (для multicast)
  final String? groupName;

  /// Полезная нагрузка сообщения
  final Map<String, dynamic>? payload;

  /// Временная метка
  final int? timestamp;

  /// Сообщение об ошибке
  final String? errorMessage;

  /// Флаг успешности операции
  final bool? success;

  const RouterMessage({
    required this.type,
    this.senderId,
    this.targetId,
    this.groupName,
    this.payload,
    this.timestamp,
    this.errorMessage,
    this.success,
  });

  /// Создает сообщение регистрации клиента
  factory RouterMessage.register({
    String? clientName,
    List<String>? groups,
  }) {
    return RouterMessage(
      type: RouterMessageType.register,
      payload: {
        if (clientName != null) 'clientName': clientName,
        if (groups != null) 'groups': groups,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает ответ на регистрацию
  factory RouterMessage.registerResponse({
    required String clientId,
    required bool success,
    String? errorMessage,
  }) {
    return RouterMessage(
      type: RouterMessageType.registerResponse,
      senderId: 'router',
      payload: {'clientId': clientId},
      success: success,
      errorMessage: errorMessage,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает unicast сообщение
  factory RouterMessage.unicast({
    required String targetId,
    required Map<String, dynamic> payload,
    String? senderId,
  }) {
    return RouterMessage(
      type: RouterMessageType.unicast,
      senderId: senderId,
      targetId: targetId,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает multicast сообщение
  factory RouterMessage.multicast({
    required String groupName,
    required Map<String, dynamic> payload,
    String? senderId,
  }) {
    return RouterMessage(
      type: RouterMessageType.multicast,
      senderId: senderId,
      groupName: groupName,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает broadcast сообщение
  factory RouterMessage.broadcast({
    required Map<String, dynamic> payload,
    String? senderId,
  }) {
    return RouterMessage(
      type: RouterMessageType.broadcast,
      senderId: senderId,
      payload: payload,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает ping сообщение
  factory RouterMessage.ping({
    String? senderId,
  }) {
    return RouterMessage(
      type: RouterMessageType.ping,
      senderId: senderId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает pong сообщение
  factory RouterMessage.pong({
    required int timestamp,
    String? senderId,
  }) {
    return RouterMessage(
      type: RouterMessageType.pong,
      senderId: senderId,
      payload: {'originalTimestamp': timestamp},
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает сообщение об ошибке
  factory RouterMessage.error(
    String errorMessage, {
    String? senderId,
  }) {
    return RouterMessage(
      type: RouterMessageType.error,
      senderId: senderId,
      errorMessage: errorMessage,
      success: false,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает копию сообщения с измененными полями
  RouterMessage copyWith({
    RouterMessageType? type,
    String? senderId,
    String? targetId,
    String? groupName,
    Map<String, dynamic>? payload,
    int? timestamp,
    String? errorMessage,
    bool? success,
  }) {
    return RouterMessage(
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      targetId: targetId ?? this.targetId,
      groupName: groupName ?? this.groupName,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
      success: success ?? this.success,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (senderId != null) 'senderId': senderId,
      if (targetId != null) 'targetId': targetId,
      if (groupName != null) 'groupName': groupName,
      if (payload != null) 'payload': payload,
      if (timestamp != null) 'timestamp': timestamp,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (success != null) 'success': success,
    };
  }

  factory RouterMessage.fromJson(Map<String, dynamic> json) {
    return RouterMessage(
      type: RouterMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => throw ArgumentError('Unknown router message type: ${json['type']}'),
      ),
      senderId: json['senderId'] as String?,
      targetId: json['targetId'] as String?,
      groupName: json['groupName'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] as int?,
      errorMessage: json['errorMessage'] as String?,
      success: json['success'] as bool?,
    );
  }

  @override
  String toString() {
    return 'RouterMessage('
        'type: $type'
        '${senderId != null ? ', senderId: $senderId' : ''}'
        '${targetId != null ? ', targetId: $targetId' : ''}'
        '${groupName != null ? ', groupName: $groupName' : ''}'
        '${payload != null ? ', payload: $payload' : ''}'
        '${errorMessage != null ? ', error: $errorMessage' : ''}'
        ')';
  }
}

/// Системное событие роутера для отправки клиентам
class RouterEvent implements IRpcSerializable {
  /// Тип события
  final RouterEventType type;

  /// Временная метка события
  final int timestamp;

  /// Данные события
  final Map<String, dynamic> data;

  /// Дополнительные метаданные
  final Map<String, dynamic>? metadata;

  const RouterEvent({
    required this.type,
    required this.timestamp,
    required this.data,
    this.metadata,
  });

  /// Событие подключения клиента
  factory RouterEvent.clientConnected({
    required String clientId,
    String? clientName,
    List<String>? capabilities,
  }) {
    return RouterEvent(
      type: RouterEventType.clientConnected,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      data: {
        'clientId': clientId,
        if (clientName != null) 'clientName': clientName,
        if (capabilities != null) 'capabilities': capabilities,
      },
    );
  }

  /// Событие отключения клиента
  factory RouterEvent.clientDisconnected({
    required String clientId,
    String? reason,
  }) {
    return RouterEvent(
      type: RouterEventType.clientDisconnected,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      data: {
        'clientId': clientId,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Событие изменения топологии
  factory RouterEvent.topologyChanged({
    required int activeClients,
    required List<String> clientIds,
    required Map<String, List<String>> capabilities,
  }) {
    return RouterEvent(
      type: RouterEventType.topologyChanged,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      data: {
        'activeClients': activeClients,
        'clientIds': clientIds,
        'capabilities': capabilities,
      },
    );
  }

  /// Событие статистики роутера
  factory RouterEvent.routerStats({
    required int activeClients,
    required int messagesPerSecond,
    required Map<String, int> messageTypeCounts,
  }) {
    return RouterEvent(
      type: RouterEventType.routerStats,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      data: {
        'activeClients': activeClients,
        'messagesPerSecond': messagesPerSecond,
        'messageTypeCounts': messageTypeCounts,
      },
    );
  }

  /// Событие предупреждения о производительности
  factory RouterEvent.healthWarning({
    required String warning,
    required String severity,
    Map<String, dynamic>? details,
  }) {
    return RouterEvent(
      type: RouterEventType.healthWarning,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      data: {
        'warning': warning,
        'severity': severity,
        if (details != null) ...details,
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'timestamp': timestamp,
      'data': data,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory RouterEvent.fromJson(Map<String, dynamic> json) {
    return RouterEvent(
      type: RouterEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => throw ArgumentError('Unknown router event type: ${json['type']}'),
      ),
      timestamp: json['timestamp'] as int,
      data: json['data'] as Map<String, dynamic>,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'RouterEvent(type: $type, data: $data)';
  }
}

/// Информация о клиенте роутера
class RouterClientInfo {
  /// Уникальный ID клиента
  final String clientId;

  /// Имя клиента (опционально)
  final String? clientName;

  /// Группы, к которым принадлежит клиент
  final List<String> groups;

  /// Время подключения
  final DateTime connectedAt;

  const RouterClientInfo({
    required this.clientId,
    this.clientName,
    this.groups = const [],
    required this.connectedAt,
  });

  @override
  String toString() {
    return 'RouterClientInfo(id: $clientId, name: $clientName, groups: $groups)';
  }
}
