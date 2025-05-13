// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Интерфейс логгера для RPC методов
abstract class RpcMethodLogger {
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
class PrintRpcMethodLogger implements RpcMethodLogger {
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
class SilentRpcMethodLogger implements RpcMethodLogger {
  @override
  void info(String message) {}

  @override
  void warning(String message) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void debug(String message) {}
}

/// Глобальный логгер для использования во всех классах RPC методов
RpcMethodLogger rpcMethodLogger = PrintRpcMethodLogger();

/// Устанавливает глобальный логгер для всех классов RPC методов
void setRpcMethodLogger(RpcMethodLogger logger) {
  rpcMethodLogger = logger;
}
