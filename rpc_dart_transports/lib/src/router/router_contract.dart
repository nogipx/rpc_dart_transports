// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:uuid/uuid.dart';

import 'package:rpc_dart/rpc_dart.dart';

import 'router_models.dart';

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

    // Регистрируем двунаправленный стрим для клиентского соединения
    addBidirectionalMethod<RouterMessage, RouterMessage>(
      methodName: 'connect',
      requestCodec: RpcCodec<RouterMessage>(
        (json) => RouterMessage.fromJson(json),
      ),
      responseCodec: RpcCodec<RouterMessage>(
        (json) => RouterMessage.fromJson(json),
      ),
      handler: _handleClientConnection,
    );

    // Регистрируем серверный поток для системных событий
    // Клиент отправляет пустой запрос для подписки
    addServerStreamMethod<RouterMessage, RouterEvent>(
      methodName: 'events',
      requestCodec: RpcCodec<RouterMessage>(
        (json) => RouterMessage.fromJson(json),
      ),
      responseCodec: RpcCodec<RouterEvent>(
        (json) => RouterEvent.fromJson(json),
      ),
      handler: _handleEventSubscription,
    );

    _logger?.info('Router контракт настроен');
  }

  /// Обрабатывает двунаправленное соединение с клиентом
  Stream<RouterMessage> _handleClientConnection(
    Stream<RouterMessage> clientMessages,
  ) async* {
    String? clientId;
    StreamController<RouterMessage>? clientController;

    try {
      _logger?.debug('Новое клиентское соединение');

      // Создаем контроллер для отправки сообщений клиенту
      clientController = StreamController<RouterMessage>();

      // Слушаем сообщения от клиента
      late StreamSubscription clientSubscription;
      clientSubscription = clientMessages.listen(
        (message) {
          // Обрабатываем регистрацию здесь
          if (clientId == null && message.type == RouterMessageType.register) {
            clientId = _generateClientId();
            _clientStreams[clientId!] = clientController!;

            // Создаем информацию о клиенте
            final now = DateTime.now();
            final clientInfo = RouterClientInfo(
              clientId: clientId!,
              clientName: message.payload?['clientName'] as String?,
              groups: (message.payload?['groups'] as List?)?.cast<String>() ?? [],
              connectedAt: now,
              lastActivity: now,
              metadata: (message.payload?['metadata'] as Map<String, dynamic>?) ?? {},
              status: ClientStatus.online,
            );
            _clientsInfo[clientId!] = clientInfo;

            _logger?.info('Клиент зарегистрирован: $clientId (${clientInfo.clientName})');

            // Отправляем подтверждение регистрации
            clientController!.add(RouterMessage.registerResponse(
              clientId: clientId!,
              success: true,
            ));

            // Уведомляем подписчиков о новом клиенте
            _broadcastEvent(RouterEvent.clientConnected(
              clientId: clientId!,
              clientName: clientInfo.clientName,
              capabilities: clientInfo.groups,
            ));
          } else {
            _handleClientMessage(message, clientId);
          }
        },
        onError: (error) {
          _logger?.error('Ошибка в клиентском стриме: $error');
          _disconnectClient(clientId);
        },
        onDone: () {
          _logger?.debug('Клиентский стрим завершен для $clientId');
          _disconnectClient(clientId);
        },
      );

      // Возвращаем стрим ответов клиенту
      yield* clientController.stream.doOnCancel(() {
        _logger?.debug('Отмена стрима для клиента $clientId');
        clientSubscription.cancel();
        _disconnectClient(clientId);
      }).doOnListen(() {
        // При подключении ждем сообщение регистрации
        _logger?.debug('Клиент подключился, ожидаем регистрацию');
      });
    } catch (e, stackTrace) {
      _logger?.error('Ошибка в соединении клиента: $e', error: e, stackTrace: stackTrace);
      _disconnectClient(clientId);
      rethrow;
    }
  }

  /// Обрабатывает сообщение от клиента
  void _handleClientMessage(RouterMessage message, String? senderId) {
    if (senderId == null) {
      _logger?.warning('Получено сообщение от незарегистрированного клиента');
      return;
    }

    // Обновляем время последней активности
    _updateClientActivity(senderId);

    _logger?.debug('Сообщение от $senderId: ${message.type}');

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
      case RouterMessageType.ping:
        _handlePing(message, senderId);
        break;
      case RouterMessageType.getOnlineClients:
        _handleGetOnlineClients(message, senderId);
        break;
      case RouterMessageType.request:
        _handleRequest(message, senderId);
        break;
      case RouterMessageType.response:
        _handleResponse(message, senderId);
        break;
      case RouterMessageType.updateClientMetadata:
        _handleUpdateClientMetadata(message, senderId);
        break;
      case RouterMessageType.heartbeat:
        _handleHeartbeat(message, senderId);
        break;
      default:
        _logger?.warning('Неизвестный тип сообщения: ${message.type}');
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

  /// Обрабатывает ping сообщение
  void _handlePing(RouterMessage message, String senderId) {
    final pongMessage = RouterMessage.pong(
      timestamp: message.timestamp ?? DateTime.now().millisecondsSinceEpoch,
      senderId: 'router',
    );
    _sendToClient(senderId, pongMessage);

    _logger?.debug('Ping-Pong: $senderId');
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
  Stream<RouterEvent> _handleEventSubscription(RouterMessage subscriptionRequest) async* {
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

  /// Обрабатывает запрос списка онлайн клиентов
  void _handleGetOnlineClients(RouterMessage message, String senderId) {
    final filters = message.payload ?? <String, dynamic>{};

    // Фильтруем клиентов
    var clients = _clientsInfo.values.where(
        (client) => client.status == ClientStatus.online || client.status == ClientStatus.idle);

    // Применяем фильтры если есть
    if (filters.containsKey('groups')) {
      final requiredGroups = (filters['groups'] as List?)?.cast<String>() ?? [];
      clients =
          clients.where((client) => requiredGroups.any((group) => client.groups.contains(group)));
    }

    if (filters.containsKey('metadata')) {
      final requiredMetadata = filters['metadata'] as Map<String, dynamic>?;
      if (requiredMetadata != null) {
        clients = clients.where((client) {
          return requiredMetadata.entries
              .every((entry) => client.metadata[entry.key] == entry.value);
        });
      }
    }

    // Преобразуем в JSON
    final clientsList = clients.map((client) => client.toJson()).toList();

    // Отправляем ответ
    final response = RouterMessage.onlineClientsResponse(
      clients: clientsList,
      senderId: 'router',
    );
    _sendToClient(senderId, response);

    _logger?.debug('Отправлен список клиентов ($clientsList.length) клиенту $senderId');
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

  /// Обрабатывает обновление метаданных клиента
  void _handleUpdateClientMetadata(RouterMessage message, String senderId) {
    final metadata = message.payload?['metadata'] as Map<String, dynamic>?;
    if (metadata == null) {
      _logger?.warning('UpdateClientMetadata без metadata от $senderId');
      return;
    }

    final clientInfo = _clientsInfo[senderId];
    if (clientInfo != null) {
      // Обновляем метаданные клиента
      _clientsInfo[senderId] = clientInfo.copyWith(
        metadata: {...clientInfo.metadata, ...metadata},
        lastActivity: DateTime.now(),
      );

      // Уведомляем подписчиков об обновлении
      _broadcastEvent(RouterEvent.clientCapabilitiesUpdated(
        clientId: senderId,
        metadata: _clientsInfo[senderId]!.metadata,
      ));

      _logger?.debug('Обновлены метаданные клиента $senderId');
    }
  }

  /// Обрабатывает heartbeat сообщение
  void _handleHeartbeat(RouterMessage message, String senderId) {
    // Просто обновляем активность (уже сделано в _handleClientMessage)
    _logger?.debug('Heartbeat от $senderId');
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

/// Расширение для Stream с дополнительными методами
extension StreamExtensions<T> on Stream<T> {
  /// Выполняет действие при отмене подписки
  Stream<T> doOnCancel(void Function() onCancel) {
    late StreamController<T> controller;
    late StreamSubscription<T> subscription;

    controller = StreamController<T>(
      onListen: () {
        subscription = listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () {
        onCancel();
        return subscription.cancel();
      },
    );

    return controller.stream;
  }

  /// Выполняет действие при подключении
  Stream<T> doOnListen(void Function() onListen) {
    late StreamController<T> controller;

    controller = StreamController<T>(
      onListen: () {
        onListen();
        listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
    );

    return controller.stream;
  }
}
