// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Коды состояния операции в стиле gRPC
enum RpcStatusCode {
  /// Операция выполнена успешно
  ok(0),

  /// Операция отменена клиентом
  cancelled(1),

  /// Неизвестная ошибка
  unknown(2),

  /// Некорректный аргумент
  invalidArgument(3),

  /// Время ожидания истекло
  deadlineExceeded(4),

  /// Ресурс не найден
  notFound(5),

  /// Ресурс уже существует
  alreadyExists(6),

  /// Отказано в доступе
  permissionDenied(7),

  /// Недостаточно ресурсов
  resourceExhausted(8),

  /// Предварительное условие не выполнено
  failedPrecondition(9),

  /// Операция прервана
  aborted(10),

  /// Ресурс вне допустимого диапазона
  outOfRange(11),

  /// Функциональность не реализована
  unimplemented(12),

  /// Внутренняя ошибка сервера
  internal(13),

  /// Сервис недоступен
  unavailable(14),

  /// Ошибка аутентификации
  unauthenticated(16);

  /// Числовой код состояния
  final int code;

  /// Конструктор
  const RpcStatusCode(this.code);

  /// Создает RpcStatusCode из числового кода
  factory RpcStatusCode.fromCode(int code) {
    return RpcStatusCode.values.firstWhere(
      (status) => status.code == code,
      orElse: () => RpcStatusCode.unknown,
    );
  }
}

/// Маркер статуса операции в стиле gRPC
class RpcStatusMarker extends RpcServiceMarker {
  /// Код состояния
  final RpcStatusCode code;

  /// Сообщение с описанием
  final String message;

  /// Детали ошибки (опционально)
  final Map<String, dynamic>? details;

  /// Конструктор
  const RpcStatusMarker({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.status;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['code'] = code.code;
    baseJson['message'] = message;
    if (details != null) {
      baseJson['details'] = details;
    }
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcStatusMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.status.name) {
      throw FormatException('Неверный формат маркера статуса');
    }

    return RpcStatusMarker(
      code: RpcStatusCode.fromCode(json['code'] as int),
      message: json['message'] as String,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}
