// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:http2/http2.dart' as http2;
import 'package:rpc_dart/rpc_dart.dart';

import 'rpc_http2_responder_transport.dart';

/// Высокоуровневый HTTP/2 RPC сервер
///
/// Автоматически управляет HTTP/2 соединениями и создает RPC endpoints
/// для каждого подключения. Поддерживает все типы RPC операций.
class RpcHttp2Server {
  final String _host;
  final int _port;
  final RpcLogger? _logger;

  /// Колбэк для настройки каждого нового RPC endpoint
  final void Function(RpcResponderEndpoint endpoint)? _onEndpointCreated;

  /// Колбэк для обработки ошибок соединения
  final void Function(Object error, StackTrace? stack)? _onConnectionError;

  ServerSocket? _serverSocket;
  final List<StreamSubscription> _subscriptions = [];
  final List<RpcResponderEndpoint> _endpoints = [];
  bool _isRunning = false;

  /// Создает HTTP/2 сервер
  ///
  /// [host] - хост для привязки (по умолчанию 'localhost')
  /// [port] - порт для привязки
  /// [onEndpointCreated] - колбэк для настройки каждого нового endpoint
  /// [onConnectionError] - колбэк для обработки ошибок соединения
  /// [logger] - логгер для отладки
  RpcHttp2Server({
    String host = 'localhost',
    required int port,
    void Function(RpcResponderEndpoint endpoint)? onEndpointCreated,
    void Function(Object error, StackTrace? stack)? onConnectionError,
    RpcLogger? logger,
  })  : _host = host,
        _port = port,
        _onEndpointCreated = onEndpointCreated,
        _onConnectionError = onConnectionError,
        _logger = logger?.child('Http2Server');

  /// Запускает HTTP/2 сервер
  Future<void> start() async {
    if (_isRunning) {
      throw StateError('HTTP/2 сервер уже запущен');
    }

    _logger?.info('Запуск HTTP/2 RPC сервера на $_host:$_port');

    try {
      // Создаем TCP сервер для HTTP/2
      _serverSocket = await ServerSocket.bind(_host, _port);
      _logger?.info('HTTP/2 сервер запущен на $_host:$_port');

      _isRunning = true;

      // Обработка TCP соединений
      final subscription = _serverSocket!.listen((socket) {
        _handleConnection(socket);
      });
      _subscriptions.add(subscription);

      _logger?.info('HTTP/2 RPC сервер готов принимать соединения');
    } catch (e, stackTrace) {
      _logger?.error('Ошибка запуска HTTP/2 сервера: $e', error: e, stackTrace: stackTrace);
      await stop();
      rethrow;
    }
  }

  /// Обрабатывает TCP соединение
  void _handleConnection(Socket socket) {
    final clientAddress = '${socket.remoteAddress}:${socket.remotePort}';
    _logger?.debug('Новое соединение от $clientAddress');

    try {
      // Создаем HTTP/2 соединение
      final connection = http2.ServerTransportConnection.viaSocket(socket);
      _setupRpcEndpoint(connection, clientAddress);
    } catch (e, stackTrace) {
      _logger?.error('Ошибка обработки соединения от $clientAddress: $e',
          error: e, stackTrace: stackTrace);
      _onConnectionError?.call(e, stackTrace);
      socket.destroy();
    }
  }

  /// Настраивает RPC endpoint для соединения
  void _setupRpcEndpoint(http2.ServerTransportConnection connection, String clientAddress) {
    try {
      // Создаем HTTP/2 транспорт (низкий уровень)
      final transport = RpcHttp2ResponderTransport.create(
        connection: connection,
        logger: _logger?.child('Transport'),
      );

      // Создаем RPC endpoint (высокий уровень)
      final endpoint = RpcResponderEndpoint(
        transport: transport,
        debugLabel: 'Http2Endpoint($clientAddress)',
      );

      _endpoints.add(endpoint);

      // ⭐ ЗДЕСЬ ПРОИСХОДИТ РЕГИСТРАЦИЯ RPC КОНТРАКТОВ ⭐
      _onEndpointCreated?.call(endpoint);

      // Запускаем endpoint
      endpoint.start();

      _logger?.info('RPC endpoint создан для $clientAddress');

      // Отслеживаем закрытие соединения
      transport.incomingMessages.listen(
        (message) {
          // Сообщения автоматически обрабатываются endpoint'ом
        },
        onError: (error) {
          _logger?.debug('Ошибка в транспорте для $clientAddress: $error');
        },
        onDone: () {
          _logger?.debug('Соединение с $clientAddress закрыто');
          _endpoints.remove(endpoint);
          endpoint.close().catchError((e) {
            _logger?.debug('Ошибка закрытия endpoint: $e');
          });
        },
      );
    } catch (e, stackTrace) {
      _logger?.error('Ошибка настройки RPC endpoint: $e', error: e, stackTrace: stackTrace);
      _onConnectionError?.call(e, stackTrace);
    }
  }

  /// Останавливает HTTP/2 сервер
  Future<void> stop() async {
    if (!_isRunning) return;

    _logger?.info('Остановка HTTP/2 RPC сервера...');
    _isRunning = false;

    // Отменяем все подписки
    await Future.wait(_subscriptions.map((s) => s.cancel()));
    _subscriptions.clear();

    // Закрываем все endpoints
    await Future.wait(_endpoints.map((e) => e.close()));
    _endpoints.clear();

    // Закрываем серверный сокет
    if (_serverSocket != null) {
      await _serverSocket!.close();
      _serverSocket = null;
    }

    _logger?.info('HTTP/2 RPC сервер остановлен');
  }

  /// Проверяет, запущен ли сервер
  bool get isRunning => _isRunning;

  /// Получает хост сервера
  String get host => _host;

  /// Получает порт сервера
  int get port => _port;

  /// Получает количество активных соединений
  int get activeConnections => _endpoints.length;

  /// Получает список активных endpoints
  List<RpcResponderEndpoint> get endpoints => List.unmodifiable(_endpoints);
}
