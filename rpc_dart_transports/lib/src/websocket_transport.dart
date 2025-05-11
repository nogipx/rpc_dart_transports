// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:web_socket_client/web_socket_client.dart';

/// Транспорт для обмена сообщениями через WebSocket с использованием web_socket_client
class WebSocketTransport implements RpcTransport {
  /// Идентификатор транспорта
  @override
  final String id;

  @override
  bool get isAvailable => _isAvailable;

  /// URI WebSocket сервера
  final Uri uri;

  /// Опции для WebSocket соединения
  final Duration? connectionTimeout;
  final Backoff? backoff;
  final String? binaryType;

  /// Экземпляр WebSocket клиента
  WebSocket? _socket;

  /// Контроллер потока входящих сообщений
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();

  /// Подписка на сообщения WebSocket
  StreamSubscription<dynamic>? _messagesSubscription;

  /// Подписка на состояние WebSocket соединения
  StreamSubscription<dynamic>? _connectionSubscription;

  /// Таймаут операций по умолчанию
  final Duration _defaultTimeout;

  /// Флаг, указывающий на доступность транспорта
  bool _isAvailable = false;

  /// Создает новый транспорт WebSocket
  ///
  /// [id] - идентификатор транспорта
  /// [uri] - URI WebSocket сервера
  /// [autoConnect] - автоматически подключаться при создании
  /// [timeout] - таймаут для операций (по умолчанию 30 секунд)
  /// [connectionTimeout] - таймаут для установки соединения
  /// [backoff] - стратегия повторных попыток соединения
  /// [binaryType] - тип бинарных данных ('blob' или 'arraybuffer')
  WebSocketTransport(
    this.id,
    this.uri, {
    bool autoConnect = true,
    Duration timeout = const Duration(seconds: 30),
    this.connectionTimeout,
    this.backoff,
    this.binaryType,
  }) : _defaultTimeout = timeout {
    if (autoConnect) {
      connect();
    }
  }

  /// Создает новый транспорт WebSocket из строкового URL
  ///
  /// [id] - идентификатор транспорта
  /// [url] - URL WebSocket сервера в строковом формате
  /// [autoConnect] - автоматически подключаться при создании
  /// [timeout] - таймаут для операций (по умолчанию 30 секунд)
  /// [connectionTimeout] - таймаут для установки соединения
  /// [backoff] - стратегия повторных попыток соединения
  /// [binaryType] - тип бинарных данных ('blob' или 'arraybuffer')
  factory WebSocketTransport.fromUrl(
    String id,
    String url, {
    bool autoConnect = true,
    Duration timeout = const Duration(seconds: 30),
    Duration? connectionTimeout,
    Backoff? backoff,
    String? binaryType,
  }) {
    return WebSocketTransport(
      id,
      Uri.parse(url),
      autoConnect: autoConnect,
      timeout: timeout,
      connectionTimeout: connectionTimeout,
      backoff: backoff,
      binaryType: binaryType,
    );
  }

  /// Подключается к WebSocket серверу
  ///
  /// Возвращает Future, который завершается, когда соединение установлено
  Future<void> connect() async {
    if (_isAvailable) return;

    try {
      // Создаем новый экземпляр WebSocket
      _socket = WebSocket(
        uri,
        timeout: connectionTimeout,
        backoff: backoff,
        binaryType: binaryType,
      );

      // Слушаем изменения состояния соединения
      _connectionSubscription = _socket!.connection.listen((state) {
        if (state is Connected || state is Reconnected) {
          _isAvailable = true;
        } else if (state is Disconnected) {
          _isAvailable = false;
        }
      });

      // Слушаем входящие сообщения
      _messagesSubscription = _socket!.messages.listen(
        (dynamic data) {
          if (!_incomingController.isClosed) {
            if (data is String) {
              // Если пришли строковые данные, конвертируем в Uint8List
              final bytes = Uint8List.fromList(utf8.encode(data));
              _incomingController.add(bytes);
            } else if (data is List<int>) {
              // Если пришли бинарные данные
              _incomingController.add(Uint8List.fromList(data));
            }
          }
        },
        onError: (error) {
          if (!_incomingController.isClosed) {
            _incomingController.addError(error);
          }
        },
      );

      // Ждем пока соединение установится
      final connectionState = await _socket!.connection
          .firstWhere((state) =>
              state is Connected ||
              state is Reconnected ||
              state is Disconnected)
          .timeout(connectionTimeout ?? _defaultTimeout);

      if (connectionState is Disconnected) {
        throw Exception(
            'Не удалось установить соединение: ${connectionState.error}');
      }

      _isAvailable = true;
    } catch (e) {
      _isAvailable = false;
      throw Exception('Ошибка при подключении к WebSocket: $e');
    }
  }

  @override
  Stream<Uint8List> receive() {
    return _incomingController.stream;
  }

  @override
  Future<RpcTransportActionStatus> send(Uint8List data,
      {Duration? timeout}) async {
    if (!isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    final effectiveTimeout = timeout ?? _defaultTimeout;
    final socket = _socket;

    if (socket == null) {
      return RpcTransportActionStatus.connectionNotEstablished;
    }

    try {
      // Проверяем текущее состояние соединения
      final currentState = socket.connection.state;
      if (currentState is! Connected && currentState is! Reconnected) {
        return RpcTransportActionStatus.connectionClosed;
      }

      await Future.delayed(Duration.zero, () => socket.send(data)).timeout(
        effectiveTimeout,
        onTimeout: () => throw TimeoutException(
          'Истекло время ожидания отправки данных',
          effectiveTimeout,
        ),
      );

      return RpcTransportActionStatus.success;
    } on TimeoutException {
      return RpcTransportActionStatus.timeoutError;
    } catch (e) {
      Zone.current.handleUncaughtError(
        Exception('Ошибка при отправке данных через WebSocket: $e'),
        StackTrace.current,
      );
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  Future<RpcTransportActionStatus> close() async {
    _isAvailable = false;

    try {
      // Отменяем подписки
      await _messagesSubscription?.cancel();
      _messagesSubscription = null;

      await _connectionSubscription?.cancel();
      _connectionSubscription = null;

      // Закрываем соединение
      _socket?.close();
      _socket = null;

      // Закрываем контроллер
      if (!_incomingController.isClosed) {
        await _incomingController.close();
      }

      return RpcTransportActionStatus.success;
    } catch (e) {
      Zone.current.handleUncaughtError(
        Exception('Ошибка при закрытии WebSocket транспорта: $e'),
        StackTrace.current,
      );
      return RpcTransportActionStatus.unknownError;
    }
  }
}
