// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

/// Запрос регистрации клиента
class RouterRegisterRequest implements IRpcSerializable {
  final String? clientName;
  final List<String>? groups;
  final Map<String, dynamic>? metadata;

  const RouterRegisterRequest({
    this.clientName,
    this.groups,
    this.metadata,
  });

  factory RouterRegisterRequest.fromJson(Map<String, dynamic> json) {
    return RouterRegisterRequest(
      clientName: json['clientName'] as String?,
      groups: (json['groups'] as List?)?.cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (clientName != null) 'clientName': clientName,
      if (groups != null) 'groups': groups,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Запрос списка онлайн клиентов
class RouterGetOnlineClientsRequest implements IRpcSerializable {
  final List<String>? groups;
  final Map<String, dynamic>? metadata;

  const RouterGetOnlineClientsRequest({
    this.groups,
    this.metadata,
  });

  factory RouterGetOnlineClientsRequest.fromJson(Map<String, dynamic> json) {
    return RouterGetOnlineClientsRequest(
      groups: (json['groups'] as List?)?.cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (groups != null) 'groups': groups,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Запрос обновления метаданных
class RouterUpdateMetadataRequest implements IRpcSerializable {
  final Map<String, dynamic> metadata;

  const RouterUpdateMetadataRequest({
    required this.metadata,
  });

  factory RouterUpdateMetadataRequest.fromJson(Map<String, dynamic> json) {
    return RouterUpdateMetadataRequest(
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata,
    };
  }
}
