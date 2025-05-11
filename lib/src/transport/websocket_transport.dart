// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import '_index.dart';

/// Транспорт для обмена сообщениями через WebSocket
class WebSocketTransport implements RpcTransport {
  /// Идентификатор транспорта
  @override
  final String id;

  @override
  bool get isAvailable => _isAvailable;

  /// URL WebSocket сервера
  final String? url;

  /// WebSocket соединение
  WebSocket? _webSocket;

  /// Контроллер потока входящих сообщений
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();

  /// Подписка на WebSocket
  StreamSubscription<dynamic>? _webSocketSubscription;

  /// Флаг, указывающий на доступность транспорта
  bool _isAvailable = false;

  /// Таймаут операций по умолчанию
  final Duration _defaultTimeout;

  /// Создает новый транспорт WebSocket
  ///
  /// [id] - идентификатор транспорта
  /// [url] - URL WebSocket сервера
  /// [autoConnect] - автоматически подключаться при создании
  /// [timeout] - таймаут для операций (по умолчанию 30 секунд)
  WebSocketTransport(
    this.id,
    this.url, {
    bool autoConnect = false,
    Duration timeout = const Duration(seconds: 30),
  }) : _defaultTimeout = timeout {
    if (autoConnect) {
      connect();
    }
  }

  /// Создает транспорт из существующего WebSocket соединения
  ///
  /// [id] - идентификатор транспорта
  /// [webSocket] - уже установленное WebSocket соединение
  /// [timeout] - таймаут для операций (по умолчанию 30 секунд)
  WebSocketTransport.fromWebSocket(
    this.id,
    WebSocket webSocket, {
    Duration timeout = const Duration(seconds: 30),
  })  : url = null,
        _webSocket = webSocket,
        _defaultTimeout = timeout {
    // Сразу подключаемся
    _isAvailable = true;

    // Используем общий метод для настройки слушателя
    _setupWebSocketListener(webSocket);
  }

  /// Настраивает слушателя для WebSocket соединения
  void _setupWebSocketListener(WebSocket socket) {
    // Отписываемся от предыдущей подписки, если она существует
    _webSocketSubscription?.cancel();

    // Создаем новую подписку
    _webSocketSubscription = socket.listen(
      (dynamic data) {
        if (data is String) {
          // Если получили строку, преобразуем в Uint8List
          final bytes = Uint8List.fromList(utf8.encode(data));
          if (!_incomingController.isClosed) {
            _incomingController.add(bytes);
          }
        } else if (data is List<int>) {
          // Если получили список байтов, преобразуем в Uint8List
          if (!_incomingController.isClosed) {
            _incomingController.add(Uint8List.fromList(data));
          }
        }
      },
      onError: (error) {
        _isAvailable = false;
        if (!_incomingController.isClosed) {
          _incomingController.addError(error);
        }
      },
      onDone: () {
        _isAvailable = false;
        _webSocket = null;
        // Не закрываем контроллер здесь, это будет сделано в методе close()
      },
    );
  }

  /// Подключается к WebSocket серверу
  ///
  /// Возвращает Future, который завершается, когда соединение установлено
  /// Если соединение не может быть установлено в течение [timeout], выбрасывается исключение
  Future<void> connect({Duration? timeout}) async {
    if (_isAvailable) return;
    if (url == null) throw StateError('URL не указан для подключения');

    final effectiveTimeout = timeout ?? _defaultTimeout;

    try {
      // Устанавливаем таймаут на операцию подключения
      _webSocket = await WebSocket.connect(url!).timeout(
        effectiveTimeout,
        onTimeout: () => throw TimeoutException(
          'Истекло время ожидания подключения к WebSocket',
          effectiveTimeout,
        ),
      );

      _isAvailable = true;

      // Используем общий метод для настройки слушателя
      _setupWebSocketListener(_webSocket!);
    } on TimeoutException catch (e) {
      _isAvailable = false;
      throw Exception('Время подключения к WebSocket истекло: $e');
    } catch (e) {
      _isAvailable = false;
      throw Exception('Не удалось подключиться к WebSocket серверу: $e');
    }
  }

  @override
  Stream<Uint8List> receive() {
    return _incomingController.stream;
  }

  @override
  Future<RpcTransportActionStatus> send(Uint8List data,
      {Duration? timeout}) async {
    if (!_isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    final effectiveTimeout = timeout ?? _defaultTimeout;

    try {
      final socket = _webSocket;
      if (socket == null) {
        return RpcTransportActionStatus.connectionNotEstablished;
      }

      if (socket.readyState == WebSocket.open) {
        // Добавляем таймаут на операцию отправки
        await Future.delayed(Duration.zero, () => socket.add(data)).timeout(
          effectiveTimeout,
          onTimeout: () => throw TimeoutException(
            'Истекло время ожидания отправки данных',
            effectiveTimeout,
          ),
        );
        return RpcTransportActionStatus.success;
      } else {
        _isAvailable = false;
        return RpcTransportActionStatus.connectionClosed;
      }
    } on TimeoutException {
      return RpcTransportActionStatus.timeoutError;
    } catch (e) {
      _isAvailable = false;
      return RpcTransportActionStatus.unknownError;
    }
  }

  @override
  Future<RpcTransportActionStatus> close() async {
    // Сначала меняем флаг доступности, чтобы предотвратить новые отправки
    _isAvailable = false;

    try {
      // Отменяем подписку на WebSocket
      await _webSocketSubscription?.cancel();
      _webSocketSubscription = null;

      // Закрываем WebSocket, если он открыт
      final socket = _webSocket;
      if (socket != null && socket.readyState == WebSocket.open) {
        await socket.close();
      }
      _webSocket = null;

      // Закрываем контроллер, если он не закрыт
      if (!_incomingController.isClosed) {
        await _incomingController.close();
      }

      return RpcTransportActionStatus.success;
    } catch (e) {
      // Используем более структурированное логирование ошибок
      Zone.current.handleUncaughtError(
        Exception('Ошибка при закрытии WebSocket: $e'),
        StackTrace.current,
      );
      return RpcTransportActionStatus.unknownError;
    }
  }
}
