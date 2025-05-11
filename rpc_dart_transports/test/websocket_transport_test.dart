import 'dart:async';
import 'dart:typed_data';

import 'package:rpc_dart/rpc_dart.dart' show RpcTransportActionStatus;
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:test/test.dart';

import 'echo_websocket_server.dart';

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
    // Используем новый фабричный метод для создания транспорта из URL
    final clientTransport = WebSocketTransport.fromUrl(
      'client',
      testServer.wsUrl,
      autoConnect: true,
    );

    // Ждем пока транспорт будет доступен
    final completer = Completer<void>();
    Timer(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;

    expect(clientTransport.isAvailable, isTrue,
        reason: 'Транспорт должен быть доступен после подключения');

    // Отправляем и получаем тестовое сообщение
    final responseCompleter = Completer<Uint8List>();
    final subscription = clientTransport.receive().listen((data) {
      if (!responseCompleter.isCompleted) {
        responseCompleter.complete(data);
      }
    });

    // Отправляем тестовые данные
    final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
    final result = await clientTransport.send(testData);

    expect(result, equals(RpcTransportActionStatus.success),
        reason: 'Отправка данных должна быть успешной');

    // Получаем эхо от сервера
    final response =
        await responseCompleter.future.timeout(const Duration(seconds: 5));

    // Проверяем, что получили те же данные
    expect(response, equals(testData),
        reason: 'Полученные данные должны соответствовать отправленным');

    await subscription.cancel();
    await clientTransport.close();
  });

  test('Создание транспорта с URI', () async {
    final uri = Uri.parse(testServer.wsUrl);
    final clientTransport = WebSocketTransport(
      'client',
      uri,
      autoConnect: true,
    );

    // Ждем пока транспорт будет доступен
    final completer = Completer<void>();
    Timer(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;

    expect(clientTransport.isAvailable, isTrue,
        reason: 'Транспорт должен быть доступен после подключения');

    await clientTransport.close();
  });
}
