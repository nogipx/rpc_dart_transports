// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_logs.dart';

/// Уровни логирования
enum RpcLogLevel {
  debug,
  info,
  warning,
  error,
  critical,
  none;

  /// Создание из строки JSON
  static RpcLogLevel fromJson(String json) {
    return values.firstWhere(
      (e) => e.name == json,
      orElse: () => none,
    );
  }
}
