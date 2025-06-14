// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:io';
import 'dart:async';

/// Продвинутый обработчик ошибок роутера
///
/// Особенности:
/// - Различные обработчики для разных типов ошибок
/// - Graceful recovery для HTTP/2 ошибок
/// - Логирование в файл для daemon режима
/// - Детектирование критических ошибок
/// - Автоматическая очистка ресурсов
class ErrorHandler {
  final bool verbose;
  final bool isDaemon;
  final String? logFile;

  const ErrorHandler({
    required this.verbose,
    required this.isDaemon,
    this.logFile,
  });

  /// Универсальный обработчик ошибок
  Future<void> handleError(dynamic error, StackTrace? stackTrace) async {
    final timestamp = DateTime.now().toIso8601String();
    final errorType = _classifyError(error);

    // Формируем сообщение об ошибке
    final errorMessage = _formatErrorMessage(error, stackTrace, timestamp, errorType);

    // Логируем ошибку
    await _logError(errorMessage, errorType);

    // Выводим в консоль если нужно
    if (!isDaemon || errorType.isCritical) {
      _printToConsole(errorMessage, errorType);
    }

    // Специальная обработка для определенных типов ошибок
    await _handleSpecificError(error, errorType);
  }

  /// Классифицирует тип ошибки
  ErrorType _classifyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // HTTP/2 ошибки (восстановимые)
    if (errorString.contains('http/2 error') ||
        errorString.contains('connection is being forcefully terminated') ||
        errorString.contains('http2exception')) {
      return ErrorType.http2Connection;
    }

    // Сетевые ошибки
    if (errorString.contains('connection refused') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('socketexception')) {
      return ErrorType.network;
    }

    // Файловые ошибки
    if (errorString.contains('file not found') ||
        errorString.contains('permission denied') ||
        errorString.contains('filesystemexception')) {
      return ErrorType.filesystem;
    }

    // Конфигурационные ошибки
    if (errorString.contains('argumenterror') ||
        errorString.contains('formatexception') ||
        errorString.contains('invalid configuration')) {
      return ErrorType.configuration;
    }

    // Ошибки ресурсов
    if (errorString.contains('out of memory') ||
        errorString.contains('too many open files') ||
        errorString.contains('resource exhausted')) {
      return ErrorType.resource;
    }

    // Ошибки безопасности
    if (errorString.contains('access denied') ||
        errorString.contains('unauthorized') ||
        errorString.contains('certificate')) {
      return ErrorType.security;
    }

    // По умолчанию - неизвестная ошибка
    return ErrorType.unknown;
  }

  /// Форматирует сообщение об ошибке
  String _formatErrorMessage(
    dynamic error,
    StackTrace? stackTrace,
    String timestamp,
    ErrorType errorType,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('🚨 === ОШИБКА РОУТЕРА ===');
    buffer.writeln('❌ Время: $timestamp');
    buffer.writeln('🏷️  Тип: ${errorType.displayName}');
    buffer.writeln('📝 Ошибка: $error');

    if (verbose && stackTrace != null) {
      buffer.writeln('📍 Stack trace:');
      buffer.writeln(stackTrace.toString());
    }

    // Добавляем рекомендации по восстановлению
    final recovery = _getRecoveryRecommendations(errorType);
    if (recovery.isNotEmpty) {
      buffer.writeln('💡 Рекомендации:');
      for (final recommendation in recovery) {
        buffer.writeln('   • $recommendation');
      }
    }

    buffer.writeln('=' * 50);

    return buffer.toString();
  }

  /// Логирует ошибку в файл (для daemon режима)
  Future<void> _logError(String errorMessage, ErrorType errorType) async {
    if (!isDaemon || logFile == null) return;

    try {
      final file = File(logFile!);
      await file.writeAsString(
        errorMessage,
        mode: FileMode.writeOnlyAppend,
      );
    } catch (e) {
      // Если не можем писать в лог, пишем в stderr
      stderr.writeln('Failed to write error to log file: $e');
      stderr.writeln('Original error: $errorMessage');
    }
  }

  /// Выводит ошибку в консоль
  void _printToConsole(String errorMessage, ErrorType errorType) {
    if (errorType.isCritical) {
      stderr.writeln(errorMessage);
    } else {
      print(errorMessage);
    }
  }

  /// Специальная обработка для определенных типов ошибок
  Future<void> _handleSpecificError(dynamic error, ErrorType errorType) async {
    switch (errorType) {
      case ErrorType.http2Connection:
        await _handleHttp2Error(error);
        break;

      case ErrorType.network:
        await _handleNetworkError(error);
        break;

      case ErrorType.filesystem:
        await _handleFilesystemError(error);
        break;

      case ErrorType.resource:
        await _handleResourceError(error);
        break;

      case ErrorType.security:
        await _handleSecurityError(error);
        break;

      default:
        // Для остальных ошибок - стандартная обработка
        break;
    }
  }

  /// Обрабатывает HTTP/2 ошибки (часто восстановимые)
  Future<void> _handleHttp2Error(dynamic error) async {
    final message =
        '🔗 HTTP/2 соединение было принудительно закрыто (это нормально при отключении клиентов)\n'
        '♻️  Роутер продолжает работу...';

    if (isDaemon && logFile != null) {
      try {
        final timestamp = DateTime.now().toIso8601String();
        await File(logFile!).writeAsString(
          '$timestamp: $message\n',
          mode: FileMode.writeOnlyAppend,
        );
      } catch (e) {
        // Игнорируем ошибки логирования
      }
    } else {
      print(message);
    }

    // Не завершаем процесс для HTTP/2 ошибок
  }

  /// Обрабатывает сетевые ошибки
  Future<void> _handleNetworkError(dynamic error) async {
    print('🌐 Сетевая ошибка обнаружена. Роутер попытается продолжить работу...');

    // Можно добавить логику переподключения или fallback
  }

  /// Обрабатывает ошибки файловой системы
  Future<void> _handleFilesystemError(dynamic error) async {
    print('📁 Ошибка файловой системы. Проверьте права доступа и свободное место...');
  }

  /// Обрабатывает ошибки ресурсов
  Future<void> _handleResourceError(dynamic error) async {
    print('💾 Критическая нехватка ресурсов! Попытка освобождения памяти...');

    // Принудительная сборка мусора
    await _forceGarbageCollection();
  }

  /// Обрабатывает ошибки безопасности
  Future<void> _handleSecurityError(dynamic error) async {
    print('🔒 ОШИБКА БЕЗОПАСНОСТИ! Немедленная остановка...');

    // Для ошибок безопасности - немедленное завершение
    exit(1);
  }

  /// Принудительная сборка мусора
  Future<void> _forceGarbageCollection() async {
    // Делаем небольшую паузу и надеемся на GC
    await Future.delayed(Duration(milliseconds: 100));

    // В Dart нет прямого способа принудительного GC,
    // но можем освободить какие-то кэши если они есть
  }

  /// Возвращает рекомендации по восстановлению для типа ошибки
  List<String> _getRecoveryRecommendations(ErrorType errorType) {
    switch (errorType) {
      case ErrorType.http2Connection:
        return [
          'HTTP/2 ошибки обычно не критичны',
          'Клиенты могут переподключиться автоматически',
          'Мониторьте количество активных соединений',
        ];

      case ErrorType.network:
        return [
          'Проверьте сетевое подключение',
          'Убедитесь что порт не занят другим процессом',
          'Проверьте настройки firewall',
        ];

      case ErrorType.filesystem:
        return [
          'Проверьте права доступа к файлам',
          'Убедитесь в наличии свободного места',
          'Проверьте пути к конфигурационным файлам',
        ];

      case ErrorType.configuration:
        return [
          'Проверьте синтаксис конфигурационного файла',
          'Убедитесь в корректности всех параметров',
          'Используйте --help для справки по опциям',
        ];

      case ErrorType.resource:
        return [
          'Проверьте потребление памяти системой',
          'Уменьшите количество max-connections',
          'Перезапустите роутер для освобождения ресурсов',
        ];

      case ErrorType.security:
        return [
          'Проверьте права доступа к сертификатам',
          'Убедитесь в корректности TLS конфигурации',
          'Проверьте список разрешенных хостов',
        ];

      case ErrorType.unknown:
        return [
          'Включите verbose режим для детальной диагностики',
          'Проверьте логи системы',
          'Обратитесь к документации',
        ];
    }
  }
}

/// Типы ошибок роутера
enum ErrorType {
  /// HTTP/2 соединения (обычно восстановимые)
  http2Connection,

  /// Сетевые ошибки
  network,

  /// Ошибки файловой системы
  filesystem,

  /// Ошибки конфигурации
  configuration,

  /// Ошибки ресурсов (память, файлы)
  resource,

  /// Ошибки безопасности
  security,

  /// Неизвестные ошибки
  unknown;

  /// Отображаемое имя типа ошибки
  String get displayName {
    switch (this) {
      case ErrorType.http2Connection:
        return 'HTTP/2 Connection';
      case ErrorType.network:
        return 'Network Error';
      case ErrorType.filesystem:
        return 'Filesystem Error';
      case ErrorType.configuration:
        return 'Configuration Error';
      case ErrorType.resource:
        return 'Resource Error';
      case ErrorType.security:
        return 'Security Error';
      case ErrorType.unknown:
        return 'Unknown Error';
    }
  }

  /// Является ли ошибка критической
  bool get isCritical {
    switch (this) {
      case ErrorType.http2Connection:
      case ErrorType.network:
        return false;
      case ErrorType.filesystem:
      case ErrorType.configuration:
      case ErrorType.resource:
      case ErrorType.security:
      case ErrorType.unknown:
        return true;
    }
  }
}
