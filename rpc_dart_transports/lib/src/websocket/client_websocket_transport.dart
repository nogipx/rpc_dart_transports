// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketChannelProvider = WebSocketChannel Function();

/// Транспорт для обмена сообщениями через WebSocket
class ClientWebSocketTransport implements IRpcTransport {
  /// Идентификатор транспорта
  @override
  final String id;

  @override
  bool get isAvailable => _isAvailable;

  /// URI WebSocket сервера
  final Uri? uri;

  /// Экземпляр WebSocket канала
  WebSocketChannel? _channel;

  /// Контроллер потока входящих сообщений
  final StreamController<Uint8List> _incomingController = StreamController<Uint8List>.broadcast();

  /// Подписка на сообщения WebSocket
  StreamSubscription<dynamic>? _messagesSubscription;

  /// Таймаут операций по умолчанию
  final Duration _defaultTimeout;

  /// Флаг, указывающий на доступность транспорта
  bool _isAvailable = false;

  /// Функция создания WebSocketChannel (может быть заменена для тестирования)
  final WebSocketChannelProvider? _channelProvider;

  /// Создает новый транспорт WebSocket
  ///
  /// [id] - идентификатор транспорта
  /// [uri] - URI WebSocket сервера
  /// [autoConnect] - автоматически подключаться при создании
  /// [timeout] - таймаут для операций (по умолчанию 30 секунд)
  ClientWebSocketTransport._({
    required this.id,
    this.uri,
    bool autoConnect = false,
    Duration timeout = const Duration(seconds: 30),
    WebSocketChannelProvider? channelProvider,
  })  : _defaultTimeout = timeout,
        _channelProvider = channelProvider,
        assert(uri != null || channelProvider != null, 'uri or channelProvider must be provided') {
    if (autoConnect) {
      connect();
    }
  }

  factory ClientWebSocketTransport.fromUrl({
    required String id,
    required String url,
    bool autoConnect = false,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return ClientWebSocketTransport._(
      id: id,
      autoConnect: autoConnect,
      timeout: timeout,
      uri: Uri.parse(url),
    );
  }

  /// Создает новый транспорт WebSocket из строкового URL
  ///
  /// [id] - идентификатор транспорта
  /// [url] - URL WebSocket сервера в строковом формате
  /// [autoConnect] - автоматически подключаться при создании
  /// [timeout] - таймаут для операций (по умолчанию 30 секунд)
  factory ClientWebSocketTransport.customChannel({
    required String id,
    bool autoConnect = true,
    Duration timeout = const Duration(seconds: 30),
    WebSocketChannelProvider? channelProvider,
  }) {
    return ClientWebSocketTransport._(
      id: id,
      autoConnect: autoConnect,
      timeout: timeout,
      channelProvider: channelProvider,
    );
  }

  /// Подключается к WebSocket серверу
  ///
  /// Возвращает Future, который завершается, когда соединение установлено
  Future<RpcTransportActionStatus> connect() async {
    if (_isAvailable) return RpcTransportActionStatus.success;

    try {
      if (uri != null) {
        _channel = WebSocketChannel.connect(uri!);
      } else if (_channelProvider != null) {
        _channel = _channelProvider!();
      }

      await _channel?.ready.timeout(const Duration(seconds: 30));

      if (_channel == null) {
        throw Exception('Ошибка при создании WebSocketChannel');
      }

      // Слушаем входящие сообщения
      _messagesSubscription = _channel!.stream.listen(
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
        onDone: () {
          _isAvailable = false;
          if (!_incomingController.isClosed) {
            _incomingController.close();
          }
        },
      );

      _isAvailable = true;
      return RpcTransportActionStatus.success;
    } catch (e) {
      _isAvailable = false;
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  Stream<Uint8List> receive() {
    return _incomingController.stream;
  }

  @override
  Future<RpcTransportActionStatus> send(Uint8List data, {Duration? timeout}) async {
    if (!isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    final effectiveTimeout = timeout ?? _defaultTimeout;

    // Используем WebSocketChannel
    final channel = _channel;
    if (channel == null) {
      return RpcTransportActionStatus.connectionNotEstablished;
    }

    try {
      await Future.delayed(Duration.zero, () => channel.sink.add(data)).timeout(
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

      // Закрываем соединение
      _channel?.sink.close();
      _channel = null;

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
