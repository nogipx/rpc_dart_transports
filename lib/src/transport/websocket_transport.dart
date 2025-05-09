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

  /// Флаг, указывающий на доступность транспорта
  bool _isAvailable = false;

  /// Создает новый транспорт WebSocket
  ///
  /// [id] - идентификатор транспорта
  /// [url] - URL WebSocket сервера
  /// [autoConnect] - автоматически подключаться при создании
  WebSocketTransport(this.id, this.url, {bool autoConnect = false}) {
    if (autoConnect) {
      connect();
    }
  }

  /// Создает транспорт из существующего WebSocket соединения
  ///
  /// [id] - идентификатор транспорта
  /// [webSocket] - уже установленное WebSocket соединение
  WebSocketTransport.fromWebSocket(this.id, WebSocket webSocket)
      : url = null,
        _webSocket = webSocket {
    // Сразу подключаемся
    _isAvailable = true;

    // Подписываемся на входящие сообщения
    _webSocket!.listen(
      (dynamic data) {
        if (data is String) {
          // Если получили строку, преобразуем в Uint8List
          final bytes = Uint8List.fromList(utf8.encode(data));
          _incomingController.add(bytes);
        } else if (data is List<int>) {
          // Если получили список байтов, преобразуем в Uint8List
          _incomingController.add(Uint8List.fromList(data));
        }
      },
      onError: (error) {
        _isAvailable = false;
        _incomingController.addError(error);
      },
      onDone: () {
        _isAvailable = false;
        _webSocket = null;
      },
    );
  }

  /// Подключается к WebSocket серверу
  ///
  /// Возвращает Future, который завершается, когда соединение установлено
  Future<void> connect() async {
    if (_isAvailable) return;
    if (url == null) throw StateError('URL не указан для подключения');

    try {
      _webSocket = await WebSocket.connect(url!);
      _isAvailable = true;

      // Подписываемся на входящие сообщения
      _webSocket!.listen(
        (dynamic data) {
          if (data is String) {
            // Если получили строку, преобразуем в Uint8List
            final bytes = Uint8List.fromList(utf8.encode(data));
            _incomingController.add(bytes);
          } else if (data is List<int>) {
            // Если получили список байтов, преобразуем в Uint8List
            _incomingController.add(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          _isAvailable = false;
          _incomingController.addError(error);
        },
        onDone: () {
          _isAvailable = false;
          _webSocket = null;
        },
      );
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
  Future<RpcTransportActionStatus> send(Uint8List data) async {
    if (!_isAvailable) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    try {
      if (_webSocket != null) {
        if (_webSocket!.readyState == WebSocket.open) {
          _webSocket!.add(data);
          return RpcTransportActionStatus.success;
        } else {
          _isAvailable = false;
          return RpcTransportActionStatus.connectionClosed;
        }
      } else {
        return RpcTransportActionStatus.connectionNotEstablished;
      }
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
      if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
        await _webSocket!.close();
        _webSocket = null;
      }

      // Закрываем контроллер, если он не закрыт
      if (!_incomingController.isClosed) {
        await _incomingController.close();
      }

      return RpcTransportActionStatus.success;
    } catch (e) {
      print('Ошибка при закрытии WebSocket соединения: $e');
      return RpcTransportActionStatus.unknownError;
    }
  }
}
