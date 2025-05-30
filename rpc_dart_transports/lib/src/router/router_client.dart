// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'router_models.dart';

/// Клиентская часть роутера для подключения к серверу роутера
final class RouterCallerContract extends RpcCallerContract {
  /// Контроллер для отправки сообщений роутеру
  StreamController<RouterMessage>? _outgoingController;

  /// Подписка на входящие сообщения от роутера
  StreamSubscription<RouterMessage>? _incomingSubscription;

  /// ID клиента, присвоенный роутером
  String? _clientId;

  /// Контроллер для входящих сообщений от других клиентов
  final StreamController<RouterMessage> _messagesController =
      StreamController<RouterMessage>.broadcast();

  /// Контроллер для системных событий роутера
  final StreamController<RouterEvent> _eventsController = StreamController<RouterEvent>.broadcast();

  /// Логгер для отладки
  final RpcLogger? _logger;

  /// Флаг подключения к роутеру
  bool _isConnected = false;

  RouterCallerContract(
    RpcCallerEndpoint endpoint, {
    RpcLogger? logger,
  })  : _logger = logger?.child('RouterClient'),
        super('router', endpoint);

  /// ID клиента (доступен после подключения)
  String? get clientId => _clientId;

  /// Статус подключения к роутеру
  bool get isConnected => _isConnected;

  /// Поток входящих сообщений от других клиентов
  Stream<RouterMessage> get messages => _messagesController.stream;

  /// Поток системных событий роутера
  Stream<RouterEvent> get events => _eventsController.stream;

  /// Подключается к роутеру и регистрирует клиента
  Future<String> connect({
    String? clientName,
    List<String>? groups,
  }) async {
    if (_isConnected) {
      throw StateError('Клиент уже подключен к роутеру');
    }

    try {
      _logger?.info('Подключение к роутеру...');

      // Создаем контроллер для исходящих сообщений
      _outgoingController = StreamController<RouterMessage>();

      // Вызываем двунаправленный метод connect
      final responseStream = endpoint.bidirectionalStream<RouterMessage, RouterMessage>(
        serviceName: 'router',
        methodName: 'connect',
        requestCodec: RpcCodec<RouterMessage>(
          (json) => RouterMessage.fromJson(json),
        ),
        responseCodec: RpcCodec<RouterMessage>(
          (json) => RouterMessage.fromJson(json),
        ),
        requests: _outgoingController!.stream,
      );

      // Слушаем ответы от роутера
      _incomingSubscription = responseStream.listen(
        _handleIncomingMessage,
        onError: (error) {
          _logger?.error('Ошибка в стриме роутера: $error');
          _disconnect();
        },
        onDone: () {
          _logger?.info('Соединение с роутером разорвано');
          _disconnect();
        },
      );

      // Отправляем сообщение регистрации
      final registerMessage = RouterMessage.register(
        clientName: clientName,
        groups: groups,
      );

      _outgoingController!.add(registerMessage);
      _logger?.debug('Отправлено сообщение регистрации');

      // Ждем ответ на регистрацию
      final completer = Completer<String>();
      late StreamSubscription tempSub;

      tempSub = messages.listen((message) {
        if (message.type == RouterMessageType.registerResponse) {
          tempSub.cancel();

          if (message.success == true) {
            _clientId = message.payload?['clientId'] as String?;
            if (_clientId != null) {
              _isConnected = true;
              _logger?.info('Успешно подключен к роутеру с ID: $_clientId');
              completer.complete(_clientId!);
            } else {
              completer.completeError('Не получен clientId в ответе роутера');
            }
          } else {
            completer.completeError(message.errorMessage ?? 'Ошибка регистрации в роутере');
          }
        }
      });

      return await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          tempSub.cancel();
          throw TimeoutException('Таймаут регистрации в роутере');
        },
      );
    } catch (e) {
      _logger?.error('Ошибка подключения к роутеру: $e');
      await _disconnect();
      rethrow;
    }
  }

  /// Отправляет unicast сообщение конкретному клиенту
  Future<void> sendUnicast({
    required String targetId,
    required Map<String, dynamic> payload,
  }) async {
    _ensureConnected();

    final message = RouterMessage.unicast(
      targetId: targetId,
      payload: payload,
      senderId: _clientId,
    );

    _outgoingController!.add(message);
    _logger?.debug('Отправлено unicast сообщение к $targetId');
  }

  /// Отправляет multicast сообщение группе клиентов
  Future<void> sendMulticast({
    required String groupName,
    required Map<String, dynamic> payload,
  }) async {
    _ensureConnected();

    final message = RouterMessage.multicast(
      groupName: groupName,
      payload: payload,
      senderId: _clientId,
    );

    _outgoingController!.add(message);
    _logger?.debug('Отправлено multicast сообщение группе $groupName');
  }

  /// Отправляет broadcast сообщение всем клиентам
  Future<void> sendBroadcast({
    required Map<String, dynamic> payload,
  }) async {
    _ensureConnected();

    final message = RouterMessage.broadcast(
      payload: payload,
      senderId: _clientId,
    );

    _outgoingController!.add(message);
    _logger?.debug('Отправлено broadcast сообщение');
  }

  /// Отправляет ping роутеру
  Future<Duration> ping() async {
    _ensureConnected();

    final startTime = DateTime.now();
    final pingMessage = RouterMessage.ping(senderId: _clientId);

    _outgoingController!.add(pingMessage);
    _logger?.debug('Отправлен ping роутеру');

    final completer = Completer<Duration>();
    late StreamSubscription tempSub;

    tempSub = messages.listen((message) {
      if (message.type == RouterMessageType.pong && message.senderId == 'router') {
        tempSub.cancel();

        final endTime = DateTime.now();
        final latency = endTime.difference(startTime);
        completer.complete(latency);
      }
    });

    return await completer.future.timeout(
      Duration(seconds: 5),
      onTimeout: () {
        tempSub.cancel();
        throw TimeoutException('Таймаут ping');
      },
    );
  }

  /// Подписывается на системные события роутера
  Future<void> subscribeToEvents() async {
    _ensureConnected();

    _logger?.info('Подписка на системные события роутера...');

    try {
      // Создаем пустое сообщение для подписки
      final subscriptionRequest = RouterMessage(
        type: RouterMessageType.register, // Используем любой тип
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Подписываемся на серверный поток событий
      final eventStream = endpoint.serverStream<RouterMessage, RouterEvent>(
        serviceName: 'router',
        methodName: 'events',
        requestCodec: RpcCodec<RouterMessage>(
          (json) => RouterMessage.fromJson(json),
        ),
        responseCodec: RpcCodec<RouterEvent>(
          (json) => RouterEvent.fromJson(json),
        ),
        request: subscriptionRequest,
      );

      // Перенаправляем события в локальный контроллер
      eventStream.listen(
        (event) {
          _logger?.debug('Получено системное событие: ${event.type}');
          if (!_eventsController.isClosed) {
            _eventsController.add(event);
          }
        },
        onError: (error) {
          _logger?.error('Ошибка в потоке событий: $error');
          if (!_eventsController.isClosed) {
            _eventsController.addError(error);
          }
        },
        onDone: () {
          _logger?.info('Поток системных событий завершен');
        },
      );

      _logger?.info('Подписка на события успешно установлена');
    } catch (e) {
      _logger?.error('Ошибка подписки на события: $e');
      rethrow;
    }
  }

  /// Отключается от роутера
  Future<void> disconnect() async {
    await _disconnect();
  }

  /// Обрабатывает входящие сообщения от роутера
  void _handleIncomingMessage(RouterMessage message) {
    _logger?.debug('Получено сообщение: ${message.type}');

    // Пересылаем все сообщения в общий стрим
    if (!_messagesController.isClosed) {
      _messagesController.add(message);
    }
  }

  /// Проверяет, что клиент подключен к роутеру
  void _ensureConnected() {
    if (!_isConnected) {
      throw StateError('Клиент не подключен к роутеру. Вызовите connect() сначала.');
    }
  }

  /// Внутренний метод отключения
  Future<void> _disconnect() async {
    _isConnected = false;
    _clientId = null;

    await _incomingSubscription?.cancel();
    _incomingSubscription = null;

    if (_outgoingController != null && !_outgoingController!.isClosed) {
      await _outgoingController!.close();
    }
    _outgoingController = null;

    _logger?.info('Отключен от роутера');
  }

  /// Освобождает ресурсы клиента
  Future<void> dispose() async {
    await _disconnect();

    if (!_messagesController.isClosed) {
      await _messagesController.close();
    }

    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
  }
}
