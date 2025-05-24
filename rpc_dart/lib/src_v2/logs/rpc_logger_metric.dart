// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_logs.dart';

/// Метрика для логирования сообщений
///
/// Может использоваться для отправки различных уровней логов
/// от компонентов библиотеки в диагностический сервис
class RpcLoggerMetric extends IRpcSerializableMessage {
  /// Уникальный идентификатор метрики
  final String id;

  /// ID трассировки, к которой относится этот лог
  final String? traceId;

  /// Временная метка создания лога
  final int timestamp;

  /// Уровень логирования
  final RpcLoggerLevel level;

  /// Сообщение лога
  final String message;

  /// Источник лога (компонент или модуль)
  final String source;

  /// Связанный контекст (например, имя метода или сервиса)
  final String? context;

  /// Идентификатор запроса (если применимо)
  final String? requestId;

  /// Информация об ошибке (если уровень error или critical)
  final Map<String, dynamic>? error;

  /// Стектрейс (для ошибок)
  final String? stackTrace;

  /// Дополнительные данные
  final Map<String, dynamic>? data;

  const RpcLoggerMetric({
    required this.id,
    this.traceId,
    required this.timestamp,
    required this.level,
    required this.message,
    required this.source,
    this.context,
    this.requestId,
    this.error,
    this.stackTrace,
    this.data,
  });

  /// Преобразование в JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trace_id': traceId,
      'timestamp': timestamp,
      'level': level.name,
      'message': message,
      'source': source,
      if (context != null) 'context': context,
      if (requestId != null) 'request_id': requestId,
      if (error != null) 'error': error,
      if (stackTrace != null) 'stack_trace': stackTrace,
      if (data != null) 'data': data,
    };
  }

  /// Создание из JSON
  factory RpcLoggerMetric.fromJson(Map<String, dynamic> json) {
    final levelString = json['level'] as String;
    final level = RpcLoggerLevel.fromJson(levelString);

    return RpcLoggerMetric(
      id: json['id'] as String,
      traceId: json['trace_id'] as String?,
      timestamp: json['timestamp'] as int,
      level: level,
      message: json['message'] as String,
      source: json['source'] as String,
      context: json['context'] as String?,
      requestId: json['request_id'] as String?,
      error: json['error'] as Map<String, dynamic>?,
      stackTrace: json['stack_trace'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
