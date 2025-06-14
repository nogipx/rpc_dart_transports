// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:io';
import 'dart:async';

import 'config.dart';
import 'signals.dart';

/// Менеджер daemon режима роутера
///
/// Обеспечивает:
/// - Демонизацию процесса (только Unix)
/// - Управление PID файлом
/// - Проверку статуса daemon
/// - Graceful остановку
/// - Перезагрузку конфигурации
/// - Production-ready логирование
class DaemonManager {
  final RouterConfig config;

  const DaemonManager({required this.config});

  /// Демонизирует текущий процесс
  Future<void> daemonize() async {
    if (!Platform.isLinux && !Platform.isMacOS) {
      throw UnsupportedError('Режим daemon поддерживается только на Linux и macOS');
    }

    print('🔄 Запуск в режиме daemon...');

    // Получаем путь к текущему исполняемому файлу
    final scriptPath = Platform.script.toFilePath();

    // Создаем аргументы для дочернего процесса
    final childArgs = _buildChildArgs();

    // Настройка файлов логов
    final logFile = config.defaultLogFile;
    final pidFile = config.defaultPidFile;

    try {
      // Проверяем что daemon не запущен уже
      await _checkExistingDaemon(pidFile);

      // Создаем лог файл заранее
      await _ensureLogFile(logFile);

      // Записываем начальную запись о запуске
      await _logStartup(logFile);

      // Запускаем дочерний процесс в detached режиме
      final process = await _startDetachedProcess(scriptPath, childArgs);

      // Ждем и проверяем что процесс запустился
      await _verifyProcessStart(process, logFile);

      // Сохраняем PID
      await _savePidFile(pidFile, process.pid);

      // Логируем успешный запуск
      await _logSuccess(logFile, process.pid, pidFile);

      print('✅ Daemon запущен с PID: ${process.pid}');
      print('📄 PID файл: $pidFile');
      print('📝 Логи: $logFile');
      print('💡 Используйте --daemon-status для проверки состояния');
      print('💡 Используйте --daemon-stop для остановки');

      // Родительский процесс завершается
      exit(0);
    } catch (e) {
      print('❌ Ошибка демонизации: $e');
      await _logError(logFile, 'Daemon startup failed: $e');
      exit(1);
    }
  }

  /// Останавливает daemon
  Future<void> stop() async {
    final pidFile = config.defaultPidFile;

    if (!await File(pidFile).exists()) {
      print('❌ PID файл не найден: $pidFile');
      print('💡 Daemon возможно не запущен');
      exit(1);
    }

    try {
      final pid = await _readPidFile(pidFile);
      print('🛑 Остановка daemon с PID: $pid');

      // Проверяем что процесс существует
      if (!DaemonSignals.isProcessRunning(pid)) {
        print('❌ Процесс с PID $pid не найден');
        await _cleanupPidFile(pidFile);
        print('🧹 PID файл удален');
        exit(1);
      }

      // Отправляем SIGTERM
      print('🛑 Отправка SIGTERM процессу $pid...');
      final terminated = DaemonSignals.sendSignal(pid, ProcessSignal.sigterm);

      if (!terminated) {
        print('❌ Не удалось отправить SIGTERM');
        exit(1);
      }

      // Ждем завершения процесса
      final stopped = await _waitForProcessStop(pid, Duration(seconds: 10));

      if (stopped) {
        // Удаляем PID файл
        await _cleanupPidFile(pidFile);
        print('✅ Daemon остановлен');
      } else {
        print('⚠️  Процесс не завершился за 10 секунд, отправляем SIGKILL...');
        final killed = DaemonSignals.sendSignal(pid, ProcessSignal.sigkill);

        if (killed) {
          await _cleanupPidFile(pidFile);
          print('✅ Daemon принудительно остановлен');
        } else {
          print('❌ Не удалось остановить daemon');
          exit(1);
        }
      }
    } catch (e) {
      print('❌ Ошибка остановки daemon: $e');
      await _cleanupInvalidPid(pidFile);
      exit(1);
    }
  }

  /// Показывает статус daemon
  Future<void> status() async {
    final pidFile = config.defaultPidFile;

    if (!await File(pidFile).exists()) {
      print('❌ Daemon не запущен (PID файл не найден)');
      exit(1);
    }

    try {
      final pid = await _readPidFile(pidFile);

      if (DaemonSignals.isProcessRunning(pid)) {
        print('✅ Daemon запущен с PID: $pid');
        print('📄 PID файл: $pidFile');

        final logFile = config.defaultLogFile;
        print('📝 Логи: $logFile');

        // Показываем дополнительную информацию
        await _showExtendedStatus(pid, logFile);
      } else {
        print('❌ Процесс с PID $pid не найден');
        print('🔧 Удаляем устаревший PID файл...');
        await _cleanupPidFile(pidFile);
        exit(1);
      }
    } catch (e) {
      print('❌ Ошибка проверки статуса: $e');
      exit(1);
    }
  }

  /// Перезагружает daemon (отправляет SIGHUP)
  Future<void> reload() async {
    final pidFile = config.defaultPidFile;

    if (!await File(pidFile).exists()) {
      print('❌ Daemon не запущен (PID файл не найден)');
      exit(1);
    }

    try {
      final pid = await _readPidFile(pidFile);

      if (DaemonSignals.isProcessRunning(pid)) {
        print('🔄 Отправка SIGHUP процессу $pid...');
        final sent = DaemonSignals.sendSignal(pid, ProcessSignal.sighup);

        if (sent) {
          print('✅ Сигнал перезагрузки отправлен daemon с PID: $pid');

          // Логируем в файл
          final logFile = config.defaultLogFile;
          await _logReload(logFile, pid);
        } else {
          print('❌ Не удалось отправить сигнал перезагрузки');
          exit(1);
        }
      } else {
        print('❌ Процесс с PID $pid не найден');
        await _cleanupPidFile(pidFile);
        exit(1);
      }
    } catch (e) {
      print('❌ Ошибка перезагрузки daemon: $e');
      exit(1);
    }
  }

  // === ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ===

  /// Проверяет что daemon не запущен уже
  Future<void> _checkExistingDaemon(String pidFile) async {
    if (await File(pidFile).exists()) {
      try {
        final pid = await _readPidFile(pidFile);
        if (DaemonSignals.isProcessRunning(pid)) {
          throw Exception('Daemon уже запущен с PID: $pid');
        } else {
          // Удаляем устаревший PID файл
          await _cleanupPidFile(pidFile);
          print('🧹 Удален устаревший PID файл');
        }
      } catch (e) {
        if (e.toString().contains('уже запущен')) rethrow;
        // Игнорируем ошибки чтения PID файла
        await _cleanupPidFile(pidFile);
      }
    }
  }

  /// Создает аргументы для дочернего процесса
  List<String> _buildChildArgs() {
    // Берем текущие аргументы и модифицируем их
    final args = Platform.executableArguments.toList();

    // Убираем daemon команды и добавляем внутренний флаг
    args.removeWhere((arg) => arg == '--daemon-start' || arg == '--daemon' || arg == '-d');
    args.add('--_daemon-child');

    return args;
  }

  /// Обеспечивает существование лог файла
  Future<void> _ensureLogFile(String logFile) async {
    final file = File(logFile);
    await file.create(recursive: true);

    // Устанавливаем права доступа (только для владельца)
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['600', logFile]);
      } catch (e) {
        // Игнорируем ошибки chmod
      }
    }
  }

  /// Логирует начало запуска
  Future<void> _logStartup(String logFile) async {
    final timestamp = DateTime.now().toIso8601String();
    final startMessage = '''
$timestamp: ===== RPC Dart Router Daemon Startup =====
$timestamp: Version: 2.0.0
$timestamp: Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
$timestamp: Dart: ${Platform.version}
$timestamp: PID: ${pid}
$timestamp: Working Directory: ${Directory.current.path}
$timestamp: Arguments: ${Platform.executableArguments.join(' ')}
$timestamp: ================================================
''';
    await File(logFile).writeAsString(startMessage, mode: FileMode.writeOnlyAppend);
  }

  /// Логирует ошибку
  Future<void> _logError(String logFile, String error) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final errorMessage = '$timestamp: [ERROR] $error\n';
      await File(logFile).writeAsString(errorMessage, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // Игнорируем ошибки логирования
    }
  }

  /// Логирует перезагрузку
  Future<void> _logReload(String logFile, int pid) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final reloadMessage = '$timestamp: [INFO] Reload signal sent to daemon PID: $pid\n';
      await File(logFile).writeAsString(reloadMessage, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // Игнорируем ошибки логирования
    }
  }

  /// Запускает detached процесс
  Future<Process> _startDetachedProcess(String scriptPath, List<String> childArgs) async {
    return await Process.start(
      Platform.resolvedExecutable,
      [scriptPath, ...childArgs],
      mode: ProcessStartMode.detached,
      runInShell: false,
      workingDirectory: Directory.current.path,
    );
  }

  /// Проверяет что процесс запустился
  Future<void> _verifyProcessStart(Process process, String logFile) async {
    // Ждем немного чтобы убедиться что процесс запустился
    await Future.delayed(Duration(milliseconds: 1000));

    if (!DaemonSignals.isProcessRunning(process.pid)) {
      await _logError(logFile, 'Child process failed to start or exited immediately');
      throw Exception('Дочерний процесс не запустился или завершился');
    }
  }

  /// Ждет завершения процесса
  Future<bool> _waitForProcessStop(int pid, Duration timeout) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      if (!DaemonSignals.isProcessRunning(pid)) {
        return true;
      }
      await Future.delayed(Duration(milliseconds: 100));
    }

    return false;
  }

  /// Сохраняет PID файл
  Future<void> _savePidFile(String pidFile, int pid) async {
    await File(pidFile).writeAsString('$pid');

    // Устанавливаем права доступа (только для владельца)
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['600', pidFile]);
      } catch (e) {
        // Игнорируем ошибки chmod
      }
    }
  }

  /// Логирует успешный запуск
  Future<void> _logSuccess(String logFile, int pid, String pidFile) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '''
$timestamp: [INFO] Daemon successfully started
$timestamp: [INFO] Child PID: $pid
$timestamp: [INFO] PID file: $pidFile
$timestamp: [INFO] Parent process exiting
$timestamp: ================================================
''';
      await File(logFile).writeAsString(logEntry, mode: FileMode.writeOnlyAppend);
    } catch (e) {
      // Игнорируем ошибки логирования на этом этапе
    }
  }

  /// Читает PID из файла
  Future<int> _readPidFile(String pidFile) async {
    final pidStr = await File(pidFile).readAsString();
    return int.parse(pidStr.trim());
  }

  /// Удаляет PID файл
  Future<void> _cleanupPidFile(String pidFile) async {
    try {
      await File(pidFile).delete();
    } catch (e) {
      // Игнорируем ошибки удаления
    }
  }

  /// Очищает невалидный PID файл
  Future<void> _cleanupInvalidPid(String pidFile) async {
    try {
      final pidStr = await File(pidFile).readAsString();
      final pid = int.parse(pidStr.trim());

      if (!DaemonSignals.isProcessRunning(pid)) {
        await _cleanupPidFile(pidFile);
        print('🧹 PID файл удален (процесс не найден)');
      }
    } catch (e) {
      // Игнорируем ошибки
      await _cleanupPidFile(pidFile);
    }
  }

  /// Показывает расширенную информацию о статусе
  Future<void> _showExtendedStatus(int pid, String logFile) async {
    // Показываем информацию о лог-файле
    if (await File(logFile).exists()) {
      final stat = await File(logFile).stat();
      print('📊 Размер лог-файла: ${_formatBytes(stat.size)}');
      print('🕐 Последнее изменение: ${stat.modified}');

      // Показываем последние строки лога
      await _showRecentLogs(logFile);
    }

    // Показываем использование памяти процесса
    final memoryInfo = await _getProcessMemory(pid);
    if (memoryInfo != null) {
      print('💾 Использование памяти: $memoryInfo');
    }

    // Показываем время работы
    final uptime = await _getProcessUptime(pid);
    if (uptime != null) {
      print('⏱️  Время работы: $uptime');
    }

    // Показываем открытые порты
    await _showOpenPorts(pid);
  }

  /// Показывает последние строки лога
  Future<void> _showRecentLogs(String logFile) async {
    try {
      final result = await Process.run('tail', ['-n', '3', logFile]);
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        print('📝 Последние записи лога:');
        final lines = result.stdout.toString().trim().split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            print('   $line');
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки чтения лога
    }
  }

  /// Показывает открытые порты процесса
  Future<void> _showOpenPorts(int pid) async {
    try {
      final result = await Process.run('lsof', ['-Pan', '-p', pid.toString(), '-i']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        final portLines = lines.where((line) => line.contains('LISTEN')).toList();

        if (portLines.isNotEmpty) {
          print('🔌 Открытые порты:');
          for (final line in portLines) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length > 8) {
              final port = parts[8];
              print('   • $port');
            }
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки lsof
    }
  }

  /// Форматирует размер в байтах
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Получает информацию о памяти процесса
  Future<String?> _getProcessMemory(int pid) async {
    try {
      final result = await Process.run('ps', ['-o', 'rss=', '-p', pid.toString()]);
      if (result.exitCode == 0) {
        final rss = int.tryParse(result.stdout.toString().trim()) ?? 0;
        return '${(rss / 1024).toStringAsFixed(1)}MB';
      }
    } catch (e) {
      // Игнорируем ошибки получения памяти
    }
    return null;
  }

  /// Получает время работы процесса
  Future<String?> _getProcessUptime(int pid) async {
    try {
      final result = await Process.run('ps', ['-o', 'etime=', '-p', pid.toString()]);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (e) {
      // Игнорируем ошибки получения uptime
    }
    return null;
  }
}
