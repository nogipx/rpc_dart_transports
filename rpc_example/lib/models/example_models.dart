// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

/// Базовый класс для всех сообщений в примере
abstract class ExampleMessage implements IRpcSerializableMessage {
  const ExampleMessage();

  @override
  Map<String, dynamic> toJson();
}

/// Модели для модуля пользователей
class UserRequest extends ExampleMessage {
  final String userId;

  const UserRequest({this.userId = ''});

  @override
  Map<String, dynamic> toJson() => {'userId': userId};

  factory UserRequest.fromJson(Map<String, dynamic> json) {
    return UserRequest(userId: json['userId'] as String? ?? '');
  }
}

class UserResponse extends ExampleMessage {
  final String userName;
  final String email;

  const UserResponse({this.userName = '', this.email = ''});

  @override
  Map<String, dynamic> toJson() => {'userName': userName, 'email': email};

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      userName: json['userName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

/// Модели для модуля аутентификации
class AuthRequest extends ExampleMessage {
  final String login;
  final String password;

  const AuthRequest({this.login = '', this.password = ''});

  @override
  Map<String, dynamic> toJson() => {'login': login, 'password': password};

  factory AuthRequest.fromJson(Map<String, dynamic> json) {
    return AuthRequest(
      login: json['login'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}

class AuthResponse extends ExampleMessage {
  final bool success;
  final String token;

  const AuthResponse({this.success = false, this.token = ''});

  @override
  Map<String, dynamic> toJson() => {'success': success, 'token': token};

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] as bool? ?? false,
      token: json['token'] as String? ?? '',
    );
  }
}

/// Модели для модуля контента
class ContentRequest extends ExampleMessage {
  final String contentId;

  const ContentRequest({this.contentId = ''});

  @override
  Map<String, dynamic> toJson() => {'contentId': contentId};

  factory ContentRequest.fromJson(Map<String, dynamic> json) {
    return ContentRequest(contentId: json['contentId'] as String? ?? '');
  }
}

class ContentResponse extends ExampleMessage {
  final String title;
  final String content;

  const ContentResponse({this.title = '', this.content = ''});

  @override
  Map<String, dynamic> toJson() => {'title': title, 'content': content};

  factory ContentResponse.fromJson(Map<String, dynamic> json) {
    return ContentResponse(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}
