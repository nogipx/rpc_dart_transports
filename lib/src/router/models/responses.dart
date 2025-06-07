// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';
import '../router_models.dart';

/// Ответ на регистрацию клиента
class RouterRegisterResponse implements IRpcSerializable {
  final String clientId;
  final bool success;
  final String? errorMessage;

  const RouterRegisterResponse({
    required this.clientId,
    required this.success,
    this.errorMessage,
  });

  factory RouterRegisterResponse.fromJson(Map<String, dynamic> json) {
    return RouterRegisterResponse(
      clientId: json['clientId'] as String,
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'success': success,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}

/// Ответ ping
class RouterPongResponse implements IRpcSerializable {
  final int timestamp;
  final int serverTimestamp;

  const RouterPongResponse({
    required this.timestamp,
    required this.serverTimestamp,
  });

  factory RouterPongResponse.fromJson(Map<String, dynamic> json) {
    return RouterPongResponse(
      timestamp: json['timestamp'] as int,
      serverTimestamp: json['serverTimestamp'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'serverTimestamp': serverTimestamp,
    };
  }
}

/// Список клиентов как ответ
class RouterClientsList implements IRpcSerializable {
  final List<RouterClientInfo> clients;

  const RouterClientsList(this.clients);

  factory RouterClientsList.fromJson(Map<String, dynamic> json) {
    return RouterClientsList(
      (json['clients'] as List)
          .map((item) => RouterClientInfo.fromJson(item))
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'clients': clients.map((client) => client.toJson()).toList(),
    };
  }
}
