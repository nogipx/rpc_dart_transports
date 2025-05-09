import 'dart:async';
import 'dart:typed_data';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

import '../fixtures/echo_websocket_server.dart';

/// Интеграционные тесты для WebSocket транспорта
void main() {
  late EchoWebSocketServer testServer;

  setUp(() async {
    testServer = EchoWebSocketServer();
    await testServer.start();
  });

  tearDown(() async {
    await testServer.stop();
  });

  test('Базовый тест подключения к WebSocket', () async {
    final clientTransport = WebSocketTransport('client', testServer.wsUrl);
    await clientTransport.connect();

    expect(clientTransport.isAvailable, isTrue);

    // Отправляем и получаем тестовое сообщение
    final completer = Completer<Uint8List>();
    final subscription = clientTransport.receive().listen((data) {
      completer.complete(data);
    });

    // Отправляем тестовые данные
    final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
    await clientTransport.send(testData);

    // Получаем эхо от сервера
    final response = await completer.future.timeout(Duration(seconds: 5));

    // Проверяем, что получили те же данные
    expect(response, equals(testData));

    await subscription.cancel();
    await clientTransport.close();
  });
}
