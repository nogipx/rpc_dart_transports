// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import '../websocket/websocket_caller_transport.dart';
import '../websocket/managers/reconnect_manager.dart';
import 'router_client.dart';
import 'router_models.dart';

/// RouterClient с автоматическим переподключением
///
/// Предоставляет полностью прозрачное переподключение:
/// - Сохраняет регистрацию клиента
/// - Автоматически восстанавливает P2P соединения
/// - Переподписывается на события
/// - События состояния соединения
class RouterClientWithReconnect {
  /// URI сервера
  final Uri _serverUri;

  /// Параметры подключения
  final Iterable<String>? _protocols;
  final Map<String, dynamic>? _headers;

  /// Текущий RouterClient
  RouterClient? _routerClient;

  /// Менеджер переподключений
  late final WebSocketReconnectManager _reconnectManager;

  /// Контроллер для событий состояния
  final StreamController<ReconnectState> _stateController =
      StreamController<ReconnectState>.broadcast();

  /// Контроллер для событий роутера (проксирует события из текущего клиента)
  final StreamController<RouterEvent> _eventsController =
      StreamController<RouterEvent>.broadcast();

  /// Сохраненные параметры регистрации
  String? _savedClientName;
  List<String>? _savedGroups;
  Map<String, dynamic>? _savedMetadata;

  /// ID клиента
  String? _clientId;

  /// Параметры P2P инициализации
  void Function(RouterMessage message)? _savedOnP2PMessage;
  bool _savedEnableAutoHeartbeat = true;
  bool _savedFilterRouterHeartbeats = true;

  /// Флаги состояния
  bool _isRegistered = false;
  bool _isP2PInitialized = false;
  bool _isEventsSubscribed = false;

  final RpcLogger? _logger;

  RouterClientWithReconnect({
    required Uri serverUri,
    Iterable<String>? protocols,
    Map<String, dynamic>? headers,
    RpcLogger? logger,
    ReconnectConfig? reconnectConfig,
  })  : _serverUri = serverUri,
        _protocols = protocols,
        _headers = headers,
        _logger = logger?.child('RouterClientWithReconnect') {
    // Инициализируем ReconnectManager
    _reconnectManager = WebSocketReconnectManager(
      config: reconnectConfig,
      logger: _logger?.child('ReconnectManager'),
    );

    _setupReconnectManager();
  }

  /// Стрим состояния переподключения
  Stream<ReconnectState> get connectionState => _stateController.stream;

  /// Стрим событий роутера
  Stream<RouterEvent> get events => _eventsController.stream;

  /// ID клиента
  String? get clientId => _clientId;

  /// Проверяет, подключен ли клиент
  bool get isConnected => _routerClient != null && _isRegistered;

  /// Настраивает менеджер переподключений
  void _setupReconnectManager() {
    _reconnectManager.setReconnectCallback(_attemptReconnect);

    // Проксируем изменения состояния
    _reconnectManager.stateChanges.listen((state) {
      _stateController.add(state);
    });
  }

  /// Инициализирует соединение
  Future<void> connect() async {
    await _attemptReconnect();
  }

  /// Выполняет попытку подключения/переподключения
  Future<void> _attemptReconnect() async {
    _logger?.info('Попытка подключения к $_serverUri');

    try {
      // Закрываем старый клиент если есть
      await _disposeCurrentClient();

      // Создаем новый WebSocket транспорт
      final transport = RpcWebSocketCallerTransport.connect(
        _serverUri,
        protocols: _protocols,
        headers: _headers,
        logger: _logger,
      );

      // Создаем новый endpoint и клиент
      final endpoint = RpcCallerEndpoint(transport: transport);
      _routerClient = RouterClient(
        callerEndpoint: endpoint,
        logger: _logger,
      );

      // Восстанавливаем регистрацию если была
      if (_savedClientName != null ||
          _savedGroups != null ||
          _savedMetadata != null) {
        await _restoreRegistration();
      }

      // Восстанавливаем P2P если было
      if (_isP2PInitialized) {
        await _restoreP2P();
      }

      // Восстанавливаем подписку на события если была
      if (_isEventsSubscribed) {
        await _restoreEventsSubscription();
      }

      // Уведомляем об успешном подключении
      _reconnectManager.onConnected();
      _logger?.info('Подключение восстановлено');
    } catch (e) {
      _logger?.error('Ошибка подключения: $e');
      rethrow;
    }
  }

  /// Восстанавливает регистрацию клиента
  Future<void> _restoreRegistration() async {
    if (_routerClient == null) return;

    try {
      final newClientId = await _routerClient!.register(
        clientName: _savedClientName,
        groups: _savedGroups,
        metadata: _savedMetadata,
      );

      _clientId = newClientId;
      _isRegistered = true;

      _logger?.info('Регистрация восстановлена: $_clientId');
    } catch (e) {
      _logger?.error('Ошибка восстановления регистрации: $e');
      rethrow;
    }
  }

  /// Восстанавливает P2P соединение
  Future<void> _restoreP2P() async {
    if (_routerClient == null || !_isRegistered) return;

    try {
      await _routerClient!.initializeP2P(
        onP2PMessage: _savedOnP2PMessage,
        enableAutoHeartbeat: _savedEnableAutoHeartbeat,
        filterRouterHeartbeats: _savedFilterRouterHeartbeats,
      );

      _logger?.info('P2P соединение восстановлено');
    } catch (e) {
      _logger?.error('Ошибка восстановления P2P: $e');
      rethrow;
    }
  }

  /// Восстанавливает подписку на события
  Future<void> _restoreEventsSubscription() async {
    if (_routerClient == null) return;

    try {
      await _routerClient!.subscribeToEvents();

      // Проксируем события из нового клиента
      _routerClient!.events.listen((event) {
        _eventsController.add(event);
      });

      _logger?.info('Подписка на события восстановлена');
    } catch (e) {
      _logger?.error('Ошибка восстановления подписки на события: $e');
      rethrow;
    }
  }

  /// Закрывает текущий клиент
  Future<void> _disposeCurrentClient() async {
    if (_routerClient != null) {
      try {
        await _routerClient!.dispose();
      } catch (e) {
        _logger?.debug('Ошибка при закрытии старого клиента: $e');
      }
      _routerClient = null;
      _isRegistered = false;
    }
  }

  // === Проксирование методов RouterClient ===

  /// Регистрирует клиента в роутере
  Future<String> register({
    String? clientName,
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) async {
    // Сохраняем параметры для переподключения
    _savedClientName = clientName;
    _savedGroups = groups;
    _savedMetadata = metadata;

    if (_routerClient == null) {
      throw StateError('Клиент не подключен. Вызовите connect()');
    }

    final clientId = await _routerClient!.register(
      clientName: clientName,
      groups: groups,
      metadata: metadata,
    );

    _clientId = clientId;
    _isRegistered = true;
    return clientId;
  }

  /// Инициализирует P2P соединение
  Future<void> initializeP2P({
    void Function(RouterMessage message)? onP2PMessage,
    bool enableAutoHeartbeat = true,
    bool filterRouterHeartbeats = true,
  }) async {
    // Сохраняем параметры для переподключения
    _savedOnP2PMessage = onP2PMessage;
    _savedEnableAutoHeartbeat = enableAutoHeartbeat;
    _savedFilterRouterHeartbeats = filterRouterHeartbeats;
    _isP2PInitialized = true;

    if (_routerClient == null) {
      throw StateError('Клиент не подключен');
    }

    await _routerClient!.initializeP2P(
      onP2PMessage: onP2PMessage,
      enableAutoHeartbeat: enableAutoHeartbeat,
      filterRouterHeartbeats: filterRouterHeartbeats,
    );
  }

  /// Подписывается на события роутера
  Future<void> subscribeToEvents() async {
    _isEventsSubscribed = true;

    if (_routerClient == null) {
      throw StateError('Клиент не подключен');
    }

    await _routerClient!.subscribeToEvents();

    // Проксируем события
    _routerClient!.events.listen((event) {
      _eventsController.add(event);
    });
  }

  /// Пингует роутер
  Future<Duration> ping() async {
    if (_routerClient == null) {
      throw StateError('Клиент не подключен');
    }
    return _routerClient!.ping();
  }

  /// Получает список онлайн клиентов
  Future<List<RouterClientInfo>> getOnlineClients({
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) async {
    if (_routerClient == null) {
      throw StateError('Клиент не подключен');
    }
    return _routerClient!.getOnlineClients(groups: groups, metadata: metadata);
  }

  /// Отправляет unicast сообщение
  Future<void> sendUnicast(
      String targetId, Map<String, dynamic> payload) async {
    if (_routerClient == null) {
      throw StateError('Клиент не подключен');
    }
    await _routerClient!.sendUnicast(targetId, payload);
  }

  /// Отправляет multicast сообщение
  Future<void> sendMulticast(
      String groupName, Map<String, dynamic> payload) async {
    if (_routerClient == null) {
      throw StateError('Клиент не подключен');
    }
    await _routerClient!.sendMulticast(groupName, payload);
  }

  /// Отправляет broadcast сообщение
  Future<void> sendBroadcast(Map<String, dynamic> payload) async {
    if (_routerClient == null) {
      throw StateError('Клиент не подключен');
    }
    await _routerClient!.sendBroadcast(payload);
  }

  /// Отправляет request с ожиданием response
  Future<Map<String, dynamic>> sendRequest(
    String targetId,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_routerClient == null) {
      throw StateError('Клиент не подключен');
    }
    return _routerClient!.sendRequest(targetId, payload, timeout: timeout);
  }

  /// Обновляет метаданные клиента
  Future<bool> updateMetadata(Map<String, dynamic> metadata) async {
    // Обновляем сохраненные метаданные
    _savedMetadata = {...(_savedMetadata ?? {}), ...metadata};

    if (_routerClient == null) {
      throw StateError('Клиент не подключен');
    }
    return _routerClient!.updateMetadata(metadata);
  }

  /// Принудительно запускает переподключение
  Future<void> reconnect() async {
    await _reconnectManager.reconnect();
  }

  /// Останавливает автоматическое переподключение
  void stopReconnecting() {
    _reconnectManager.stop();
  }

  /// Возобновляет автоматическое переподключение
  void resumeReconnecting() {
    _reconnectManager.reset();
  }

  /// Закрывает клиент и все соединения
  Future<void> dispose() async {
    _logger?.info('Закрытие RouterClientWithReconnect...');

    // Останавливаем переподключение
    _reconnectManager.stop();

    // Закрываем текущий клиент
    await _disposeCurrentClient();

    // Закрываем контроллеры
    await _stateController.close();
    await _eventsController.close();

    // Закрываем менеджер переподключений
    await _reconnectManager.dispose();

    _logger?.info('RouterClientWithReconnect закрыт');
  }
}
