import 'dart:io';

/// Простая реализация сервера, который принимает WebSocket соединения
class EchoWebSocketServer {
  final List<WebSocket> _connections = [];
  HttpServer? _server;
  int? _port;

  /// URL для подключения клиентов
  String get wsUrl => 'ws://localhost:$_port';

  /// Запускает сервер на случайном порту
  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;

    print('Тестовый WebSocket сервер запущен на порту $_port');

    _server!.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _connections.add(socket);

        socket.listen(
          (data) {
            socket.add(data);
          },
          onDone: () {
            _connections.remove(socket);
            print('WebSocket соединение закрыто');
          },
          onError: (error) {
            _connections.remove(socket);
            print('Ошибка WebSocket: $error');
          },
        );
      }
    });
  }

  /// Останавливает сервер
  Future<void> stop() async {
    for (final conn in _connections) {
      await conn.close();
    }
    _connections.clear();

    await _server?.close();
    _server = null;
    _port = null;

    print('Тестовый WebSocket сервер остановлен');
  }
}
