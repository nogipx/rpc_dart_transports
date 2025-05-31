import 'dart:io';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:web_socket_channel/io.dart';

void main() async {
  print('🚀 Запускаем роутер для чата...');

  try {
    // Запускаем WebSocket сервер на порту 8000 (изменил на тот порт, который используется в клиенте)
    final server = await HttpServer.bind('0.0.0.0', 8000);
    print('💬 Роутер запущен на ws://0.0.0.0:8000');

    // Создаем единый RouterContract для всех соединений
    // Это важно чтобы все клиенты работали с одним роутером
    final routerContract = RouterResponderContract();

    await for (final request in server) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final webSocket = await WebSocketTransformer.upgrade(request);

        // Создаем WebSocket канал и транспорт для сервера
        final channel = IOWebSocketChannel(webSocket);
        final transport = RpcWebSocketResponderTransport(
          channel,
          logger: RpcLogger('ServerTransport'),
        );

        // Создаем RPC эндпоинт для каждого соединения
        final endpoint = RpcResponderEndpoint(transport: transport, debugLabel: 'RouterEndpoint');

        // Регистрируем общий роутер контракт
        endpoint.registerServiceContract(routerContract);

        print('✅ Новое подключение: ${request.connectionInfo?.remoteAddress}');
        print('📊 Статистика роутера: ${routerContract.routerImpl.stats}');

        // Мониторинг закрытия соединения через WebSocket события
        // НЕ делаем channel.stream.listen() - это вызывает ошибку!
        webSocket.done
            .then((_) {
              print('❌ Клиент отключился');
              endpoint.close();
            })
            .catchError((error) {
              print('⚠️ Ошибка при отключении клиента: $error');
              endpoint.close();
            });

        // Запускаем endpoint
        endpoint.start();
      } else {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('WebSocket connections only')
          ..close();
      }
    }
  } catch (e, stackTrace) {
    print('❌ Ошибка запуска роутера: $e');
    print('📍 Stack trace: $stackTrace');
    exit(1);
  }
}
