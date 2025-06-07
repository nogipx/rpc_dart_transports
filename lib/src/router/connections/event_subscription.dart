// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import '../router_models.dart';

/// Подписка на события роутера
///
/// Отвечает за подписку на события роутера и их обработку.
/// Выделен из RouterClient для улучшения читаемости.
class RouterEventSubscription {
  final RpcCallerEndpoint _callerEndpoint;
  final String _serviceName;
  final RpcLogger? _logger;

  /// Подписка на события роутера
  StreamSubscription<RouterEvent>? _eventsSubscription;

  /// Контроллер для публикации событий
  final StreamController<RouterEvent> _eventsController =
      StreamController.broadcast();

  RouterEventSubscription({
    required RpcCallerEndpoint callerEndpoint,
    required String serviceName,
    RpcLogger? logger,
  })  : _callerEndpoint = callerEndpoint,
        _serviceName = serviceName,
        _logger = logger?.child('EventSubscription');

  /// Стрим событий роутера
  Stream<RouterEvent> get events => _eventsController.stream;

  /// Проверяет, активна ли подписка
  bool get isSubscribed => _eventsSubscription != null;

  /// Подписывается на события роутера
  Future<void> subscribe() async {
    if (_eventsSubscription != null) {
      _logger?.warning('Уже подписан на события роутера');
      return;
    }

    try {
      final eventStream = _callerEndpoint.serverStream<RpcNull, RouterEvent>(
        serviceName: _serviceName,
        methodName: 'events',
        request: const RpcNull(),
        requestCodec: RpcCodec<RpcNull>((json) => RpcNull.fromJson(json)),
        responseCodec:
            RpcCodec<RouterEvent>((json) => RouterEvent.fromJson(json)),
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
        onDone: () {
          _logger?.info('Стрим событий роутера закрыт');
          _eventsSubscription = null;
        },
      );

      _logger?.info('Подписка на события роутера активирована');
    } catch (e, stackTrace) {
      _logger?.error('Ошибка подписки на события: $e',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Отписывается от событий роутера
  Future<void> unsubscribe() async {
    if (_eventsSubscription != null) {
      await _eventsSubscription!.cancel();
      _eventsSubscription = null;
      _logger?.info('Отписка от событий роутера');
    }
  }

  /// Закрывает подписку на события
  Future<void> dispose() async {
    _logger?.info('Закрытие подписки на события...');

    await unsubscribe();
    await _eventsController.close();

    _logger?.info('Подписка на события закрыта');
  }
}
