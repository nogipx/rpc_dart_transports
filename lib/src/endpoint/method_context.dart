// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Интерфейс для контекстов, поддерживающих обновление метаданных
abstract class MetadataUpdatable {
  /// Обновляет метаданные контекста
  void updateMetadata(Map<String, dynamic> newMetadata);
}

/// Контекст вызова метода
///
/// Содержит информацию о вызове метода, включая ID сообщения,
/// метаданные и полезную нагрузку
class RpcMethodContext {
  /// Уникальный идентификатор сообщения
  final String messageId;

  /// Метаданные сообщения
  final Map<String, dynamic>? _metadata;

  /// Полезная нагрузка (тело запроса)
  final dynamic payload;

  /// Имя сервиса
  final String? serviceName;

  /// Имя метода
  final String? methodName;

  /// Создает новый контекст вызова метода
  const RpcMethodContext({
    required this.messageId,
    Map<String, dynamic>? metadata,
    required this.payload,
    this.serviceName,
    this.methodName,
  }) : _metadata = metadata;

  /// Получает метаданные сообщения
  Map<String, dynamic>? get metadata => UnmodifiableMapView(_metadata ?? {});

  /// Создает строковое представление контекста
  @override
  String toString() => 'MethodContext(messageId: $messageId, '
      'serviceName: $serviceName, methodName: $methodName)';

  /// Создает мутабельную копию контекста
  MutableRpcMethodContext toMutable() {
    return MutableRpcMethodContext(
      messageId: messageId,
      metadata: Map<String, dynamic>.from(_metadata ?? {}),
      payload: payload,
      serviceName: serviceName,
      methodName: methodName,
    );
  }
}

/// Мутабельный вариант контекста вызова метода
///
/// Позволяет изменять метаданные и полезную нагрузку
class MutableRpcMethodContext extends RpcMethodContext
    implements MetadataUpdatable {
  /// Мутабельная копия метаданных
  Map<String, dynamic> _mutableMetadata;

  /// Мутабельная копия полезной нагрузки
  dynamic _mutablePayload;

  /// Создает новый мутабельный контекст
  MutableRpcMethodContext({
    required String messageId,
    Map<String, dynamic>? metadata,
    required dynamic payload,
    String? serviceName,
    String? methodName,
  })  : _mutableMetadata =
            metadata != null ? Map<String, dynamic>.from(metadata) : {},
        _mutablePayload = payload,
        super(
          messageId: messageId,
          metadata: null, // Не используем родительское поле
          payload: null, // Не используем родительское поле
          serviceName: serviceName,
          methodName: methodName,
        );

  /// Обновляет метаданные
  @override
  void updateMetadata(Map<String, dynamic> newMetadata) {
    _mutableMetadata = newMetadata;
  }

  /// Обновляет полезную нагрузку
  void updatePayload(dynamic newPayload) {
    _mutablePayload = newPayload;
  }

  /// Получает текущие метаданные
  @override
  Map<String, dynamic>? get metadata => _mutableMetadata;

  /// Получает текущую полезную нагрузку
  @override
  dynamic get payload => _mutablePayload;
}
