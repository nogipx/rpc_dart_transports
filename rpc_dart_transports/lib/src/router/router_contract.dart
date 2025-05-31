// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'router_models.dart';
import 'models/_index.dart';
import 'implementations/router_responder.dart';
import 'interfaces/router_interface.dart';

/// RPC контракт роутера для маршрутизации сообщений между клиентами.
///
/// Этот класс является адаптером между RPC фреймворком и основной
/// реализацией роутера RouterResponderImpl.
final class RouterResponderContract extends RpcResponderContract {
  /// Основная реализация роутера
  final RouterResponderImpl _routerImpl;

  /// Логгер для отладки контракта
  final RpcLogger? _logger;

  RouterResponderContract({RpcLogger? logger})
      : _logger = logger?.child('RouterContract'),
        _routerImpl = RouterResponderImpl(logger: logger),
        super('router') {
    setup(); // Автоматически настраиваем контракт
  }

  /// Получить доступ к реализации роутера для продвинутого использования
  IRouterContract get routerImpl => _routerImpl;

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
      final clientId = _routerImpl.generateClientId();

      _logger?.info('Предварительная регистрация клиента: $clientId (${request.clientName})');

      // Создаем временный контроллер для начальной регистрации
      // Он будет заменен при установке P2P соединения
      final tempController = StreamController<RouterMessage>();

      final success = await _routerImpl.registerClient(
        clientId,
        tempController,
        clientName: request.clientName,
        groups: request.groups,
        metadata: request.metadata,
      );

      if (!success) {
        await tempController.close();
        return RouterRegisterResponse(
          clientId: '',
          success: false,
          errorMessage: 'Ошибка регистрации клиента в роутере',
        );
      }

      _logger?.info('Клиент предварительно зарегистрирован: $clientId, ожидается P2P соединение');

      return RouterRegisterResponse(
        clientId: clientId,
        success: success,
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
    final clients = _routerImpl.getActiveClients(
      groups: request.groups,
      metadata: request.metadata,
    );

    _logger?.debug('Отправлен список клиентов (${clients.length})');

    return RouterClientsList(clients);
  }

  // === ОБРАБОТЧИК P2P ТРАНСПОРТА ===

  /// Обрабатывает P2P соединение между клиентами
  Stream<RouterMessage> _handleP2PConnection(
    Stream<RouterMessage> clientMessages,
  ) async* {
    StreamController<RouterMessage>? responseController;
    String? clientId;
    StreamSubscription? subscription;
    bool isInitialized = false;

    _logger?.info('Новое P2P соединение установлено');

    try {
      responseController = StreamController<RouterMessage>();

      // Подписываемся на входящие сообщения
      subscription = clientMessages.listen(
        (message) {
          if (!isInitialized) {
            // Первое сообщение должно содержать senderId для привязки
            clientId = message.senderId;

            if (clientId == null) {
              _logger?.warning('Первое P2P сообщение без senderId');
              responseController?.add(RouterMessage(
                type: RouterMessageType.error,
                errorMessage: 'Первое сообщение должно содержать senderId',
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));
              return;
            }

            _logger?.info('P2P соединение привязывается к клиенту: $clientId');

            // Проверяем что клиент зарегистрирован
            final clientInfo = _routerImpl.getClientInfo(clientId!);
            if (clientInfo == null) {
              _logger?.warning('P2P соединение для незарегистрированного клиента: $clientId');
              responseController?.add(RouterMessage(
                type: RouterMessageType.error,
                errorMessage: 'Клиент $clientId не зарегистрирован. Сначала вызовите register()',
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));
              return;
            }

            // Заменяем временный стрим контроллер на реальный P2P стрим
            final streamReplaced = _routerImpl.replaceClientStream(clientId!, responseController!);
            if (!streamReplaced) {
              _logger?.error('Не удалось привязать P2P стрим для клиента: $clientId');
              responseController.add(RouterMessage(
                type: RouterMessageType.error,
                errorMessage: 'Ошибка привязки P2P стрима к клиенту $clientId',
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));
              return;
            }

            isInitialized = true;
            _logger?.info('P2P соединение успешно привязано к клиенту: $clientId');

            // Отправляем подтверждение подключения
            responseController.add(RouterMessage(
              type: RouterMessageType.heartbeat,
              senderId: 'router',
              targetId: clientId,
              payload: {'connected': true, 'timestamp': DateTime.now().millisecondsSinceEpoch},
              success: true,
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));

            // Обрабатываем первое сообщение если это не heartbeat
            if (message.type != RouterMessageType.heartbeat) {
              _routerImpl.handleIncomingMessage(message, clientId!);
            }
          } else {
            // Обрабатываем все последующие сообщения
            if (clientId != null) {
              _logger?.debug('P2P сообщение от $clientId: ${message.type}');
              _routerImpl.handleIncomingMessage(message, clientId!);
            }
          }
        },
        onError: (error) {
          _logger?.error('Ошибка в P2P стриме для $clientId: $error');
          if (clientId != null && responseController != null && !responseController.isClosed) {
            responseController.add(RouterMessage(
              type: RouterMessageType.error,
              targetId: clientId!,
              senderId: 'router',
              errorMessage: 'Ошибка P2P соединения: $error',
              success: false,
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        },
        onDone: () {
          _logger?.info('P2P стрим закрыт для клиента: $clientId');

          // Обновляем статус клиента на disconnecting
          if (clientId != null) {
            final clientInfo = _routerImpl.getClientInfo(clientId!);
            if (clientInfo != null) {
              _routerImpl.updateClientMetadata(clientId!, {
                ...clientInfo.metadata,
                '_status': 'disconnecting',
                '_lastSeen': DateTime.now().millisecondsSinceEpoch,
              });
            }
          }
        },
      );

      // Возвращаем исходящие сообщения для клиента
      yield* responseController.stream;
    } catch (e, stackTrace) {
      _logger?.error('Критическая ошибка в P2P соединении: $e', error: e, stackTrace: stackTrace);

      if (clientId != null && responseController != null && !responseController.isClosed) {
        responseController.add(RouterMessage(
          type: RouterMessageType.error,
          targetId: clientId!,
          senderId: 'router',
          errorMessage: 'Критическая ошибка P2P соединения: $e',
          success: false,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }

      rethrow;
    } finally {
      await subscription?.cancel();

      if (clientId != null) {
        // НЕ удаляем клиента полностью - только очищаем стрим
        // Клиент может переподключиться с новым P2P стримом
        _routerImpl.removeClientStream(clientId!);
        _logger?.info('P2P стрим для клиента $clientId очищен, клиент может переподключиться');
      }

      if (responseController != null && !responseController.isClosed) {
        await responseController.close();
      }
    }
  }

  // === ОБРАБОТЧИК СОБЫТИЙ ===

  /// Обрабатывает подписку на события роутера
  Stream<RouterEvent> _handleEventSubscription(RpcNull subscriptionRequest) async* {
    _logger?.debug('Новая подписка на события роутера');

    try {
      // Создаем стрим через роутер
      final eventStream = _routerImpl.subscribeToEvents();

      // Отправляем приветственное событие с текущей статистикой
      final stats = _routerImpl.stats;
      final welcomeEvent = RouterEvent.routerStats(
        activeClients: stats.activeClients,
        messagesPerSecond: 0, // Не реализуем - слишком сложно
        messageTypeCounts: {'total': stats.totalMessages}, // Простая версия
      );

      // Сначала отправляем приветственное событие
      yield welcomeEvent;

      // Затем возвращаем поток событий
      yield* eventStream;
    } catch (e, stackTrace) {
      _logger?.error('Ошибка в подписке на события: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Освобождает ресурсы роутера
  Future<void> dispose() async {
    _logger?.info('Закрытие роутера...');
    await _routerImpl.dispose();
    _logger?.info('Роутер закрыт');
  }
}
