import 'dart:io';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:web_socket_channel/io.dart';

void main() async {
  print('🚀 Запускаем роутер для чата...');

  try {
    // Запускаем WebSocket сервер на порту 8080
    final server = await HttpServer.bind('localhost', 8080);
    print('💬 Роутер запущен на ws://localhost:8080');

    await for (final request in server) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final webSocket = await WebSocketTransformer.upgrade(request);

        // Создаем WebSocket канал и транспорт для сервера
        final channel = IOWebSocketChannel(webSocket);
        final transport = RpcWebSocketResponderTransport(channel);

        // Создаем RPC эндпоинт
        final endpoint = RpcResponderEndpoint(transport: transport);

        // Регистрируем роутер контракт
        final routerContract = RouterResponderContract();
        endpoint.registerServiceContract(routerContract);

        print('✅ Новое подключение: ${request.connectionInfo?.remoteAddress}');
        print('📊 Статистика роутера: ${routerContract.routerImpl.stats}');

        // Мониторинг закрытия соединения
        channel.stream.listen(
          (_) {},
          onDone: () {
            print('❌ Клиент отключился');
            endpoint.stop();
          },
        );
      } else {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('WebSocket connections only')
          ..close();
      }
    }
  } catch (e) {
    print('❌ Ошибка запуска роутера: $e');
    exit(1);
  }
}
