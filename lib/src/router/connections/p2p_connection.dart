// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import '../router_models.dart';

/// P2P соединение клиента роутера
///
/// Отвечает за инициализацию, поддержание и управление P2P соединением
/// между клиентом и роутером. Выделен из RouterClient для улучшения читаемости.
class RouterP2PConnection {
  final RpcCallerEndpoint _callerEndpoint;
  final String _serviceName;
  final String? _clientId;
  final RpcLogger? _logger;

  /// Стрим для P2P сообщений
  StreamController<RouterMessage>? _p2pStreamController;
  Stream<RouterMessage>? _p2pResponseStream;

  /// Активные запросы: requestId -> Completer
  final Map<String, Completer<Map<String, dynamic>>> _activeRequests = {};

  /// Таймеры для активных запросов: requestId -> Timer
  final Map<String, Timer> _requestTimers = {};

  /// Таймер для автоматического heartbeat
  Timer? _heartbeatTimer;

  /// Интервал автоматического heartbeat
  final Duration _heartbeatInterval;

  /// Включен ли автоматический heartbeat
  bool _autoHeartbeatEnabled = false;

  RouterP2PConnection({
    required RpcCallerEndpoint callerEndpoint,
    required String serviceName,
    required String? clientId,
    RpcLogger? logger,
    Duration heartbeatInterval = const Duration(seconds: 20),
  })  : _callerEndpoint = callerEndpoint,
        _serviceName = serviceName,
        _clientId = clientId,
        _logger = logger?.child('P2PConnection'),
        _heartbeatInterval = heartbeatInterval;

  /// Проверяет, инициализировано ли P2P соединение
  bool get isInitialized => _p2pStreamController != null;

  /// Инициализирует P2P соединение
  Future<void> initialize({
    void Function(RouterMessage message)? onP2PMessage,
    bool enableAutoHeartbeat = true,
    bool filterRouterHeartbeats = true,
  }) async {
    if (_clientId == null) {
      throw StateError(
          'Клиент должен быть зарегистрирован перед инициализацией P2P');
    }

    _logger?.info('Инициализация P2P соединения для клиента: $_clientId');

    try {
      // Создаем стрим контроллер для исходящих сообщений
      _logger?.debug('Создаем StreamController для исходящих P2P сообщений');
      _p2pStreamController = StreamController<RouterMessage>();

      // Подключаемся к P2P транспорту
      _logger?.debug('Подключаемся к bidirectionalStream router.p2p');
      _p2pResponseStream =
          _callerEndpoint.bidirectionalStream<RouterMessage, RouterMessage>(
        serviceName: _serviceName,
        methodName: 'p2p',
        requests: _p2pStreamController!.stream,
        requestCodec:
            RpcCodec<RouterMessage>((json) => RouterMessage.fromJson(json)),
        responseCodec:
            RpcCodec<RouterMessage>((json) => RouterMessage.fromJson(json)),
      );
      _logger?.debug('BidirectionalStream создан успешно');

      // Слушаем ответы и пересылаем в колбэк
      _logger?.debug('Настраиваем слушатель P2P сообщений');
      _p2pResponseStream!.listen(
        (message) {
          _logger?.debug(
              'Получено P2P сообщение: ${message.type} от ${message.senderId}');

          // Обрабатываем response сообщения внутри клиента
          if (message.type == RouterMessageType.response) {
            _handleResponse(message);
          }

          // Обрабатываем подтверждение соединения от роутера
          if (message.type == RouterMessageType.heartbeat &&
              message.senderId == 'router' &&
              message.payload?['connected'] == true) {
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
          _logger?.error('Ошибка в P2P стриме: $error');
          _stopAutoHeartbeat();
        },
        onDone: () {
          _logger?.info('P2P стрим закрыт');
          _stopAutoHeartbeat();
        },
      );

      // Отправляем первое сообщение для привязки к зарегистрированному клиенту
      _logger?.debug('Отправляем identity heartbeat для привязки клиента');
      final identityMessage = RouterMessage(
        type: RouterMessageType.heartbeat,
        senderId: _clientId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _p2pStreamController!.add(identityMessage);
      _logger?.debug('Identity heartbeat отправлен');

      // Включаем автоматический heartbeat если запрошено
      if (enableAutoHeartbeat) {
        _startAutoHeartbeat();
      }

      _logger?.info('P2P соединение инициализировано для клиента: $_clientId');
    } catch (e, stackTrace) {
      _logger?.error('Ошибка инициализации P2P: $e',
          error: e, stackTrace: stackTrace);

      // Очищаем состояние при ошибке
      await dispose();

      rethrow; // Пробрасываем ошибку дальше
    }
  }

  /// Отправляет P2P сообщение
  void sendMessage(RouterMessage message) {
    _ensureInitialized();
    _p2pStreamController!.add(message);
    _logger?.debug('Отправлено P2P сообщение: ${message.type}');
  }

  /// Отправляет heartbeat через P2P поток
  void sendHeartbeat() {
    _ensureInitialized();

    final heartbeatMessage = RouterMessage(
      type: RouterMessageType.heartbeat,
      senderId: _clientId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _p2pStreamController!.add(heartbeatMessage);
    _logger?.debug('Heartbeat отправлен');
  }

  /// Отправляет request с ожиданием response
  Future<Map<String, dynamic>> sendRequest(
    String targetId,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _ensureInitialized();

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
    _logger?.debug(
        'Отправлен request: $_clientId -> $targetId (requestId: $requestId)');

    return completer.future;
  }

  /// Запускает автоматический heartbeat
  void _startAutoHeartbeat() {
    if (_autoHeartbeatEnabled) {
      return; // Уже запущен
    }

    _autoHeartbeatEnabled = true;
    _logger?.info(
        'Запуск автоматического heartbeat (интервал: ${_heartbeatInterval.inSeconds}s)');

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
        final responsePayload =
            Map<String, dynamic>.from(message.payload ?? {});
        responsePayload.remove('requestId');
        completer.complete(responsePayload);
      } else {
        completer
            .completeError(Exception(message.errorMessage ?? 'Request failed'));
      }
    }
  }

  /// Проверяет что P2P соединение инициализировано
  void _ensureInitialized() {
    if (_p2pStreamController == null) {
      _logger?.error('P2P соединение не инициализировано');
      throw StateError(
          'P2P соединение не инициализировано. Вызовите initialize()');
    }
  }

  /// Закрывает P2P соединение
  Future<void> dispose() async {
    _logger?.info('Закрытие P2P соединения...');

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
    _p2pResponseStream = null;

    _logger?.info('P2P соединение закрыто');
  }
}
