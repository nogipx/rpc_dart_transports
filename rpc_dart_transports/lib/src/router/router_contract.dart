// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:uuid/uuid.dart';

import 'package:rpc_dart/rpc_dart.dart';

import 'router_models.dart';

/// Запрос регистрации клиента
class RouterRegisterRequest implements IRpcSerializable {
  final String? clientName;
  final List<String>? groups;
  final Map<String, dynamic>? metadata;

  const RouterRegisterRequest({
    this.clientName,
    this.groups,
    this.metadata,
  });

  factory RouterRegisterRequest.fromJson(Map<String, dynamic> json) {
    return RouterRegisterRequest(
      clientName: json['clientName'] as String?,
      groups: (json['groups'] as List?)?.cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (clientName != null) 'clientName': clientName,
      if (groups != null) 'groups': groups,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Ответ на регистрацию клиента
class RouterRegisterResponse implements IRpcSerializable {
  final String clientId;
  final bool success;
  final String? errorMessage;

  const RouterRegisterResponse({
    required this.clientId,
    required this.success,
    this.errorMessage,
  });

  factory RouterRegisterResponse.fromJson(Map<String, dynamic> json) {
    return RouterRegisterResponse(
      clientId: json['clientId'] as String,
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'success': success,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}

/// Запрос списка онлайн клиентов
class RouterGetOnlineClientsRequest implements IRpcSerializable {
  final List<String>? groups;
  final Map<String, dynamic>? metadata;

  const RouterGetOnlineClientsRequest({
    this.groups,
    this.metadata,
  });

  factory RouterGetOnlineClientsRequest.fromJson(Map<String, dynamic> json) {
    return RouterGetOnlineClientsRequest(
      groups: (json['groups'] as List?)?.cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      if (groups != null) 'groups': groups,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Запрос обновления метаданных
class RouterUpdateMetadataRequest implements IRpcSerializable {
  final Map<String, dynamic> metadata;

  const RouterUpdateMetadataRequest({
    required this.metadata,
  });

  factory RouterUpdateMetadataRequest.fromJson(Map<String, dynamic> json) {
    return RouterUpdateMetadataRequest(
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata,
    };
  }
}

/// Ответ ping
class RouterPongResponse implements IRpcSerializable {
  final int timestamp;
  final int serverTimestamp;

  const RouterPongResponse({
    required this.timestamp,
    required this.serverTimestamp,
  });

  factory RouterPongResponse.fromJson(Map<String, dynamic> json) {
    return RouterPongResponse(
      timestamp: json['timestamp'] as int,
      serverTimestamp: json['serverTimestamp'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'serverTimestamp': serverTimestamp,
    };
  }
}

/// Список клиентов как ответ
class RouterClientsList implements IRpcSerializable {
  final List<RouterClientInfo> clients;

  const RouterClientsList(this.clients);

  factory RouterClientsList.fromJson(Map<String, dynamic> json) {
    return RouterClientsList(
      (json['clients'] as List).map((item) => RouterClientInfo.fromJson(item)).toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'clients': clients.map((client) => client.toJson()).toList(),
    };
  }
}

/// Контракт роутера для маршрутизации RPC сообщений между клиентами.
///
/// Обеспечивает stateless маршрутизацию сообщений между различными
/// клиентами через двунаправленные стримы. Роутер не хранит состояние
/// и минимизирует потребление ресурсов.
final class RouterResponderContract extends RpcResponderContract {
  /// Активные клиентские соединения: clientId -> StreamController
  final Map<String, StreamController<RouterMessage>> _clientStreams = {};

  /// Информация о клиентах: clientId -> RouterClientInfo
  final Map<String, RouterClientInfo> _clientsInfo = {};

  /// Активные запросы: requestId -> Completer
  final Map<String, Completer<RouterMessage>> _activeRequests = {};

  /// Дистрибьютор для системных событий роутера
  late final StreamDistributor<RouterEvent> _eventDistributor;

  /// UUID генератор для создания уникальных ID
  static const Uuid _uuid = Uuid();

  /// Логгер для отладки роутера
  final RpcLogger? _logger;

  RouterResponderContract({RpcLogger? logger})
      : _logger = logger?.child('RouterContract'),
        super('router') {
    // Инициализируем дистрибьютор событий
    _eventDistributor = StreamDistributor<RouterEvent>(
      config: StreamDistributorConfig(
        enableAutoCleanup: true,
        inactivityThreshold: Duration(minutes: 5),
        cleanupInterval: Duration(minutes: 1),
        autoRemoveOnCancel: true,
      ),
      logger: _logger?.child('EventDistributor'),
    );

    setup(); // Автоматически настраиваем контракт
  }

  @override
  void setup() {
    _logger?.info('Настройка Router контракта');

    // === ПРЯМЫЕ RPC МЕТОДЫ К РОУТЕРУ ===

    // Регистрация клиента
    addUnaryMethod<RouterRegisterRequest, RouterRegisterResponse>(
      methodName: 'register',
      requestCodec: RpcCodec<RouterRegisterRequest>(
        (json) => RouterRegisterRequest.fromJson(json),
      ),
      responseCodec: RpcCodec<RouterRegisterResponse>(
        (json) => RouterRegisterResponse.fromJson(json),
      ),
      handler: _handleRegister,
    );

    // Ping роутера
    addUnaryMethod<RpcInt, RouterPongResponse>(
      methodName: 'ping',
      requestCodec: RpcCodec<RpcInt>((json) => RpcInt.fromJson(json)),
      responseCodec: RpcCodec<RouterPongResponse>(
        (json) => RouterPongResponse.fromJson(json),
      ),
      handler: _handlePing,
    );

    // Получить список онлайн клиентов
    addUnaryMethod<RouterGetOnlineClientsRequest, RouterClientsList>(
      methodName: 'getOnlineClients',
      requestCodec: RpcCodec<RouterGetOnlineClientsRequest>(
        (json) => RouterGetOnlineClientsRequest.fromJson(json),
      ),
      responseCodec: RpcCodec<RouterClientsList>(
        (json) => RouterClientsList.fromJson(json),
      ),
      handler: _handleGetOnlineClients,
    );

    // Обновить метаданные клиента
    addUnaryMethod<RouterUpdateMetadataRequest, RpcBool>(
      methodName: 'updateMetadata',
      requestCodec: RpcCodec<RouterUpdateMetadataRequest>(
        (json) => RouterUpdateMetadataRequest.fromJson(json),
      ),
      responseCodec: RpcCodec<RpcBool>((json) => RpcBool.fromJson(json)),
      handler: _handleUpdateMetadata,
    );

    // Heartbeat
    addUnaryMethod<RpcNull, RpcNull>(
      methodName: 'heartbeat',
      requestCodec: RpcCodec<RpcNull>((json) => RpcNull.fromJson(json)),
      responseCodec: RpcCodec<RpcNull>((json) => RpcNull.fromJson(json)),
      handler: _handleHeartbeat,
    );

    // === P2P ТРАНСПОРТ ===

    // Двунаправленный стрим для P2P сообщений между клиентами
    addBidirectionalMethod<RouterMessage, RouterMessage>(
      methodName: 'p2p',
      requestCodec: RpcCodec<RouterMessage>(
        (json) => RouterMessage.fromJson(json),
      ),
      responseCodec: RpcCodec<RouterMessage>(
        (json) => RouterMessage.fromJson(json),
      ),
      handler: _handleP2PConnection,
    );

    // === СОБЫТИЯ РОУТЕРА ===

    // Серверный поток для системных событий
    addServerStreamMethod<RpcNull, RouterEvent>(
      methodName: 'events',
      requestCodec: RpcCodec<RpcNull>((json) => RpcNull.fromJson(json)),
      responseCodec: RpcCodec<RouterEvent>(
        (json) => RouterEvent.fromJson(json),
      ),
      handler: _handleEventSubscription,
    );

    _logger?.info('Router контракт настроен');
  }

  // === ОБРАБОТЧИКИ ПРЯМЫХ RPC МЕТОДОВ ===

  /// Регистрирует нового клиента
  Future<RouterRegisterResponse> _handleRegister(RouterRegisterRequest request) async {
    try {
      final clientId = _generateClientId();

      final now = DateTime.now();
      final clientInfo = RouterClientInfo(
        clientId: clientId,
        clientName: request.clientName,
        groups: request.groups ?? [],
        connectedAt: now,
        lastActivity: now,
        metadata: request.metadata ?? {},
        status: ClientStatus.online,
      );

      _clientsInfo[clientId] = clientInfo;

      _logger?.info('Клиент зарегистрирован: $clientId (${clientInfo.clientName})');

      // Уведомляем подписчиков о новом клиенте
      _broadcastEvent(RouterEvent.clientConnected(
        clientId: clientId,
        clientName: clientInfo.clientName,
        capabilities: clientInfo.groups,
      ));

      return RouterRegisterResponse(
        clientId: clientId,
        success: true,
      );
    } catch (e, stackTrace) {
      _logger?.error('Ошибка регистрации клиента: $e', error: e, stackTrace: stackTrace);
      return RouterRegisterResponse(
        clientId: '',
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Обрабатывает ping запрос
  Future<RouterPongResponse> _handlePing(RpcInt clientTimestamp) async {
    final serverTimestamp = DateTime.now().millisecondsSinceEpoch;

    _logger?.debug('Ping получен, timestamp: ${clientTimestamp.value}');

    return RouterPongResponse(
      timestamp: clientTimestamp.value,
      serverTimestamp: serverTimestamp,
    );
  }

  /// Получает список онлайн клиентов
  Future<RouterClientsList> _handleGetOnlineClients(RouterGetOnlineClientsRequest request) async {
    // Фильтруем клиентов
    var clients = _clientsInfo.values.where(
        (client) => client.status == ClientStatus.online || client.status == ClientStatus.idle);

    // Применяем фильтры если есть
    if (request.groups != null && request.groups!.isNotEmpty) {
      clients =
          clients.where((client) => request.groups!.any((group) => client.groups.contains(group)));
    }

    if (request.metadata != null && request.metadata!.isNotEmpty) {
      clients = clients.where((client) {
        return request.metadata!.entries
            .every((entry) => client.metadata[entry.key] == entry.value);
      });
    }

    final result = clients.toList();

    _logger?.debug('Отправлен список клиентов (${result.length})');

    return RouterClientsList(result);
  }

  /// Обновляет метаданные клиента
  Future<RpcBool> _handleUpdateMetadata(RouterUpdateMetadataRequest request) async {
    // TODO: Нужно получать clientId из контекста RPC запроса
    // В текущей реализации rpc_dart не предоставляет доступ к метаданным запроса
    // Возможные решения:
    // 1. Добавить clientId в параметры запроса
    // 2. Использовать session-based authentication
    // 3. Расширить RPC endpoint контекст
    _logger?.warning('Метод updateMetadata требует передачи clientId в контексте запроса');
    return const RpcBool(false);
  }

  /// Обрабатывает heartbeat
  Future<RpcNull> _handleHeartbeat(RpcNull request) async {
    // TODO: Нужно получать clientId из контекста RPC запроса
    // В текущей реализации rpc_dart не предоставляет доступ к метаданным запроса
    _logger?.warning('Метод heartbeat требует передачи clientId в контексте запроса');
    return const RpcNull();
  }

  // === ОБРАБОТЧИК P2P ТРАНСПОРТА ===

  /// Обрабатывает P2P соединение между клиентами
  Stream<RouterMessage> _handleP2PConnection(
    Stream<RouterMessage> clientMessages,
  ) async* {
    String? clientId;
    StreamController<RouterMessage>? clientController;
    StreamSubscription? clientSubscription;

    try {
      _logger?.debug('Новое P2P соединение');

      // Создаем контроллер для отправки сообщений клиенту
      clientController = StreamController<RouterMessage>();

      // Слушаем сообщения от клиента
      clientSubscription = clientMessages.listen(
        (message) {
          // Первое сообщение должно содержать clientId для привязки к зарегистрированному клиенту
          if (clientId == null) {
            clientId = message.senderId;
            if (clientId == null || !_clientsInfo.containsKey(clientId)) {
              _logger?.warning('P2P соединение без валидного clientId: ${message.senderId}');
              return;
            }

            _clientStreams[clientId!] = clientController!;
            _logger?.info('P2P соединение установлено для клиента: $clientId');
          } else {
            _handleP2PMessage(message, clientId!);
          }
        },
        onError: (error) {
          _logger?.error('Ошибка в P2P стриме: $error');
          _disconnectClient(clientId);
        },
        onDone: () {
          _logger?.debug('P2P стрим завершен для $clientId');
          _disconnectClient(clientId);
        },
      );

      // Возвращаем стрим ответов клиенту
      yield* clientController.stream;
    } catch (e, stackTrace) {
      _logger?.error('Ошибка в P2P соединении: $e', error: e, stackTrace: stackTrace);
      _disconnectClient(clientId);
      rethrow;
    } finally {
      // Очистка ресурсов
      await clientSubscription?.cancel();
      await clientController?.close();
    }
  }

  /// Обрабатывает P2P сообщение от клиента
  void _handleP2PMessage(RouterMessage message, String senderId) {
    // Обновляем время последней активности
    _updateClientActivity(senderId);

    _logger?.debug('P2P сообщение от $senderId: ${message.type}');

    switch (message.type) {
      case RouterMessageType.unicast:
        _handleUnicast(message, senderId);
        break;
      case RouterMessageType.multicast:
        _handleMulticast(message, senderId);
        break;
      case RouterMessageType.broadcast:
        _handleBroadcast(message, senderId);
        break;
      case RouterMessageType.request:
        _handleRequest(message, senderId);
        break;
      case RouterMessageType.response:
        _handleResponse(message, senderId);
        break;
      default:
        _logger?.warning('Неподдерживаемый тип P2P сообщения: ${message.type}');
    }
  }

  /// Обрабатывает unicast сообщение (1:1)
  void _handleUnicast(RouterMessage message, String senderId) {
    final targetId = message.targetId;
    if (targetId == null) {
      _logger?.warning('Unicast сообщение без targetId от $senderId');
      return;
    }

    final targetController = _clientStreams[targetId];
    if (targetController == null) {
      _logger?.warning('Клиент $targetId не найден для unicast от $senderId');

      // Отправляем ошибку отправителю
      final errorMessage = RouterMessage.error(
        'Клиент $targetId не найден',
        senderId: senderId,
      );
      _sendToClient(senderId, errorMessage);
      return;
    }

    // Пересылаем сообщение с информацией об отправителе
    final forwardedMessage = message.copyWith(senderId: senderId);
    _sendToClient(targetId, forwardedMessage);

    _logger?.debug('Unicast: $senderId -> $targetId');
  }

  /// Обрабатывает multicast сообщение (1:N по группе)
  void _handleMulticast(RouterMessage message, String senderId) {
    final groupName = message.groupName;
    if (groupName == null) {
      _logger?.warning('Multicast сообщение без groupName от $senderId');
      return;
    }

    int sentCount = 0;

    // В stateless роутере не храним группы клиентов
    // Отправляем всем подключенным клиентам (они сами фильтруют)
    for (final clientId in _clientStreams.keys) {
      if (clientId != senderId) {
        final forwardedMessage = message.copyWith(senderId: senderId);
        _sendToClient(clientId, forwardedMessage);
        sentCount++;
      }
    }

    _logger?.debug('Multicast: $senderId -> группа "$groupName" ($sentCount клиентов)');
  }

  /// Обрабатывает broadcast сообщение (1:ALL)
  void _handleBroadcast(RouterMessage message, String senderId) {
    int sentCount = 0;

    for (final clientId in _clientStreams.keys) {
      if (clientId != senderId) {
        final forwardedMessage = message.copyWith(senderId: senderId);
        _sendToClient(clientId, forwardedMessage);
        sentCount++;
      }
    }

    _logger?.debug('Broadcast: $senderId -> все ($sentCount клиентов)');
  }

  /// Отправляет сообщение конкретному клиенту
  void _sendToClient(String clientId, RouterMessage message) {
    final controller = _clientStreams[clientId];
    if (controller != null && !controller.isClosed) {
      try {
        controller.add(message);
      } catch (e) {
        _logger?.error('Ошибка отправки сообщения клиенту $clientId: $e');
        _disconnectClient(clientId);
      }
    }
  }

  /// Отключает клиента
  void _disconnectClient(String? clientId) {
    if (clientId == null) return;

    final controller = _clientStreams.remove(clientId);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }

    // Удаляем информацию о клиенте
    _clientsInfo.remove(clientId);

    _logger?.info('Клиент отключен: $clientId (активных: ${_clientStreams.length})');

    // Уведомляем подписчиков об отключении клиента
    _broadcastEvent(RouterEvent.clientDisconnected(
      clientId: clientId,
      reason: 'Клиент отключился',
    ));

    // Отправляем событие изменения топологии
    _broadcastEvent(RouterEvent.topologyChanged(
      activeClients: _clientStreams.length,
      clientIds: _clientStreams.keys.toList(),
      capabilities: _getClientsCapabilities(),
    ));
  }

  /// Получает возможности всех клиентов
  Map<String, List<String>> _getClientsCapabilities() {
    return Map.fromEntries(
        _clientsInfo.entries.map((entry) => MapEntry(entry.key, entry.value.groups)));
  }

  /// Обрабатывает подписку на системные события роутера
  Stream<RouterEvent> _handleEventSubscription(RpcNull subscriptionRequest) async* {
    final subscriberId = 'events_${_uuid.v4()}';

    _logger?.debug('Новая подписка на события: $subscriberId');

    try {
      // Создаем стрим через дистрибьютор
      final eventStream = _eventDistributor.createClientStreamWithId(
        subscriberId,
        onCancel: () {
          _logger?.debug('Отмена подписки на события: $subscriberId');
        },
      );

      // Отправляем приветственное событие с текущей статистикой
      final currentStats = RouterEvent.routerStats(
        activeClients: _clientStreams.length,
        messagesPerSecond: 0, // TODO: реализовать подсчет
        messageTypeCounts: {}, // TODO: реализовать подсчет
      );

      // Публикуем приветственное событие конкретному клиенту
      _eventDistributor.publishToClient(subscriberId, currentStats);

      // Возвращаем поток событий
      yield* eventStream;
    } catch (e, stackTrace) {
      _logger?.error('Ошибка в подписке на события: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Отправляет событие всем подписчикам
  void _broadcastEvent(RouterEvent event) {
    final activeSubscribers = _eventDistributor.activeClientCount;
    _logger?.debug('Отправка события ${event.type} $activeSubscribers подписчикам');

    // Используем дистрибьютор для широковещательной рассылки
    final deliveredCount = _eventDistributor.publish(event);

    _logger?.debug('Событие ${event.type} доставлено $deliveredCount подписчикам');
  }

  /// Обновляет время последней активности клиента
  void _updateClientActivity(String clientId) {
    final clientInfo = _clientsInfo[clientId];
    if (clientInfo != null) {
      _clientsInfo[clientId] = clientInfo.copyWith(
        lastActivity: DateTime.now(),
        status: ClientStatus.online,
      );
    }
  }

  /// Обрабатывает request-response сообщение
  void _handleRequest(RouterMessage message, String senderId) {
    final targetId = message.targetId;
    final requestId = message.payload?['requestId'] as String?;

    if (targetId == null || requestId == null) {
      _logger?.warning('Request сообщение без targetId или requestId от $senderId');
      return;
    }

    // Пересылаем запрос целевому клиенту
    final forwardedMessage = message.copyWith(senderId: senderId);
    _sendToClient(targetId, forwardedMessage);

    // Сохраняем информацию о запросе для таймаута
    final timeout = message.payload?['timeoutMs'] as int?;
    if (timeout != null) {
      Timer(Duration(milliseconds: timeout), () {
        if (_activeRequests.containsKey(requestId)) {
          _activeRequests.remove(requestId);

          // Отправляем ошибку таймаута отправителю
          final timeoutResponse = RouterMessage.response(
            targetId: senderId,
            requestId: requestId,
            payload: {},
            senderId: 'router',
            success: false,
            errorMessage: 'Request timeout',
          );
          _sendToClient(senderId, timeoutResponse);
        }
      });
    }

    _logger?.debug('Request переслан: $senderId -> $targetId (requestId: $requestId)');
  }

  /// Обрабатывает response сообщение
  void _handleResponse(RouterMessage message, String senderId) {
    final targetId = message.targetId;
    if (targetId == null) {
      _logger?.warning('Response сообщение без targetId от $senderId');
      return;
    }

    // Пересылаем ответ целевому клиенту
    final forwardedMessage = message.copyWith(senderId: senderId);
    _sendToClient(targetId, forwardedMessage);

    _logger?.debug('Response переслан: $senderId -> $targetId');
  }

  /// Генерирует уникальный ID клиента
  String _generateClientId() {
    return 'client_${_uuid.v4()}';
  }

  /// Получает информацию о состоянии роутера
  RouterStats get stats => RouterStats(
        activeClients: _clientStreams.length,
        clientIds: _clientStreams.keys.toList(),
      );

  /// Освобождает ресурсы роутера
  Future<void> dispose() async {
    _logger?.info('Закрытие роутера...');

    // Закрываем все клиентские соединения
    final clientIds = _clientStreams.keys.toList();
    for (final clientId in clientIds) {
      _disconnectClient(clientId);
    }

    // Закрываем дистрибьютор событий
    await _eventDistributor.dispose();

    _logger?.info('Роутер закрыт');
  }
}

/// Статистика роутера
class RouterStats {
  final int activeClients;
  final List<String> clientIds;

  const RouterStats({
    required this.activeClients,
    required this.clientIds,
  });

  @override
  String toString() {
    return 'RouterStats(activeClients: $activeClients, clientIds: $clientIds)';
  }
}
