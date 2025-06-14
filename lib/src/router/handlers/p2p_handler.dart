// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import '../router_models.dart';
import '../interfaces/router_interface.dart';

/// Обработчик P2P соединений роутера
///
/// Отвечает за сложную логику bidirectional stream соединений между клиентами.
/// Выделен из RouterResponderContract для улучшения читаемости.
class RouterP2PHandler {
  final IRouterContract _routerImpl;
  final RpcLogger? _logger;

  RouterP2PHandler({
    required IRouterContract routerImpl,
    RpcLogger? logger,
  })  : _routerImpl = routerImpl,
        _logger = logger?.child('P2PHandler');

  /// Обрабатывает P2P соединение между клиентами
  Stream<RouterMessage> handleP2PConnection(
    Stream<RouterMessage> clientMessages, {
    RpcContext? context,
  }) async* {
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
            // Инициализация соединения с первым сообщением
            _initializeConnection(message, responseController!, (id) {
              clientId = id;
              isInitialized = true;
            });
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
        // Очищаем стрим, клиент может переподключиться
        _routerImpl.removeClientStream(clientId!);
        _logger?.info('P2P стрим для клиента $clientId очищен, клиент может переподключиться');
      }

      if (responseController != null && !responseController.isClosed) {
        await responseController.close();
      }
    }
  }

  /// Инициализирует P2P соединение с первым сообщением
  void _initializeConnection(
    RouterMessage message,
    StreamController<RouterMessage> responseController,
    void Function(String clientId) onInitialized,
  ) {
    // Первое сообщение должно содержать senderId для привязки
    final clientId = message.senderId;

    if (clientId == null) {
      _logger?.warning('Первое P2P сообщение без senderId');
      responseController.add(RouterMessage(
        type: RouterMessageType.error,
        errorMessage: 'Первое сообщение должно содержать senderId',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      return;
    }

    _logger?.info('P2P соединение привязывается к клиенту: $clientId');

    // Проверяем что клиент зарегистрирован
    final clientInfo = _routerImpl.getClientInfo(clientId);
    if (clientInfo == null) {
      _logger?.warning('P2P соединение для незарегистрированного клиента: $clientId');
      responseController.add(RouterMessage(
        type: RouterMessageType.error,
        errorMessage: 'Клиент $clientId не зарегистрирован. Сначала вызовите register()',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      return;
    }

    // Заменяем временный стрим контроллер на реальный P2P стрим
    final streamReplaced = _routerImpl.replaceClientStream(clientId, responseController);
    if (!streamReplaced) {
      _logger?.error('Не удалось привязать P2P стрим для клиента: $clientId');
      responseController.add(RouterMessage(
        type: RouterMessageType.error,
        errorMessage: 'Ошибка привязки P2P стрима к клиенту $clientId',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      return;
    }

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

    // Вызываем колбэк инициализации
    onInitialized(clientId);

    // Обрабатываем первое сообщение если это не heartbeat
    if (message.type != RouterMessageType.heartbeat) {
      _routerImpl.handleIncomingMessage(message, clientId);
    }
  }
}
