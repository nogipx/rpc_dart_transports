// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/src/contracts/_contract.dart';

/// Простое тестовое сообщение, используемое для тестирования
class TestMessage implements IRpcSerializableMessage {
  final String message;

  TestMessage(this.message);

  @override
  Map<String, dynamic> toJson() {
    return {
      'message': message,
    };
  }

  @override
  String toString() => 'TestMessage($message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestMessage && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  /// Создает экземпляр из Json
  factory TestMessage.fromJson(Map<String, dynamic> json) {
    return TestMessage(json['message'] as String);
  }
}
