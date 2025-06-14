// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:io';
import 'dart:async';

/// Обработчик системных сигналов
///
/// Поддерживает:
/// - SIGINT (Ctrl+C) - graceful shutdown
/// - SIGTERM - graceful shutdown
/// - SIGHUP - reload конфигурации
/// - SIGUSR1 - вывод статистики
/// - SIGUSR2 - переключение уровня логирования
class SignalHandler {
  final StreamController<SignalType> _signalController = StreamController.broadcast();

  /// Стрим сигналов для подписки
  Stream<SignalType> get signals => _signalController.stream;

  /// Completer для ожидания shutdown сигнала
  final Completer<void> _shutdownCompleter = Completer<void>();

  /// Флаги состояния
  bool _shutdownInitiated = false;
  int _interruptCount = 0;

  /// Колбэки для обработки сигналов
  void Function()? onReload;
  void Function()? onStats;
  void Function()? onToggleDebug;

  SignalHandler();

  /// Инициализирует обработку сигналов
  void initialize() {
    _setupSignalHandlers();
  }

  /// Ожидает сигнал завершения
  Future<void> waitForShutdown() async {
    await _shutdownCompleter.future;
  }

  /// Настраивает обработчики сигналов
  void _setupSignalHandlers() {
    // SIGINT (Ctrl+C) - graceful shutdown
    ProcessSignal.sigint.watch().listen(_handleSigint);

    // SIGTERM - graceful shutdown
    ProcessSignal.sigterm.watch().listen(_handleSigterm);

    // SIGHUP - reload конфигурации (только Unix)
    if (Platform.isLinux || Platform.isMacOS) {
      ProcessSignal.sighup.watch().listen(_handleSighup);

      // SIGUSR1 - вывод статистики
      ProcessSignal.sigusr1.watch().listen(_handleSigusr1);

      // SIGUSR2 - переключение debug режима
      ProcessSignal.sigusr2.watch().listen(_handleSigusr2);
    }
  }

  /// Обрабатывает SIGINT (Ctrl+C)
  void _handleSigint(ProcessSignal signal) {
    _interruptCount++;

    if (!_shutdownInitiated) {
      _shutdownInitiated = true;
      print('\n🛑 Получен сигнал SIGINT, graceful shutdown...');
      _signalController.add(SignalType.shutdown);

      if (!_shutdownCompleter.isCompleted) {
        _shutdownCompleter.complete();
      }
    } else if (_interruptCount >= 2) {
      print('\n⚡ Повторный SIGINT - принудительное завершение!');
      _signalController.add(SignalType.forceShutdown);
      exit(130); // Код выхода для SIGINT
    } else {
      print(
          '\n⏳ Graceful shutdown уже в процессе. Повторный Ctrl+C для принудительного завершения...');
    }
  }

  /// Обрабатывает SIGTERM
  void _handleSigterm(ProcessSignal signal) {
    if (!_shutdownInitiated) {
      _shutdownInitiated = true;
      print('\n🛑 Получен сигнал SIGTERM, graceful shutdown...');
      _signalController.add(SignalType.shutdown);

      if (!_shutdownCompleter.isCompleted) {
        _shutdownCompleter.complete();
      }
    } else {
      print('\n⚡ Повторный SIGTERM - принудительное завершение!');
      _signalController.add(SignalType.forceShutdown);
      exit(143); // Код выхода для SIGTERM
    }
  }

  /// Обрабатывает SIGHUP (reload)
  void _handleSighup(ProcessSignal signal) {
    print('\n🔄 Получен сигнал SIGHUP, перезагрузка конфигурации...');
    _signalController.add(SignalType.reload);
    onReload?.call();
  }

  /// Обрабатывает SIGUSR1 (статистика)
  void _handleSigusr1(ProcessSignal signal) {
    print('\n📊 Получен сигнал SIGUSR1, вывод статистики...');
    _signalController.add(SignalType.stats);
    onStats?.call();
  }

  /// Обрабатывает SIGUSR2 (переключение debug)
  void _handleSigusr2(ProcessSignal signal) {
    print('\n🐛 Получен сигнал SIGUSR2, переключение debug режима...');
    _signalController.add(SignalType.toggleDebug);
    onToggleDebug?.call();
  }

  /// Освобождает ресурсы
  Future<void> dispose() async {
    await _signalController.close();
  }
}

/// Типы сигналов
enum SignalType {
  /// Graceful shutdown (SIGINT, SIGTERM)
  shutdown,

  /// Принудительное завершение
  forceShutdown,

  /// Перезагрузка конфигурации (SIGHUP)
  reload,

  /// Вывод статистики (SIGUSR1)
  stats,

  /// Переключение debug режима (SIGUSR2)
  toggleDebug;

  /// Отображаемое имя сигнала
  String get displayName {
    switch (this) {
      case SignalType.shutdown:
        return 'Graceful Shutdown';
      case SignalType.forceShutdown:
        return 'Force Shutdown';
      case SignalType.reload:
        return 'Reload Configuration';
      case SignalType.stats:
        return 'Show Statistics';
      case SignalType.toggleDebug:
        return 'Toggle Debug Mode';
    }
  }
}

/// Утилиты для работы с сигналами в daemon режиме
class DaemonSignals {
  /// Отправляет сигнал процессу по PID
  static bool sendSignal(int pid, ProcessSignal signal) {
    try {
      return Process.killPid(pid, signal);
    } catch (e) {
      return false;
    }
  }

  /// Проверяет, запущен ли процесс с указанным PID
  static bool isProcessRunning(int pid) {
    try {
      // Используем ps команду для проверки
      final result = Process.runSync('ps', ['-p', pid.toString()]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Отправляет SIGHUP для перезагрузки
  static bool reloadDaemon(int pid) {
    print('🔄 Отправка SIGHUP процессу $pid...');
    return sendSignal(pid, ProcessSignal.sighup);
  }

  /// Отправляет SIGUSR1 для статистики
  static bool requestStats(int pid) {
    print('📊 Запрос статистики у процесса $pid...');
    return sendSignal(pid, ProcessSignal.sigusr1);
  }

  /// Отправляет SIGUSR2 для переключения debug
  static bool toggleDebug(int pid) {
    print('🐛 Переключение debug режима у процесса $pid...');
    return sendSignal(pid, ProcessSignal.sigusr2);
  }

  /// Graceful остановка daemon (SIGTERM -> SIGKILL)
  static Future<bool> gracefulStop(int pid,
      {Duration timeout = const Duration(seconds: 10)}) async {
    print('🛑 Graceful остановка процесса $pid...');

    // Отправляем SIGTERM
    if (!sendSignal(pid, ProcessSignal.sigterm)) {
      print('❌ Не удалось отправить SIGTERM');
      return false;
    }

    // Ждем завершения процесса
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      if (!isProcessRunning(pid)) {
        print('✅ Процесс завершился gracefully');
        return true;
      }
      await Future.delayed(Duration(milliseconds: 100));
    }

    // Если процесс не завершился, отправляем SIGKILL
    print('⚠️  Процесс не завершился за ${timeout.inSeconds}с, отправляем SIGKILL...');
    if (sendSignal(pid, ProcessSignal.sigkill)) {
      // Ждем еще немного после SIGKILL
      await Future.delayed(Duration(milliseconds: 500));
      if (!isProcessRunning(pid)) {
        print('✅ Процесс принудительно завершен');
        return true;
      }
    }

    print('❌ Не удалось остановить процесс');
    return false;
  }

  /// Проверяет статус процесса с детальной информацией
  static Future<ProcessStatus?> getProcessStatus(int pid) async {
    try {
      if (!isProcessRunning(pid)) {
        return null;
      }

      // Получаем детальную информацию о процессе
      final result =
          await Process.run('ps', ['-o', 'pid,ppid,etime,rss,pcpu,command', '-p', pid.toString()]);

      if (result.exitCode == 0) {
        final lines = result.stdout.toString().trim().split('\n');
        if (lines.length >= 2) {
          final parts = lines[1].trim().split(RegExp(r'\s+'));
          if (parts.length >= 6) {
            return ProcessStatus(
              pid: int.parse(parts[0]),
              ppid: int.parse(parts[1]),
              uptime: parts[2],
              memoryKB: int.parse(parts[3]),
              cpuPercent: double.parse(parts[4]),
              command: parts.sublist(5).join(' '),
            );
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки
    }
    return null;
  }
}

/// Статус процесса
class ProcessStatus {
  final int pid;
  final int ppid;
  final String uptime;
  final int memoryKB;
  final double cpuPercent;
  final String command;

  const ProcessStatus({
    required this.pid,
    required this.ppid,
    required this.uptime,
    required this.memoryKB,
    required this.cpuPercent,
    required this.command,
  });

  @override
  String toString() {
    return 'ProcessStatus(pid: $pid, ppid: $ppid, uptime: $uptime, memory: ${(memoryKB / 1024).toStringAsFixed(1)}MB, cpu: $cpuPercent%, command: $command)';
  }
}
