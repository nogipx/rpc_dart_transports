// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:convert';
import 'package:rpc_dart/rpc_dart.dart';

/// Класс для идентификации клиентов в диагностической системе.
///
/// Используется для группировки и фильтрации метрик от разных клиентов
/// при множественных подключениях.
class RpcClientIdentity implements IRpcSerializableMessage {
  /// Уникальный идентификатор клиента
  final String clientId;

  /// Идентификатор трассировки для связывания всех метрик клиента
  final String traceId;

  /// Версия приложения
  final String? appVersion;

  /// Платформа (iOS, Android, Web и т.д.)
  final String? platform;

  /// Версия платформы
  final String? platformVersion;

  /// Идентификатор устройства (если доступен)
  final String? deviceId;

  /// Модель устройства (если доступна)
  final String? deviceModel;

  /// Идентификатор развертывания/релиза (если доступен)
  final String? deploymentId;

  /// Дополнительные свойства
  final Map<String, dynamic>? properties;

  const RpcClientIdentity({
    required this.clientId,
    required this.traceId,
    this.appVersion,
    this.platform,
    this.platformVersion,
    this.deviceId,
    this.deviceModel,
    this.deploymentId,
    this.properties,
  });

  /// Преобразование в JSON
  @override
  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'trace_id': traceId,
        if (appVersion != null) 'app_version': appVersion,
        if (platform != null) 'platform': platform,
        if (platformVersion != null) 'platform_version': platformVersion,
        if (deviceId != null) 'device_id': deviceId,
        if (deviceModel != null) 'device_model': deviceModel,
        if (deploymentId != null) 'deployment_id': deploymentId,
        if (properties != null) 'properties': properties,
      };

  /// Преобразование в строку JSON
  String toJsonString() => jsonEncode(toJson());

  /// Создание из JSON
  factory RpcClientIdentity.fromJson(Map<String, dynamic> json) {
    return RpcClientIdentity(
      clientId: json['client_id'] as String,
      traceId: json['trace_id'] as String,
      appVersion: json['app_version'] as String?,
      platform: json['platform'] as String?,
      platformVersion: json['platform_version'] as String?,
      deviceId: json['device_id'] as String?,
      deviceModel: json['device_model'] as String?,
      deploymentId: json['deployment_id'] as String?,
      properties: json['properties'] as Map<String, dynamic>?,
    );
  }

  /// Создание из строки JSON
  factory RpcClientIdentity.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return RpcClientIdentity.fromJson(json);
  }

  @override
  String toString() {
    return 'ClientIdentity{clientId: $clientId, traceId: $traceId, '
        'appVersion: $appVersion, platform: $platform, platformVersion: $platformVersion, '
        'deviceId: $deviceId, deviceModel: $deviceModel, deploymentId: $deploymentId}';
  }
}
