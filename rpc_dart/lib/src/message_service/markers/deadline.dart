// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Маркер для управления тайм-аутами (deadline) в стиле gRPC
class RpcDeadlineMarker extends RpcServiceMarker {
  /// Время окончания в миллисекундах с начала эпохи
  final int deadlineTimestamp;

  /// Конструктор с явным указанием времени
  const RpcDeadlineMarker({
    required this.deadlineTimestamp,
  });

  /// Конструктор с указанием Duration от текущего момента
  factory RpcDeadlineMarker.fromDuration(Duration timeout) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return RpcDeadlineMarker(
      deadlineTimestamp: now + timeout.inMilliseconds,
    );
  }

  /// Проверяет, истек ли срок
  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= deadlineTimestamp;

  /// Возвращает оставшееся время
  Duration get remaining {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = deadlineTimestamp - now;
    if (remaining <= 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: remaining);
  }

  @override
  RpcMarkerType get markerType => RpcMarkerType.deadline;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['deadlineTimestamp'] = deadlineTimestamp;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcDeadlineMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.deadline.name) {
      throw FormatException('Неверный формат маркера deadline');
    }

    return RpcDeadlineMarker(
      deadlineTimestamp: json['deadlineTimestamp'] as int,
    );
  }
}
