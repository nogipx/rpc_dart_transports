#!/usr/bin/env dart
// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'router/cli.dart';

const String version = '2.0.0';

/// Главная функция роутера
/// RPC Dart Router - HTTP/2 gRPC роутер для RPC вызовов
///
/// Главный entry point для запуска роутера с полной production обвязкой:
/// - CLI парсинг с командами help/version/daemon
/// - Daemon режим с PID файлами и управлением процессами
/// - Обработка сигналов (SIGINT/SIGTERM для shutdown, SIGHUP для reload)
/// - Graceful shutdown с таймаутами
/// - Комплексное логирование в файлы и консоль
/// - Мониторинг состояния и статистики
/// - HTTP/2 gRPC сервер с автоматической регистрацией контрактов
Future<void> main(List<String> arguments) async {
  // Обрабатываем все ошибки на верхнем уровне
  runZonedGuarded<void>(
    () => _runRouter(arguments),
    (error, stackTrace) => _handleGlobalError(error, stackTrace),
  );
}

/// Запускает роутер с обработкой ошибок
Future<void> _runRouter(List<String> arguments) async {
  try {
    // Создаем и инициализируем CLI
    final cli = await RouterCLI.create(arguments);

    // Запускаем роутер
    await cli.run();
  } catch (e, stackTrace) {
    _handleGlobalError(e, stackTrace);
    exit(1);
  }
}

/// Обрабатывает глобальные ошибки
void _handleGlobalError(Object error, StackTrace stackTrace) {
  final timestamp = DateTime.now().toIso8601String();

  stderr.writeln('🚨 === КРИТИЧЕСКАЯ ОШИБКА РОУТЕРА ===');
  stderr.writeln('❌ Время: $timestamp');
  stderr.writeln('💥 Ошибка: $error');
  stderr.writeln('📍 Stack trace:');
  stderr.writeln(stackTrace.toString());
  stderr.writeln('=' * 50);
  stderr.writeln('💡 Попробуйте:');
  stderr.writeln('   • Проверить права доступа к файлам');
  stderr.writeln('   • Убедиться что порт не занят');
  stderr.writeln('   • Запустить с --verbose для детальной диагностики');
  stderr.writeln('   • Проверить логи системы');

  // Принудительное завершение с кодом ошибки
  exit(1);
}
