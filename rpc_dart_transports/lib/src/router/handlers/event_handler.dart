// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

import '../router_models.dart';
import '../interfaces/router_interface.dart';

/// Обработчик событий роутера
///
/// Отвечает за обработку server stream подписок на события роутера.
/// Выделен из RouterResponderContract для улучшения читаемости.
class RouterEventHandler {
  final IRouterContract _routerImpl;
  final RpcLogger? _logger;

  RouterEventHandler({
    required IRouterContract routerImpl,
    RpcLogger? logger,
  })  : _routerImpl = routerImpl,
        _logger = logger?.child('EventHandler');

  /// Обрабатывает подписку на события роутера
  Stream<RouterEvent> handleEventSubscription(RpcNull subscriptionRequest) async* {
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
}
