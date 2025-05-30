// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:math';

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

  /// Генератор случайных чисел для создания ID
  final Random _random = Random();

  /// Логгер для отладки роутера
  final RpcLogger? _logger;

  RouterResponderContract({RpcLogger? logger})
      : _logger = logger?.child('RouterContract'),
        super('router') {
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
          _handleClientMessage(message, clientId);
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
      }).transform(StreamTransformer.fromHandlers(
        handleData: (message, sink) {
          // Если это первое сообщение и clientId еще не установлен
          if (clientId == null && message.type == RouterMessageType.register) {
            clientId = _generateClientId();
            _clientStreams[clientId!] = clientController!;

            _logger?.info('Клиент зарегистрирован: $clientId');

            // Отправляем подтверждение регистрации
            sink.add(RouterMessage.registerResponse(
              clientId: clientId!,
              success: true,
            ));
          } else {
            sink.add(message);
          }
        },
      ));
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

    _logger?.info('Клиент отключен: $clientId (активных: ${_clientStreams.length})');
  }

  /// Генерирует уникальный ID клиента
  String _generateClientId() {
    return 'client_${_random.nextInt(999999).toString().padLeft(6, '0')}';
  }

  /// Получает информацию о состоянии роутера
  RouterStats get stats => RouterStats(
        activeClients: _clientStreams.length,
        clientIds: _clientStreams.keys.toList(),
      );
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
