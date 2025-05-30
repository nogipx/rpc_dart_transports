/// Модели данных для чата
library;

import 'package:rpc_dart/rpc_dart.dart';

enum UserAction { joined, left }

class ChatMessage implements IRpcSerializable {
  final String id;
  final String username;
  final String message;
  final String room;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.username,
    required this.message,
    required this.room,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'message': message,
    'room': room,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    username: json['username'] as String,
    message: json['message'] as String,
    room: json['room'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
  );

  @override
  String toString() => 'ChatMessage(id: $id, username: $username, message: $message, room: $room)';
}

class UserEvent implements IRpcSerializable {
  final String username;
  final String room;
  final UserAction action;
  final DateTime timestamp;

  const UserEvent({
    required this.username,
    required this.room,
    required this.action,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
    'username': username,
    'room': room,
    'action': action.name,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory UserEvent.fromJson(Map<String, dynamic> json) => UserEvent(
    username: json['username'] as String,
    room: json['room'] as String,
    action: UserAction.values.firstWhere((e) => e.name == json['action']),
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
  );

  @override
  String toString() => 'UserEvent(username: $username, action: ${action.name}, room: $room)';
}
