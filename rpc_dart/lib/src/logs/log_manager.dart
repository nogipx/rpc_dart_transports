// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_logs.dart';

/// Фабрика и хранилище логгеров
///
/// Предоставляет методы для создания, получения и управления логгерами.
/// Позволяет получать логгеры по имени и настраивать глобальные параметры.
///
/// Пример использования:
/// ```dart
/// // Получение логгера для компонента
/// final logger = RpcLogManager.getLogger('MyComponent');
///
/// // Установка сервиса диагностики для всех логгеров
/// RpcLogManager.setDiagnosticService(diagnosticService);
/// ```
abstract interface class RpcLogManager {
  /// Кэш созданных логгеров
  static final Map<String, RpcLogger> _loggers = {};

  /// Сервис диагностики по умолчанию
  static IRpcDiagnosticService? _defaultDiagnosticService;

  /// Глобальные настройки для новых логгеров
  static RpcLogLevel _defaultMinLogLevel = RpcLogLevel.info;
  static bool _defaultConsoleLoggingEnabled = true;
  static bool _defaultColoredLoggingEnabled = true;
  static RpcLogColors _defaultLogColors = const RpcLogColors();

  /// Пользовательский фильтр для всех логгеров
  static LogFilter? _globalFilter;

  /// Пользовательский форматтер для всех логгеров
  static LogFormatter? _globalFormatter;

  /// Приватный конструктор, чтобы предотвратить инстанцирование
  RpcLogManager._();

  /// Устанавливает сервис диагностики по умолчанию для всех логгеров
  ///
  /// Этот сервис будет использоваться всеми существующими и новыми логгерами,
  /// если для них не указан другой сервис явно.
  static void setDiagnosticService(IRpcDiagnosticService service) {
    _defaultDiagnosticService = service;

    // Обновляем все существующие логгеры
    for (final logger in _loggers.values) {
      logger.setDiagnosticService(service);
    }
  }

  /// Устанавливает минимальный уровень логов по умолчанию
  static void setDefaultMinLogLevel(RpcLogLevel level) {
    _defaultMinLogLevel = level;
  }

  /// Включает/выключает вывод логов в консоль по умолчанию
  static void setDefaultConsoleLogging(bool enabled) {
    _defaultConsoleLoggingEnabled = enabled;
  }

  /// Включает/выключает цветной вывод логов в консоль по умолчанию
  static void setDefaultColoredLogging(bool enabled) {
    _defaultColoredLoggingEnabled = enabled;
  }

  /// Устанавливает цвета логов по умолчанию
  static void setDefaultLogColors(RpcLogColors colors) {
    _defaultLogColors = colors;
  }

  /// Устанавливает глобальный фильтр логов
  static void setGlobalFilter(LogFilter filter) {
    _globalFilter = filter;

    // Обновляем все существующие логгеры
    for (final logger in _loggers.values) {
      logger.setFilter(filter);
    }
  }

  /// Устанавливает глобальный форматтер логов
  static void setGlobalFormatter(LogFormatter formatter) {
    _globalFormatter = formatter;

    // Обновляем все существующие логгеры
    for (final logger in _loggers.values) {
      logger.setFormatter(formatter);
    }
  }

  /// Получает существующий или создает новый логгер с указанным именем
  ///
  /// Если логгер с таким именем уже существует, возвращает его,
  /// иначе создает новый логгер с настройками по умолчанию.
  static RpcLogger get(String name) {
    final logger = _loggers[name];
    if (logger != null) {
      return logger;
    }

    return _createLogger(
      name: name,
      diagnosticService: _defaultDiagnosticService,
      minLogLevel: _defaultMinLogLevel,
      consoleLoggingEnabled: _defaultConsoleLoggingEnabled,
      coloredLoggingEnabled: _defaultColoredLoggingEnabled,
      logColors: _defaultLogColors,
      filter: _globalFilter,
      formatter: _globalFormatter,
    );
  }

  /// Создает новый логгер с указанными параметрами и добавляет его в кэш
  ///
  /// Если логгер с таким именем уже существует, он будет заменен.
  static RpcLogger _createLogger({
    required String name,
    IRpcDiagnosticService? diagnosticService,
    RpcLogLevel? minLogLevel,
    bool? consoleLoggingEnabled,
    bool? coloredLoggingEnabled,
    RpcLogColors? logColors,
    LogFilter? filter,
    LogFormatter? formatter,
  }) {
    final logger = RpcLogger(
      name: name,
      diagnosticService: diagnosticService ?? _defaultDiagnosticService,
      minLogLevel: minLogLevel ?? _defaultMinLogLevel,
      consoleLoggingEnabled:
          consoleLoggingEnabled ?? _defaultConsoleLoggingEnabled,
      coloredLoggingEnabled:
          coloredLoggingEnabled ?? _defaultColoredLoggingEnabled,
      logColors: logColors ?? _defaultLogColors,
      filter: filter ?? _globalFilter,
      formatter: formatter ?? _globalFormatter,
    );

    _loggers[name] = logger;
    return logger;
  }

  /// Проверяет, существует ли логгер с указанным именем
  static bool hasLogger(String name) {
    return _loggers.containsKey(name);
  }

  /// Удаляет логгер с указанным именем из кэша
  static void removeLogger(String name) {
    _loggers.remove(name);
  }

  /// Очищает кэш логгеров
  ///
  /// Полезно для освобождения ресурсов или при тестировании.
  static void clearLoggers() {
    _loggers.clear();
  }

  /// Возвращает все имена зарегистрированных логгеров
  static List<String> getLoggerNames() {
    return _loggers.keys.toList();
  }
}
