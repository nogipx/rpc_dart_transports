// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'rpc_http2_caller_transport.dart';

/// Высокоуровневый HTTP/2 RPC клиент
///
/// Упрощает создание и управление HTTP/2 RPC соединениями.
/// Автоматически управляет транспортом и endpoint'ом.
class RpcHttp2Client {
  final String _host;
  final int _port;
  final bool _secure;
  final RpcLogger? _logger;

  RpcHttp2CallerTransport? _transport;
  RpcCallerEndpoint? _callerEndpoint;
  bool _isConnected = false;

  /// Создает HTTP/2 клиент
  ///
  /// [host] - хост сервера
  /// [port] - порт сервера
  /// [secure] - использовать HTTPS/TLS (по умолчанию false)
  /// [logger] - логгер для отладки
  RpcHttp2Client({
    required String host,
    required int port,
    bool secure = false,
    RpcLogger? logger,
  })  : _host = host,
        _port = port,
        _secure = secure,
        _logger = logger?.child('Http2Client');

  /// Подключается к HTTP/2 серверу
  Future<void> connect() async {
    if (_isConnected) {
      throw StateError('HTTP/2 клиент уже подключен');
    }

    _logger?.info('Подключение к HTTP/2 серверу $_host:$_port (secure: $_secure)');

    try {
      // Создаем HTTP/2 транспорт
      _transport = await RpcHttp2CallerTransport.connect(
        host: _host,
        port: _port,
        logger: _logger?.child('Transport'),
      );

      // Создаем caller endpoint
      _callerEndpoint = RpcCallerEndpoint(
        transport: _transport!,
        debugLabel: 'Http2Client($_host:$_port)',
      );

      _isConnected = true;
      _logger?.info('Подключение к HTTP/2 серверу установлено');
    } catch (e, stackTrace) {
      _logger?.error('Ошибка подключения к HTTP/2 серверу: $e', error: e, stackTrace: stackTrace);
      await disconnect();
      rethrow;
    }
  }

  /// Отключается от HTTP/2 сервера
  Future<void> disconnect() async {
    if (!_isConnected) return;

    _logger?.info('Отключение от HTTP/2 сервера...');

    _isConnected = false;

    // Закрываем транспорт
    if (_transport != null) {
      await _transport!.close();
      _transport = null;
    }

    _callerEndpoint = null;

    _logger?.info('Отключение от HTTP/2 сервера завершено');
  }

  /// Получает caller endpoint для выполнения RPC вызовов
  RpcCallerEndpoint get endpoint {
    if (!_isConnected || _callerEndpoint == null) {
      throw StateError('HTTP/2 клиент не подключен. Вызовите connect()');
    }
    return _callerEndpoint!;
  }

  /// Проверяет, подключен ли клиент
  bool get isConnected => _isConnected;

  /// Получает хост сервера
  String get host => _host;

  /// Получает порт сервера
  int get port => _port;

  /// Использует ли HTTPS/TLS
  bool get isSecure => _secure;

  /// Выполняет unary RPC вызов
  Future<TResponse>
      unaryCall<TRequest extends IRpcSerializable, TResponse extends IRpcSerializable>({
    required String serviceName,
    required String methodName,
    required RpcCodec<TRequest> requestCodec,
    required RpcCodec<TResponse> responseCodec,
    required TRequest request,
  }) async {
    return endpoint.unaryRequest<TRequest, TResponse>(
      serviceName: serviceName,
      methodName: methodName,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
      request: request,
    );
  }

  /// Выполняет server streaming RPC вызов
  Stream<TResponse>
      serverStreamCall<TRequest extends IRpcSerializable, TResponse extends IRpcSerializable>({
    required String serviceName,
    required String methodName,
    required RpcCodec<TRequest> requestCodec,
    required RpcCodec<TResponse> responseCodec,
    required TRequest request,
  }) {
    return endpoint.serverStream<TRequest, TResponse>(
      serviceName: serviceName,
      methodName: methodName,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
      request: request,
    );
  }

  /// Создает функцию для client streaming RPC вызова
  Future<TResponse> Function(Stream<TRequest> requests)
      clientStreamCall<TRequest extends IRpcSerializable, TResponse extends IRpcSerializable>({
    required String serviceName,
    required String methodName,
    required RpcCodec<TRequest> requestCodec,
    required RpcCodec<TResponse> responseCodec,
  }) {
    return endpoint.clientStream<TRequest, TResponse>(
      serviceName: serviceName,
      methodName: methodName,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );
  }

  /// Выполняет bidirectional streaming RPC вызов
  Stream<TResponse> bidirectionalStreamCall<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required String serviceName,
    required String methodName,
    required RpcCodec<TRequest> requestCodec,
    required RpcCodec<TResponse> responseCodec,
    required Stream<TRequest> requests,
  }) {
    return endpoint.bidirectionalStream<TRequest, TResponse>(
      serviceName: serviceName,
      methodName: methodName,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
      requests: requests,
    );
  }
}
