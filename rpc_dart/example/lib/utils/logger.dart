// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/diagnostics.dart';

/// Класс для логирования в примерах
class ExampleLogger {
  /// Название примера
  final String name;

  /// Создает логгер для примера
  ExampleLogger(this.name);

  /// Выводит информационное сообщение
  void info(String message) {
    RpcLog.info(message: message, source: name);
  }

  /// Выводит отладочное сообщение
  void debug(String message) {
    RpcLog.debug(message: message, source: name);
  }

  /// Выводит предупреждение
  void warning(String message) {
    RpcLog.warning(message: message, source: name);
  }

  /// Выводит сообщение об ошибке
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    RpcLog.error(
      message: message,
      source: name,
      error: error != null ? {'error': error.toString()} : null,
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Выводит эмодзи сообщение с указанным префиксом
  void emoji(String emoji, String message) {
    RpcLog.info(message: "$emoji $message", source: name);
  }

  /// Выводит заголовок раздела
  void section(String title) {
    final line = '─' * 60;
    RpcLog.info(message: '\n┌$line┐', source: name);
    RpcLog.info(message: '│ $title', source: name);
    RpcLog.info(message: '└$line┘\n', source: name);
  }

  /// Выводит строку прогресса
  void progress(
    int current,
    int total, {
    String prefix = '',
    String suffix = '',
  }) {
    final percent = (current / total * 100).round();
    final width = 40;
    final completed = (width * current / total).round();
    final remaining = width - completed;

    final bar = '█' * completed + '░' * remaining;

    RpcLog.info(message: '$prefix [$bar] $percent% $suffix', source: name);
  }

  /// Выводит список с маркерами
  void bulletList(List<String> items) {
    for (final item in items) {
      RpcLog.info(message: '  • $item', source: name);
    }
  }
}
