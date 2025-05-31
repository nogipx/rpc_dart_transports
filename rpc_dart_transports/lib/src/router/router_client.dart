// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'router_models.dart';
import 'models/_index.dart';

/// Программный интерфейс для работы с роутером
///
/// Предоставляет удобный API для:
/// - Регистрации в роутере
/// - Прямых запросов к роутеру (ping, getClients, etc.)
/// - P2P сообщений между клиентами
/// - Подписки на события роутера
class RouterClient {
  final RpcCallerEndpoint _callerEndpoint;
  final String _serviceName = 'router';

  /// ID клиента, полученный при регистрации
  String? _clientId;

  /// Стрим для P2P сообщений
  StreamController<RouterMessage>? _p2pStreamController;
  Stream<RouterMessage>? _p2pResponseStream;

  /// Активные запросы: requestId -> Completer
  final Map<String, Completer<Map<String, dynamic>>> _activeRequests = {};

  /// Таймеры для активных запросов: requestId -> Timer
  final Map<String, Timer> _requestTimers = {};

  /// Стрим событий роутера
  StreamSubscription<RouterEvent>? _eventsSubscription;
  final StreamController<RouterEvent> _eventsController = StreamController.broadcast();

  /// Таймер для автоматического heartbeat
  Timer? _heartbeatTimer;

  /// Интервал автоматического heartbeat (по умолчанию 20 секунд)
  final Duration _heartbeatInterval;

  /// Включен ли автоматический heartbeat
  bool _autoHeartbeatEnabled = false;

  final RpcLogger? _logger;

  RouterClient({
    required RpcCallerEndpoint callerEndpoint,
    RpcLogger? logger,
    Duration heartbeatInterval = const Duration(seconds: 20),
  })  : _callerEndpoint = callerEndpoint,
        _logger = logger?.child('RouterClient'),
        _heartbeatInterval = heartbeatInterval;

  /// Получает ID клиента (если зарегистрирован)
  String? get clientId => _clientId;

  /// Проверяет, зарегистрирован ли клиент
  bool get isRegistered => _clientId != null;

  /// Стрим событий роутера
  Stream<RouterEvent> get events => _eventsController.stream;

  // === ПРЯМЫЕ RPC ЗАПРОСЫ К РОУТЕРУ ===

  /// Регистрирует клиента в роутере
  Future<String> register({
    String? clientName,
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) async {
    _logger?.info('Регистрация клиента: $clientName');

    final request = RouterRegisterRequest(
      clientName: clientName,
      groups: groups,
      metadata: metadata,
    );

    final response =
        await _callerEndpoint.unaryRequest<RouterRegisterRequest, RouterRegisterResponse>(
      serviceName: _serviceName,
      methodName: 'register',
      requestCodec: RpcCodec<RouterRegisterRequest>((json) => RouterRegisterRequest.fromJson(json)),
      responseCodec:
          RpcCodec<RouterRegisterResponse>((json) => RouterRegisterResponse.fromJson(json)),
      request: request,
    );

    if (!response.success) {
      throw Exception('Ошибка регистрации: ${response.errorMessage}');
    }

    _clientId = response.clientId;
    _logger?.info('Клиент зарегистрирован с ID: $_clientId');

    return _clientId!;
  }

  /// Пингует роутер
  Future<Duration> ping() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final response = await _callerEndpoint.unaryRequest<RpcInt, RouterPongResponse>(
      serviceName: _serviceName,
      methodName: 'ping',
      requestCodec: RpcCodec<RpcInt>((json) => RpcInt.fromJson(json)),
      responseCodec: RpcCodec<RouterPongResponse>((json) => RouterPongResponse.fromJson(json)),
      request: RpcInt(timestamp),
    );

    final latency = Duration(milliseconds: response.serverTimestamp - timestamp);
    _logger?.debug('Ping: ${latency.inMilliseconds}ms');

    return latency;
  }

  /// Получает список онлайн клиентов
  Future<List<RouterClientInfo>> getOnlineClients({
    List<String>? groups,
    Map<String, dynamic>? metadata,
  }) async {
    print('🔍 RouterClient: Запрос списка онлайн клиентов...');
    print('    Фильтры: groups=$groups, metadata=$metadata');

    try {
      final request = RouterGetOnlineClientsRequest(
        groups: groups,
        metadata: metadata,
      );

      print('🔍 RouterClient: Отправляем unary запрос getOnlineClients...');
      final response =
          await _callerEndpoint.unaryRequest<RouterGetOnlineClientsRequest, RouterClientsList>(
        serviceName: _serviceName,
        methodName: 'getOnlineClients',
        requestCodec: RpcCodec<RouterGetOnlineClientsRequest>(
            (json) => RouterGetOnlineClientsRequest.fromJson(json)),
        responseCodec: RpcCodec<RouterClientsList>((json) => RouterClientsList.fromJson(json)),
        request: request,
      );

      print('✅ RouterClient: Получен ответ с ${response.clients.length} клиентами');
      for (final client in response.clients) {
        print('    - ${client.clientName} (${client.clientId}) в группах: ${client.groups}');
      }

      _logger?.debug('Получен список из ${response.clients.length} клиентов');
      return response.clients;
    } catch (e, stackTrace) {
      print('❌ RouterClient: Ошибка получения списка клиентов: $e');
      print('❌ RouterClient: StackTrace: $stackTrace');
      _logger?.error('Ошибка получения списка клиентов: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Обновляет метаданные клиента
  Future<bool> updateMetadata(Map<String, dynamic> metadata) async {
    if (!isRegistered) {
      throw StateError('Клиент должен быть зарегистрирован');
    }

    // Используем P2P поток если инициализирован
    if (_p2pStreamController != null) {
      final updateMessage = RouterMessage.updateMetadata(
        metadata: metadata,
        senderId: _clientId,
      );

      _p2pStreamController!.add(updateMessage);
      _logger?.debug('Обновление метаданных отправлено через P2P: $metadata');
      return true; // P2P метод не возвращает результат
    } else {
      // Fallback на unary метод (УСТАРЕЛ - больше не поддерживается сервером)
      _logger?.warning(
          'P2P не инициализировано, updateMetadata недоступен. Используйте initializeP2P()');
      return false;
    }
  }

  /// Отправляет heartbeat
  Future<void> heartbeat() async {
    if (!isRegistered) {
      throw StateError('Клиент должен быть зарегистрирован');
    }

    // Используем P2P поток если инициализирован
    if (_p2pStreamController != null) {
      sendHeartbeat();
    } else {
      // Fallback на unary метод (УСТАРЕЛ - больше не поддерживается сервером)
      _logger
          ?.warning('P2P не инициализировано, heartbeat недоступен. Используйте initializeP2P()');
    }
  }

  // === P2P СООБЩЕНИЯ ===

  /// Инициализирует P2P соединение
  Future<void> initializeP2P({
    void Function(RouterMessage message)? onP2PMessage,
    bool enableAutoHeartbeat = true,

    /// Если true, скрывает служебные heartbeat сообщения от роутера в onP2PMessage.
    /// Оставьте false для отладки соединений.
    bool filterRouterHeartbeats = true,
  }) async {
    if (_clientId == null) {
      throw StateError('Клиент должен быть зарегистрирован перед инициализацией P2P');
    }

    _logger?.info('Инициализация P2P соединения для клиента: $_clientId');
    print('🔗 RouterClient: Инициализация P2P соединения для клиента: $_clientId');

    try {
      // Создаем стрим контроллер для исходящих сообщений
      print('🔗 RouterClient: Создаем StreamController для исходящих P2P сообщений');
      _p2pStreamController = StreamController<RouterMessage>();

      // Подключаемся к P2P транспорту
      print('🔗 RouterClient: Подключаемся к bidirectionalStream router.p2p...');
      _p2pResponseStream = _callerEndpoint.bidirectionalStream<RouterMessage, RouterMessage>(
        serviceName: _serviceName,
        methodName: 'p2p',
        requests: _p2pStreamController!.stream,
        requestCodec: RpcCodec<RouterMessage>((json) => RouterMessage.fromJson(json)),
        responseCodec: RpcCodec<RouterMessage>((json) => RouterMessage.fromJson(json)),
      );
      print('✅ RouterClient: BidirectionalStream создан успешно');

      // Слушаем ответы и пересылаем в колбэк
      print('🔗 RouterClient: Настраиваем слушатель P2P сообщений...');
      _p2pResponseStream!.listen(
        (message) {
          print('📨 RouterClient: Получено P2P сообщение: ${message.type} от ${message.senderId}');
          _logger?.debug('Получено P2P сообщение: ${message.type} от ${message.senderId}');

          // Обрабатываем response сообщения внутри клиента
          if (message.type == RouterMessageType.response) {
            _handleResponse(message);
          }

          // Обрабатываем подтверждение соединения от роутера
          if (message.type == RouterMessageType.heartbeat &&
              message.senderId == 'router' &&
              message.payload?['connected'] == true) {
            print('✅ RouterClient: P2P соединение подтверждено роутером');
            _logger?.info('P2P соединение подтверждено роутером');
          }

          // Фильтруем служебные heartbeat'ы от роутера если включена фильтрация
          final shouldFilterHeartbeat = filterRouterHeartbeats &&
              message.type == RouterMessageType.heartbeat &&
              message.senderId == 'router';

          // Передаем сообщения в пользовательский колбэк (кроме отфильтрованных)
          if (!shouldFilterHeartbeat) {
            onP2PMessage?.call(message);
          }
        },
        onError: (error) {
          print('❌ RouterClient: Ошибка в P2P стриме: $error');
          _logger?.error('Ошибка в P2P стриме: $error');
          _stopAutoHeartbeat();
        },
        onDone: () {
          print('🔚 RouterClient: P2P стрим закрыт');
          _logger?.info('P2P стрим закрыт');
          _stopAutoHeartbeat();
        },
      );

      // Отправляем первое сообщение для привязки к зарегистрированному клиенту
      print('🔗 RouterClient: Отправляем identity heartbeat для привязки клиента...');
      final identityMessage = RouterMessage(
        type: RouterMessageType.heartbeat,
        senderId: _clientId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _p2pStreamController!.add(identityMessage);
      print('📤 RouterClient: Identity heartbeat отправлен');

      // Включаем автоматический heartbeat если запрошено
      if (enableAutoHeartbeat) {
        _startAutoHeartbeat();
      }

      print('✅ RouterClient: P2P соединение инициализировано для клиента: $_clientId');
      _logger?.info('P2P соединение инициализировано для клиента: $_clientId');
    } catch (e, stackTrace) {
      print('❌ RouterClient: Ошибка инициализации P2P: $e');
      print('❌ RouterClient: StackTrace: $stackTrace');
      _logger?.error('Ошибка инициализации P2P: $e', error: e, stackTrace: stackTrace);

      // Очищаем состояние при ошибке
      _p2pStreamController?.close();
      _p2pStreamController = null;
      _p2pResponseStream = null;

      rethrow; // Пробрасываем ошибку дальше
    }
  }

  /// Запускает автоматический heartbeat
  void _startAutoHeartbeat() {
    if (_autoHeartbeatEnabled) {
      return; // Уже запущен
    }

    _autoHeartbeatEnabled = true;
    _logger?.info('Запуск автоматического heartbeat (интервал: ${_heartbeatInterval.inSeconds}s)');

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_p2pStreamController != null && !_p2pStreamController!.isClosed) {
        try {
          sendHeartbeat();
        } catch (e) {
          _logger?.error('Ошибка автоматического heartbeat: $e');
        }
      } else {
        _stopAutoHeartbeat();
      }
    });
  }

  /// Останавливает автоматический heartbeat
  void _stopAutoHeartbeat() {
    if (!_autoHeartbeatEnabled) {
      return; // Уже остановлен
    }

    _autoHeartbeatEnabled = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _logger?.debug('Автоматический heartbeat остановлен');
  }

  /// Отправляет heartbeat через P2P поток
  void sendHeartbeat() {
    if (!isRegistered || _p2pStreamController == null) {
      throw StateError('P2P соединение не инициализировано');
    }

    final heartbeatMessage = RouterMessage(
      type: RouterMessageType.heartbeat,
      senderId: _clientId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _p2pStreamController!.add(heartbeatMessage);
    _logger?.debug('Heartbeat отправлен');
  }

  /// Отправляет unicast сообщение
  Future<void> sendUnicast(String targetId, Map<String, dynamic> payload) async {
    _ensureP2PInitialized();

    final message = RouterMessage.unicast(
      targetId: targetId,
      payload: payload,
      senderId: _clientId,
    );

    _p2pStreamController!.add(message);
    _logger?.debug('Отправлен unicast: $_clientId -> $targetId');
  }

  /// Отправляет multicast сообщение
  Future<void> sendMulticast(String groupName, Map<String, dynamic> payload) async {
    print('📤 RouterClient: Отправляем multicast в группу "$groupName"');
    print('    От клиента: $_clientId');
    print('    Payload: $payload');

    _ensureP2PInitialized();

    final message = RouterMessage.multicast(
      groupName: groupName,
      payload: payload,
      senderId: _clientId,
    );

    print('📤 RouterClient: Добавляем multicast сообщение в P2P stream');
    _p2pStreamController!.add(message);
    print('✅ RouterClient: Multicast сообщение добавлено в stream');
    _logger?.debug('Отправлен multicast: $_clientId -> группа $groupName');
  }

  /// Отправляет broadcast сообщение
  Future<void> sendBroadcast(Map<String, dynamic> payload) async {
    _ensureP2PInitialized();

    final message = RouterMessage.broadcast(
      payload: payload,
      senderId: _clientId,
    );

    _p2pStreamController!.add(message);
    _logger?.debug('Отправлен broadcast от $_clientId');
  }

  /// Отправляет произвольное P2P сообщение
  Future<void> sendP2PMessage(RouterMessage message) async {
    _ensureP2PInitialized();
    _p2pStreamController!.add(message);
    _logger?.debug('Отправлено P2P сообщение: ${message.type}');
  }

  /// Отправляет request с ожиданием response
  Future<Map<String, dynamic>> sendRequest(
    String targetId,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _ensureP2PInitialized();

    final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<Map<String, dynamic>>();

    // Сохраняем completer для обработки ответа
    _activeRequests[requestId] = completer;

    // Устанавливаем таймер
    _requestTimers[requestId] = Timer(timeout, () {
      if (_activeRequests.containsKey(requestId)) {
        _activeRequests.remove(requestId);
        _requestTimers.remove(requestId);
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Request timeout', timeout));
        }
      }
    });

    // Отправляем запрос
    final message = RouterMessage.request(
      targetId: targetId,
      requestId: requestId,
      payload: payload,
      senderId: _clientId,
    );

    _p2pStreamController!.add(message);
    _logger?.debug('Отправлен request: $_clientId -> $targetId (requestId: $requestId)');

    return completer.future;
  }

  /// Обрабатывает входящий response
  void _handleResponse(RouterMessage message) {
    final requestId = message.payload?['requestId'] as String?;
    if (requestId == null) return;

    final completer = _activeRequests.remove(requestId);
    final timer = _requestTimers.remove(requestId);

    if (completer != null && !completer.isCompleted) {
      timer?.cancel();

      if (message.success == true) {
        // Убираем requestId из payload для ответа
        final responsePayload = Map<String, dynamic>.from(message.payload ?? {});
        responsePayload.remove('requestId');
        completer.complete(responsePayload);
      } else {
        completer.completeError(Exception(message.errorMessage ?? 'Request failed'));
      }
    }
  }

  // === СОБЫТИЯ РОУТЕРА ===

  /// Подписывается на события роутера
  Future<void> subscribeToEvents() async {
    if (_eventsSubscription != null) {
      _logger?.warning('Уже подписан на события роутера');
      return;
    }

    final eventStream = _callerEndpoint.serverStream<RpcNull, RouterEvent>(
      serviceName: _serviceName,
      methodName: 'events',
      request: const RpcNull(),
      requestCodec: RpcCodec<RpcNull>((json) => RpcNull.fromJson(json)),
      responseCodec: RpcCodec<RouterEvent>((json) => RouterEvent.fromJson(json)),
    );

    _eventsSubscription = eventStream.listen(
      (event) {
        _logger?.debug('Получено событие роутера: ${event.type}');
        _eventsController.add(event);
      },
      onError: (error) {
        _logger?.error('Ошибка в стриме событий роутера: $error');
        _eventsController.addError(error);
      },
    );

    _logger?.info('Подписка на события роутера активирована');
  }

  /// Отписывается от событий роутера
  Future<void> unsubscribeFromEvents() async {
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _logger?.info('Отписка от событий роутера');
  }

  // === ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ===

  void _ensureP2PInitialized() {
    print('🔍 RouterClient: Проверяем состояние P2P...');
    print('    _clientId: $_clientId');
    print('    _p2pStreamController: ${_p2pStreamController != null ? 'есть' : 'null'}');
    print('    _p2pResponseStream: ${_p2pResponseStream != null ? 'есть' : 'null'}');

    if (_p2pStreamController == null) {
      print('❌ RouterClient: P2P соединение не инициализировано!');
      throw StateError('P2P соединение не инициализировано. Вызовите initializeP2P()');
    }

    print('✅ RouterClient: P2P соединение готово');
  }

  /// Закрывает все соединения
  Future<void> dispose() async {
    _logger?.info('Закрытие RouterClient...');

    // Останавливаем автоматический heartbeat
    _stopAutoHeartbeat();

    // Отменяем все активные запросы
    for (final timer in _requestTimers.values) {
      timer.cancel();
    }
    _activeRequests.clear();
    _requestTimers.clear();

    // Закрываем P2P соединение
    await _p2pStreamController?.close();
    _p2pStreamController = null;

    // Отписываемся от событий
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;

    await _eventsController.close();

    _logger?.info('RouterClient закрыт');
  }
}

/// Расширения для RouterMessage для удобного создания
extension RouterMessageExtensions on RouterMessage {
  /// Создает request сообщение
  static RouterMessage request({
    required String targetId,
    required String requestId,
    required Map<String, dynamic> payload,
    String? senderId,
    int? timeoutMs,
  }) {
    return RouterMessage(
      type: RouterMessageType.request,
      senderId: senderId,
      targetId: targetId,
      payload: {
        'requestId': requestId,
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
        ...payload,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создает response сообщение
  static RouterMessage response({
    required String targetId,
    required String requestId,
    required Map<String, dynamic> payload,
    String? senderId,
    bool success = true,
    String? errorMessage,
  }) {
    return RouterMessage(
      type: RouterMessageType.response,
      senderId: senderId,
      targetId: targetId,
      payload: {
        'requestId': requestId,
        ...payload,
      },
      success: success,
      errorMessage: errorMessage,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
