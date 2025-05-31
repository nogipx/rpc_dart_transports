// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// Пример HTTP/2 роутер сервера
///
/// Демонстрирует как запустить транспорт-агностичный роутер с HTTP/2 транспортом.
/// Роутер может одновременно работать с любыми транспортами!
void main() async {
  print('🚀 HTTP/2 Роутер Сервер\n');

  await runHttp2RouterServer();
}

/// Запускает HTTP/2 роутер сервер
Future<void> runHttp2RouterServer() async {
  final logger = RpcLogger('RouterHTTP2Server');

  // Создаем транспорт-агностичный роутер сервер
  final routerServer = RpcRouterServer(
    logger: logger,
  );

  logger.info('Создан транспорт-агностичный RouterServer');

  try {
    // Запускаем HTTP/2 сервер
    final server = await HttpServer.bind('localhost', 8443);
    logger.info('🌐 HTTP/2 сервер запущен на https://localhost:8443');

    print('✅ Роутер готов принимать подключения:');
    print('   • HTTP/2: https://localhost:8443');
    print('   • Транспорт: HTTP/2 gRPC-style');
    print('   • Безопасность: только HTTP (без TLS в примере)\n');

    print('💡 Для тестирования используйте RouterClientHttp2:\n');
    print('```dart');
    print('final client = await RouterClientHttp2.connect(');
    print('  host: "localhost",');
    print('  port: 8443,');
    print(');');
    print('```\n');

    // Обрабатываем входящие HTTP/2 соединения
    await for (final request in server) {
      _handleHttp2Connection(request, routerServer, logger);
    }
  } catch (e, stackTrace) {
    logger.error('Ошибка HTTP/2 сервера: $e', error: e, stackTrace: stackTrace);
  } finally {
    await routerServer.dispose();
    logger.info('Роутер сервер остановлен');
  }
}

/// Обрабатывает HTTP/2 соединение
void _handleHttp2Connection(
  HttpRequest request,
  RpcRouterServer routerServer,
  RpcLogger logger,
) async {
  try {
    final clientAddress = request.connectionInfo?.remoteAddress.toString();

    logger.debug('🔗 Новое HTTP/2 соединение: $clientAddress');

    // На данный момент HTTP/2 транспорт требует ServerTransportConnection
    // Это упрощенный пример - в реальности нужно настроить HTTP/2 соединение
    logger.info('HTTP/2 роутер требует более сложной настройки HTTP/2 соединения');

    // Для демонстрации просто возвращаем 501 Not Implemented
    request.response
      ..statusCode = HttpStatus.notImplemented
      ..write('HTTP/2 router requires proper HTTP/2 connection setup')
      ..close();

    return;

    // Показываем статистику каждые 10 секунд
  } catch (e, stackTrace) {
    logger.error('Ошибка обработки HTTP/2 соединения: $e', error: e, stackTrace: stackTrace);

    // Возвращаем HTTP ошибку
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write('Internal server error')
      ..close();
  }
}
