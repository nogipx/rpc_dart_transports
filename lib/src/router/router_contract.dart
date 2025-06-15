// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'router_models.dart';
import 'models/_index.dart';
import 'implementations/_index.dart';
import 'interfaces/router_interface.dart';
import 'handlers/rpc_handler.dart';
import 'handlers/event_handler.dart';
import 'handlers/p2p_handler.dart';

/// RPC контракт роутера для маршрутизации сообщений между клиентами.
///
/// Этот класс является адаптером между RPC фреймворком и основной
/// реализацией роутера RouterResponderImpl.
final class RouterResponderContract extends RpcResponderContract {
  /// Основная реализация роутера
  final RouterResponderImpl _routerImpl;

  /// Обработчик прямых RPC методов
  late final RouterRpcHandler _rpcHandler;

  /// Обработчик событий роутера
  late final RouterEventHandler _eventHandler;

  /// Обработчик P2P соединений
  late final RouterP2PHandler _p2pHandler;

  /// Логгер для отладки контракта
  final RpcLogger? _logger;

  RouterResponderContract({
    RpcLogger? logger,
    RouterResponderImpl? sharedRouterImpl,
  })  : _logger = logger?.child('RouterContract'),
        _routerImpl = sharedRouterImpl ?? RouterResponderImpl(logger: logger),
        super('router') {
    // Инициализируем обработчики
    _rpcHandler = RouterRpcHandler(
      routerImpl: _routerImpl,
      logger: _logger,
    );

    _eventHandler = RouterEventHandler(
      routerImpl: _routerImpl,
      logger: _logger,
    );

    _p2pHandler = RouterP2PHandler(
      routerImpl: _routerImpl,
      logger: _logger,
    );

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
      handler: _rpcHandler.handleRegister,
    );

    // Ping роутера
    addUnaryMethod<RpcInt, RouterPongResponse>(
      methodName: 'ping',
      requestCodec: RpcCodec<RpcInt>((json) => RpcInt.fromJson(json)),
      responseCodec: RpcCodec<RouterPongResponse>(
        (json) => RouterPongResponse.fromJson(json),
      ),
      handler: _rpcHandler.handlePing,
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
      handler: _rpcHandler.handleGetOnlineClients,
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
      handler: _p2pHandler.handleP2PConnection,
    );

    // === СОБЫТИЯ РОУТЕРА ===

    // Серверный поток для системных событий
    addServerStreamMethod<RpcNull, RouterEvent>(
      methodName: 'events',
      requestCodec: RpcCodec<RpcNull>((json) => RpcNull.fromJson(json)),
      responseCodec: RpcCodec<RouterEvent>(
        (json) => RouterEvent.fromJson(json),
      ),
      handler: _eventHandler.handleEventSubscription,
    );

    _logger?.info('Router контракт настроен');
  }

  // === Обработчики делегированы в специализированные классы ===

  /// Освобождает ресурсы роутера
  Future<void> dispose() async {
    _logger?.info('Закрытие роутера...');
    await _routerImpl.dispose();
    _logger?.info('Роутер закрыт');
  }
}
