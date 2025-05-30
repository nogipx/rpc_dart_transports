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
