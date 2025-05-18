// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Исключение, связанное со статусом RPC
class RpcStatusException implements Exception {
  /// Код статуса
  final RpcStatusCode code;

  /// Сообщение об ошибке
  final String message;

  /// Дополнительные детали
  final Map<String, dynamic>? details;

  /// Создает исключение со статусом RPC
  const RpcStatusException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('RpcStatusException: [${code.name}] $message');
    if (details != null && details!.isNotEmpty) {
      buffer.write(' (details: $details)');
    }
    return buffer.toString();
  }

  /// Создает маркер статуса из этого исключения
  RpcStatusMarker toMarker() {
    return RpcStatusMarker(
      code: code,
      message: message,
      details: details,
    );
  }

  /// Создает исключение из маркера статуса
  factory RpcStatusException.fromMarker(RpcStatusMarker marker) {
    return RpcStatusException(
      code: marker.code,
      message: marker.message,
      details: marker.details,
    );
  }
}
