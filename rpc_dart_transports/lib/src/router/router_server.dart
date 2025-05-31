// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'router_contract.dart';
import 'implementations/router_responder.dart';
import 'global_message_bus.dart';

/// Транспорт-агностичный роутер сервер
///
/// Может работать с любым транспортом: WebSocket, HTTP/2, изоляты и т.д.
/// Управляет общим состоянием роутера между всеми соединениями.
class RouterServer {
  /// Общая реализация роутера для всех соединений
  final RouterResponderImpl _sharedRouterImpl;

  /// Логгер сервера
  final RpcLogger? _logger;

  /// Счетчик соединений
  int _connectionCount = 0;

  /// Активные endpoint'ы
  final Map<String, RpcResponderEndpoint> _endpoints = {};

  /// Активные контракты
  final Map<String, RouterResponderContract> _contracts = {};

  RouterServer({
    RpcLogger? logger,
    RouterResponderImpl? sharedRouterImpl,
  })  : _logger = logger?.child('RouterServer'),
        _sharedRouterImpl = sharedRouterImpl ?? RouterResponderImpl(logger: logger);

  /// Доступ к реализации роутера
  RouterResponderImpl get routerImpl => _sharedRouterImpl;

  /// Создает новое соединение с роутером
  ///
  /// [transport] - любой RPC транспорт
  /// [connectionLabel] - опциональная метка для отладки
  /// [clientAddress] - адрес клиента для логирования
  String createConnection({
    required IRpcTransport transport,
    String? connectionLabel,
    String? clientAddress,
  }) {
    _connectionCount++;
    final connectionId = connectionLabel ?? 'connection_$_connectionCount';

    _logger?.info(
        'Новое соединение: $connectionId${clientAddress != null ? ' ($clientAddress)' : ''}');

    try {
      // Создаем RouterContract с общим RouterImpl
      final routerContract = RouterResponderContract(
        logger: _logger?.child('Contract#$connectionId'),
        sharedRouterImpl: _sharedRouterImpl,
      );

      // Регистрируем endpoint в глобальной шине
      final endpointInfo = EndpointInfo(
        endpointId: connectionId,
        address: clientAddress ?? 'unknown',
        connectedAt: DateTime.now(),
      );
      GlobalMessageBus().registerEndpoint(connectionId, endpointInfo);

      // Создаем RPC эндпоинт с указанным транспортом
      final endpoint = RpcResponderEndpoint(
        transport: transport,
        debugLabel: 'RouterEndpoint#$connectionId',
      );

      // Регистрируем роутер контракт
      endpoint.registerServiceContract(routerContract);

      // Сохраняем соединение
      _endpoints[connectionId] = endpoint;
      _contracts[connectionId] = routerContract;

      // Запускаем endpoint
      endpoint.start();

      _logger?.info('Соединение $connectionId активировано');

      return connectionId;
    } catch (e, stackTrace) {
      _logger?.error('Ошибка создания соединения $connectionId: $e',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Закрывает конкретное соединение
  Future<void> closeConnection(String connectionId, {String? reason}) async {
    _logger?.info('Закрытие соединения $connectionId${reason != null ? ' ($reason)' : ''}');

    try {
      // Удаляем из глобальной шины
      GlobalMessageBus().unregisterEndpoint(connectionId);

      // Закрываем endpoint
      final endpoint = _endpoints.remove(connectionId);
      if (endpoint != null) {
        await endpoint.close();
      }

      // Освобождаем контракт
      final contract = _contracts.remove(connectionId);
      if (contract != null) {
        // RouterContract автоматически очистится при закрытии endpoint
      }

      _logger?.info('Соединение $connectionId закрыто');
    } catch (e) {
      _logger?.warning('Ошибка при закрытии соединения $connectionId: $e');
    }
  }

  /// Получает статистику сервера
  RouterServerStats getStats() {
    return RouterServerStats(
      activeConnections: _endpoints.length,
      totalConnections: _connectionCount,
      routerStats: _sharedRouterImpl.stats,
      connectionIds: _endpoints.keys.toList(),
    );
  }

  /// Получает информацию о конкретном соединении
  ConnectionInfo? getConnectionInfo(String connectionId) {
    final endpoint = _endpoints[connectionId];
    final contract = _contracts[connectionId];

    if (endpoint == null || contract == null) {
      return null;
    }

    return ConnectionInfo(
      connectionId: connectionId,
      isActive: endpoint.isActive,
      transport: endpoint.transport.runtimeType.toString(),
    );
  }

  /// Получает список всех активных соединений
  List<ConnectionInfo> getActiveConnections() {
    return _endpoints.keys
        .map((id) => getConnectionInfo(id))
        .where((info) => info != null)
        .cast<ConnectionInfo>()
        .toList();
  }

  /// Закрывает сервер и все соединения
  Future<void> dispose() async {
    _logger?.info('Закрытие RouterServer...');

    // Закрываем все соединения
    final connectionIds = _endpoints.keys.toList();
    for (final connectionId in connectionIds) {
      await closeConnection(connectionId, reason: 'Server shutdown');
    }

    // Закрываем общий роутер
    await _sharedRouterImpl.dispose();

    _logger?.info('RouterServer закрыт');
  }
}

/// Статистика роутер сервера
class RouterServerStats {
  final int activeConnections;
  final int totalConnections;
  final dynamic routerStats; // RouterStats
  final List<String> connectionIds;

  const RouterServerStats({
    required this.activeConnections,
    required this.totalConnections,
    required this.routerStats,
    required this.connectionIds,
  });

  @override
  String toString() {
    return 'RouterServerStats('
        'activeConnections: $activeConnections, '
        'totalConnections: $totalConnections, '
        'connectionIds: $connectionIds, '
        'routerStats: $routerStats'
        ')';
  }
}

/// Информация о соединении
class ConnectionInfo {
  final String connectionId;
  final bool isActive;
  final String transport;

  const ConnectionInfo({
    required this.connectionId,
    required this.isActive,
    required this.transport,
  });

  @override
  String toString() {
    return 'ConnectionInfo('
        'connectionId: $connectionId, '
        'isActive: $isActive, '
        'transport: $transport'
        ')';
  }
}
