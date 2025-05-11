// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Интерфейс для контекстов, поддерживающих обновление метаданных
abstract class MetadataUpdatable {
  /// Обновляет заголовочные метаданные
  void setHeaderMetadata(Map<String, dynamic> newMetadata);

  /// Обновляет трейлерные метаданные
  void setTrailerMetadata(Map<String, dynamic> newMetadata);
}

/// Контекст вызова метода
///
/// Содержит информацию о вызове метода, включая ID сообщения,
/// метаданные и полезную нагрузку
class RpcMethodContext {
  /// Уникальный идентификатор сообщения
  final String messageId;

  /// Метаданные сообщения (устаревшие, используйте headerMetadata)
  final Map<String, dynamic>? _metadata;

  /// Заголовочные метаданные (отправляются в начале RPC)
  final Map<String, dynamic>? _headerMetadata;

  /// Трейлерные метаданные (отправляются в конце RPC, только с сервера клиенту)
  final Map<String, dynamic>? _trailerMetadata;

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
    Map<String, dynamic>? headerMetadata,
    Map<String, dynamic>? trailerMetadata,
    required this.payload,
    this.serviceName,
    this.methodName,
  })  : _metadata = metadata,
        _headerMetadata = headerMetadata ?? metadata,
        _trailerMetadata = trailerMetadata;

  /// Получает метаданные сообщения (устаревшие, используйте headerMetadata)
  Map<String, dynamic>? get metadata => UnmodifiableMapView(_metadata ?? {});

  /// Получает заголовочные метаданные
  Map<String, dynamic>? get headerMetadata =>
      UnmodifiableMapView(_headerMetadata ?? _metadata ?? {});

  /// Получает трейлерные метаданные
  Map<String, dynamic>? get trailerMetadata =>
      _trailerMetadata != null ? UnmodifiableMapView(_trailerMetadata!) : null;

  /// Создает строковое представление контекста
  @override
  String toString() => 'MethodContext(messageId: $messageId, '
      'serviceName: $serviceName, methodName: $methodName)';

  /// Создает мутабельную копию контекста
  MutableRpcMethodContext toMutable() {
    return MutableRpcMethodContext(
      messageId: messageId,
      metadata: Map<String, dynamic>.from(_metadata ?? {}),
      headerMetadata: _headerMetadata != null
          ? Map<String, dynamic>.from(_headerMetadata!)
          : null,
      trailerMetadata: _trailerMetadata != null
          ? Map<String, dynamic>.from(_trailerMetadata!)
          : null,
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
  /// Мутабельная копия метаданных (устаревшие)
  Map<String, dynamic> _mutableMetadata;

  /// Мутабельная копия заголовочных метаданных
  Map<String, dynamic> _mutableHeaderMetadata;

  /// Мутабельная копия трейлерных метаданных
  Map<String, dynamic>? _mutableTrailerMetadata;

  /// Мутабельная копия полезной нагрузки
  dynamic _mutablePayload;

  /// Создает новый мутабельный контекст
  MutableRpcMethodContext({
    required String messageId,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? headerMetadata,
    Map<String, dynamic>? trailerMetadata,
    required dynamic payload,
    String? serviceName,
    String? methodName,
  })  : _mutableMetadata =
            metadata != null ? Map<String, dynamic>.from(metadata) : {},
        _mutableHeaderMetadata = headerMetadata != null
            ? Map<String, dynamic>.from(headerMetadata)
            : (metadata != null ? Map<String, dynamic>.from(metadata) : {}),
        _mutableTrailerMetadata = trailerMetadata != null
            ? Map<String, dynamic>.from(trailerMetadata)
            : null,
        _mutablePayload = payload,
        super(
          messageId: messageId,
          metadata: null, // Не используем родительское поле
          headerMetadata: null, // Не используем родительское поле
          trailerMetadata: null, // Не используем родительское поле
          payload: null, // Не используем родительское поле
          serviceName: serviceName,
          methodName: methodName,
        );

  /// Обновляет заголовочные метаданные
  @override
  void setHeaderMetadata(Map<String, dynamic> newMetadata) {
    _mutableHeaderMetadata = Map<String, dynamic>.from(newMetadata);
    // Для обратной совместимости также обновляем старые метаданные
    _mutableMetadata = Map<String, dynamic>.from(newMetadata);
  }

  /// Обновляет трейлерные метаданные
  @override
  void setTrailerMetadata(Map<String, dynamic> newMetadata) {
    _mutableTrailerMetadata = Map<String, dynamic>.from(newMetadata);
  }

  /// Обновляет полезную нагрузку
  void updatePayload(dynamic newPayload) {
    _mutablePayload = newPayload;
  }

  /// Получает текущие метаданные (устаревшие)
  @override
  Map<String, dynamic>? get metadata => _mutableMetadata;

  /// Получает текущие заголовочные метаданные
  @override
  Map<String, dynamic>? get headerMetadata => _mutableHeaderMetadata;

  /// Получает текущие трейлерные метаданные
  @override
  Map<String, dynamic>? get trailerMetadata => _mutableTrailerMetadata;

  /// Получает текущую полезную нагрузку
  @override
  dynamic get payload => _mutablePayload;
}
