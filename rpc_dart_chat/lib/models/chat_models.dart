/// Модели данных для полнофункционального чата
library;

import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// Типы действий пользователей
enum UserAction { joined, left, typing, stopTyping }

/// Статус пользователя
enum UserStatus { online, idle, busy, offline }

/// Состояние подключения чата (избегаем конфликта с Flutter ConnectionState)
enum ChatConnectionState { disconnected, connecting, connected, reconnecting, error }

/// Пользователь чата
class ChatUser implements IRpcSerializable {
  final String id;
  final String name;
  final bool isOnline;
  final DateTime? lastSeen;
  final Map<String, dynamic> metadata;

  const ChatUser({
    required this.id,
    required this.name,
    this.isOnline = false,
    this.lastSeen,
    this.metadata = const {},
  });

  // === ГЕТТЕРЫ ДЛЯ СОВМЕСТИМОСТИ ===
  String get username => name;
  UserStatus get status => isOnline ? UserStatus.online : UserStatus.offline;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] as String,
      name: json['name'] as String,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen:
          json['lastSeen'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int)
              : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  ChatUser copyWith({
    String? name,
    bool? isOnline,
    DateTime? lastSeen,
    Map<String, dynamic>? metadata,
  }) {
    return ChatUser(
      id: id,
      name: name ?? this.name,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'ChatUser(id: $id, name: $name, isOnline: $isOnline)';
}

/// Сообщение чата
class ChatMessage implements IRpcSerializable {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final ChatMessageType type;
  final String? targetUserId; // Для приватных сообщений
  final Map<String, Set<String>> reactions; // userId -> Set<reactionEmoji>

  const ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.type = ChatMessageType.public,
    this.targetUserId,
    this.reactions = const {},
  });

  // === ГЕТТЕРЫ ДЛЯ СОВМЕСТИМОСТИ ===
  String get username => senderName;
  String get message => content;
  bool get isEdited => false; // Простая реализация

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type.name,
      'targetUserId': targetUserId,
      'reactions': reactions.map((userId, reactions) => MapEntry(userId, reactions.toList())),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final reactionsMap = <String, Set<String>>{};
    final reactionsJson = json['reactions'] as Map<String, dynamic>? ?? {};

    for (final entry in reactionsJson.entries) {
      final reactionsList = entry.value as List<dynamic>? ?? [];
      reactionsMap[entry.key] = reactionsList.cast<String>().toSet();
    }

    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      type: ChatMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChatMessageType.public,
      ),
      targetUserId: json['targetUserId'] as String?,
      reactions: reactionsMap,
    );
  }

  ChatMessage copyWith({
    String? content,
    ChatMessageType? type,
    String? targetUserId,
    Map<String, Set<String>>? reactions,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      senderId: senderId,
      senderName: senderName,
      timestamp: timestamp,
      type: type ?? this.type,
      targetUserId: targetUserId ?? this.targetUserId,
      reactions: reactions ?? this.reactions,
    );
  }

  @override
  String toString() => 'ChatMessage(id: $id, from: $senderName, type: $type)';
}

/// Тип сообщения чата
enum ChatMessageType { public, private, system }

/// Событие чата (пользователь печатает)
class TypingEvent implements IRpcSerializable {
  final String userId;
  final String userName;
  final bool isTyping;
  final DateTime timestamp;

  const TypingEvent({
    required this.userId,
    required this.userName,
    required this.isTyping,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'isTyping': isTyping,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory TypingEvent.fromJson(Map<String, dynamic> json) {
    return TypingEvent(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      isTyping: json['isTyping'] as bool,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  @override
  String toString() => 'TypingEvent(user: $userName, typing: $isTyping)';
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
