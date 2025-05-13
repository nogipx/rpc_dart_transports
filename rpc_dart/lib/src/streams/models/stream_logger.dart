part of '../_index.dart';

/// Интерфейс логгера для потоков
abstract class StreamLogger {
  /// Логгирует сообщение уровня info
  void info(String message);

  /// Логгирует сообщение уровня warning (предупреждение)
  void warning(String message);

  /// Логгирует сообщение уровня error (ошибка)
  void error(String message, [Object? error, StackTrace? stackTrace]);

  /// Логгирует сообщение уровня debug (отладка)
  void debug(String message);
}

/// Реализация логгера, которая отправляет все сообщения в print
class PrintStreamLogger implements StreamLogger {
  @override
  void info(String message) {
    print('[INFO] $message');
  }

  @override
  void warning(String message) {
    print('[WARN] $message');
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('[ERROR] $message');
    if (error != null) {
      print('Error details: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  @override
  void debug(String message) {
    print('[DEBUG] $message');
  }
}

/// Тихий логгер, который игнорирует все сообщения
class SilentStreamLogger implements StreamLogger {
  @override
  void info(String message) {}

  @override
  void warning(String message) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void debug(String message) {}
}

/// Глобальный логгер для использования во всех классах потоков
StreamLogger streamLogger = PrintStreamLogger();

/// Устанавливает глобальный логгер для всех классов потоков
void setStreamLogger(StreamLogger logger) {
  streamLogger = logger;
}
