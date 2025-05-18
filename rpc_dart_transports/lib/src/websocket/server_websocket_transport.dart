// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:rpc_dart/rpc_dart.dart';

/// Транспорт на основе WebSocket для серверной стороны
///
/// Позволяет настроить WebSocket сервер, автоматически обрабатывать
/// подключения клиентов и маршрутизировать сообщения между ними.
class ServerWebSocketTransport implements IRpcTransport {
  /// HTTP сервер для WebSocket соединений
  final HttpServer _server;

  /// Идентификатор транспорта
  @override
  final String id;

  /// Контроллер для исходящих сообщений
  final StreamController<Uint8List> _outgoingController = StreamController<Uint8List>.broadcast();

  /// Контроллер для входящих сообщений
  final StreamController<Uint8List> _incomingController = StreamController<Uint8List>.broadcast();

  /// Активные клиентские соединения, хранятся в словаре по ID клиента
  final Map<String, _ClientConnection> _connections = {};

  /// Функция для генерации ID клиента
  final String Function() _clientIdGenerator;

  /// Обработчик для настройки новых соединений
  final void Function(String clientId, WebSocket socket)? _onClientConnected;

  /// Обработчик для обработки отключений клиентов
  final void Function(String clientId)? _onClientDisconnected;

  /// Признак активности транспорта
  bool _isActive = false;

  /// Проверяет, активен ли транспорт
  @override
  bool get isAvailable => _isActive;

  /// Создает новый WebSocket транспорт для сервера
  ///
  /// [server] - уже созданный и запущенный HTTP сервер
  /// [id] - уникальный идентификатор транспорта
  /// [clientIdGenerator] - функция для генерации ID новых клиентов
  /// [onClientConnected] - обработчик для новых соединений
  /// [onClientDisconnected] - обработчик для отключений клиентов
  ServerWebSocketTransport({
    required HttpServer server,
    required this.id,
    String Function()? clientIdGenerator,
    void Function(String clientId, WebSocket socket)? onClientConnected,
    void Function(String clientId)? onClientDisconnected,
  })  : _server = server,
        _clientIdGenerator = clientIdGenerator ?? _defaultClientIdGenerator,
        _onClientConnected = onClientConnected,
        _onClientDisconnected = onClientDisconnected {
    _initialize();
  }

  /// Создает новый WebSocket транспорт и HTTP сервер
  ///
  /// [host] - хост для HTTP сервера (по умолчанию 'localhost')
  /// [port] - порт для HTTP сервера
  /// [id] - уникальный идентификатор транспорта
  /// [clientIdGenerator] - функция для генерации ID новых клиентов
  /// [onClientConnected] - обработчик для новых соединений
  /// [onClientDisconnected] - обработчик для отключений клиентов
  static Future<ServerWebSocketTransport> create({
    required String host,
    required int port,
    required String id,
    String Function()? clientIdGenerator,
    void Function(String clientId, WebSocket socket)? onClientConnected,
    void Function(String clientId)? onClientDisconnected,
  }) async {
    final server = await HttpServer.bind(host, port);
    return ServerWebSocketTransport(
      server: server,
      id: id,
      clientIdGenerator: clientIdGenerator,
      onClientConnected: onClientConnected,
      onClientDisconnected: onClientDisconnected,
    );
  }

  /// Инициализирует транспорт и начинает обработку соединений
  void _initialize() {
    _isActive = true;

    // Настраиваем обработку HTTP запросов
    _server.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          // Преобразуем HTTP запрос в WebSocket
          final socket = await WebSocketTransformer.upgrade(request);

          // Генерируем ID для нового клиента
          final clientId = _clientIdGenerator();

          // Создаем и сохраняем соединение
          final connection = _ClientConnection(
            socket: socket,
            id: clientId,
          );
          _connections[clientId] = connection;

          // Вызываем обработчик подключения, если он указан
          _onClientConnected?.call(clientId, socket);

          // Настраиваем прослушивание данных от клиента
          socket.listen(
            (data) {
              if (data is List<int>) {
                final bytes = Uint8List.fromList(data);
                _incomingController.add(bytes);
              }
            },
            onDone: () {
              // Удаляем соединение при закрытии
              _connections.remove(clientId);
              _onClientDisconnected?.call(clientId);
            },
            onError: (error) {
              // Логируем ошибки и удаляем соединение
              print('Ошибка в соединении $clientId: $error');
              _connections.remove(clientId);
              _onClientDisconnected?.call(clientId);
            },
          );
        } catch (e) {
          print('Ошибка при обработке WebSocket подключения: $e');
        }
      } else {
        // Отвечаем на обычные HTTP запросы
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write(
            '<html><body><h1>RPC WebSocket Server</h1><p>This is a WebSocket server. Connect using a WebSocket client.</p></body></html>');
        await request.response.close();
      }
    });

    // Настраиваем отправку исходящих сообщений
    _outgoingController.stream.listen((data) {
      // Отправляем данные всем подключенным клиентам
      for (final connection in _connections.values) {
        try {
          connection.socket.add(data);
        } catch (e) {
          print('Ошибка при отправке данных клиенту ${connection.id}: $e');
        }
      }
    });
  }

  /// Отправляет сообщение всем подключенным клиентам
  @override
  Future<RpcTransportActionStatus> send(Uint8List data, {Duration? timeout}) async {
    if (!_isActive) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    try {
      _outgoingController.add(data);
      return RpcTransportActionStatus.success;
    } catch (e) {
      print('Ошибка при отправке данных: $e');
      return RpcTransportActionStatus.unknownError;
    }
  }

  /// Отправляет сообщение конкретному клиенту по ID
  Future<RpcTransportActionStatus> sendToClient(String clientId, Uint8List data) async {
    if (!_isActive) {
      return RpcTransportActionStatus.transportUnavailable;
    }

    if (!_connections.containsKey(clientId)) {
      return RpcTransportActionStatus.connectionNotEstablished;
    }

    try {
      _connections[clientId]!.socket.add(data);
      return RpcTransportActionStatus.success;
    } catch (e) {
      print('Ошибка при отправке данных клиенту $clientId: $e');
      return RpcTransportActionStatus.unknownError;
    }
  }

  /// Получает поток входящих сообщений
  @override
  Stream<Uint8List> receive() {
    return _incomingController.stream;
  }

  /// Возвращает список ID подключенных клиентов
  List<String> getConnectedClientIds() {
    return _connections.keys.toList();
  }

  /// Закрывает транспорт и освобождает ресурсы
  @override
  Future<RpcTransportActionStatus> close() async {
    if (!_isActive) return RpcTransportActionStatus.success;

    _isActive = false;

    try {
      // Закрываем все клиентские соединения
      for (final connection in _connections.values) {
        try {
          await connection.socket.close();
        } catch (e) {
          print('Ошибка при закрытии соединения ${connection.id}: $e');
        }
      }
      _connections.clear();

      // Закрываем HTTP сервер
      await _server.close(force: true);

      // Закрываем стримы
      await _outgoingController.close();
      await _incomingController.close();

      return RpcTransportActionStatus.success;
    } catch (e) {
      print('Ошибка при закрытии транспорта: $e');
      return RpcTransportActionStatus.unknownError;
    }
  }

  /// Функция по умолчанию для генерации ID клиентов
  static String _defaultClientIdGenerator() {
    return 'client_${DateTime.now().millisecondsSinceEpoch}_${_randomId()}';
  }

  /// Генерирует случайный идентификатор
  static String _randomId() {
    return (DateTime.now().microsecondsSinceEpoch % 10000).toString();
  }
}

/// Класс для хранения информации о клиентском соединении
class _ClientConnection {
  /// WebSocket соединение
  final WebSocket socket;

  /// Идентификатор клиента
  final String id;

  /// Создает новое клиентское соединение
  _ClientConnection({
    required this.socket,
    required this.id,
  });
}
