/// Модели данных для полнофункционального чата
library;

import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// Типы действий пользователей
enum UserAction { joined, left, typing, stopTyping }

/// Типы сообщений
enum MessageType { text, system, private, reaction, typing, userJoined, userLeft }

/// Статус пользователя
enum UserStatus { online, idle, busy, offline }

/// Типы транспортов для подключения к роутеру
enum TransportType { websocket, http2, inMemory }

/// Состояние подключения клиента
enum ChatConnectionState { disconnected, connecting, connected, reconnecting, error }

/// Сообщение чата
class ChatMessage implements IRpcSerializable {
  final String id;
  final String username;
  final String message;
  final String room;
  final DateTime timestamp;
  final MessageType type;
  final String? targetUserId; // Для приватных сообщений
  final String? replyToId; // Для ответов на сообщения
  final Map<String, int> reactions; // emoji -> count
  final bool isEdited;

  const ChatMessage({
    required this.id,
    required this.username,
    required this.message,
    required this.room,
    required this.timestamp,
    this.type = MessageType.text,
    this.targetUserId,
    this.replyToId,
    this.reactions = const {},
    this.isEdited = false,
  });

  /// Создает системное сообщение
  factory ChatMessage.system({required String message, required String room}) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: 'Система',
      message: message,
      room: room,
      timestamp: DateTime.now(),
      type: MessageType.system,
    );
  }

  /// Создает приватное сообщение
  factory ChatMessage.private({
    required String username,
    required String message,
    required String targetUserId,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      message: message,
      room: 'private',
      timestamp: DateTime.now(),
      type: MessageType.private,
      targetUserId: targetUserId,
    );
  }

  /// Создает уведомление о печатании
  factory ChatMessage.typing({required String username, required String room}) {
    return ChatMessage(
      id: 'typing_${DateTime.now().millisecondsSinceEpoch}',
      username: username,
      message: 'печатает...',
      room: room,
      timestamp: DateTime.now(),
      type: MessageType.typing,
    );
  }

  /// Копирует сообщение с изменениями
  ChatMessage copyWith({String? message, Map<String, int>? reactions, bool? isEdited}) {
    return ChatMessage(
      id: id,
      username: username,
      message: message ?? this.message,
      room: room,
      timestamp: timestamp,
      type: type,
      targetUserId: targetUserId,
      replyToId: replyToId,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  /// Добавляет реакцию
  ChatMessage addReaction(String emoji) {
    final newReactions = Map<String, int>.from(reactions);
    newReactions[emoji] = (newReactions[emoji] ?? 0) + 1;
    return copyWith(reactions: newReactions);
  }

  /// Убирает реакцию
  ChatMessage removeReaction(String emoji) {
    final newReactions = Map<String, int>.from(reactions);
    if (newReactions.containsKey(emoji)) {
      final count = newReactions[emoji]! - 1;
      if (count <= 0) {
        newReactions.remove(emoji);
      } else {
        newReactions[emoji] = count;
      }
    }
    return copyWith(reactions: newReactions);
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'message': message,
    'room': room,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'type': type.name,
    if (targetUserId != null) 'targetUserId': targetUserId,
    if (replyToId != null) 'replyToId': replyToId,
    'reactions': reactions,
    'isEdited': isEdited,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    username: json['username'] as String,
    message: json['message'] as String,
    room: json['room'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    type: MessageType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => MessageType.text,
    ),
    targetUserId: json['targetUserId'] as String?,
    replyToId: json['replyToId'] as String?,
    reactions: Map<String, int>.from(json['reactions'] ?? {}),
    isEdited: json['isEdited'] as bool? ?? false,
  );

  @override
  String toString() => 'ChatMessage(id: $id, username: $username, type: $type, room: $room)';
}

/// Событие пользователя
class UserEvent implements IRpcSerializable {
  final String username;
  final String room;
  final UserAction action;
  final DateTime timestamp;
  final String? metadata; // Дополнительная информация

  const UserEvent({
    required this.username,
    required this.room,
    required this.action,
    required this.timestamp,
    this.metadata,
  });

  @override
  Map<String, dynamic> toJson() => {
    'username': username,
    'room': room,
    'action': action.name,
    'timestamp': timestamp.millisecondsSinceEpoch,
    if (metadata != null) 'metadata': metadata,
  };

  factory UserEvent.fromJson(Map<String, dynamic> json) => UserEvent(
    username: json['username'] as String,
    room: json['room'] as String,
    action: UserAction.values.firstWhere((e) => e.name == json['action']),
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    metadata: json['metadata'] as String?,
  );

  @override
  String toString() => 'UserEvent(username: $username, action: ${action.name}, room: $room)';
}

/// Профиль пользователя
class UserProfile implements IRpcSerializable {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final UserStatus status;
  final DateTime lastSeen;
  final Set<String> rooms;
  final Map<String, dynamic> metadata;

  const UserProfile({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.status = UserStatus.online,
    required this.lastSeen,
    this.rooms = const {},
    this.metadata = const {},
  });

  /// Копирует профиль с изменениями
  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    UserStatus? status,
    DateTime? lastSeen,
    Set<String>? rooms,
    Map<String, dynamic>? metadata,
  }) {
    return UserProfile(
      userId: userId,
      username: username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      rooms: rooms ?? this.rooms,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    if (displayName != null) 'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'status': status.name,
    'lastSeen': lastSeen.millisecondsSinceEpoch,
    'rooms': rooms.toList(),
    'metadata': metadata,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId: json['userId'] as String,
    username: json['username'] as String,
    displayName: json['displayName'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    status: UserStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => UserStatus.online,
    ),
    lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int),
    rooms: Set<String>.from(json['rooms'] ?? []),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );

  @override
  String toString() => 'UserProfile(username: $username, status: $status)';
}

/// Комната/канал чата
class ChatRoom implements IRpcSerializable {
  final String id;
  final String name;
  final String? description;
  final Set<String> members;
  final DateTime createdAt;
  final String? createdBy;
  final bool isPrivate;
  final Map<String, dynamic> metadata;

  const ChatRoom({
    required this.id,
    required this.name,
    this.description,
    this.members = const {},
    required this.createdAt,
    this.createdBy,
    this.isPrivate = false,
    this.metadata = const {},
  });

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'members': members.toList(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (createdBy != null) 'createdBy': createdBy,
    'isPrivate': isPrivate,
    'metadata': metadata,
  };

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    members: Set<String>.from(json['members'] ?? []),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    createdBy: json['createdBy'] as String?,
    isPrivate: json['isPrivate'] as bool? ?? false,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );

  @override
  String toString() => 'ChatRoom(id: $id, name: $name, members: ${members.length})';
}
