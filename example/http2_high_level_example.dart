// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart_transports/rpc_dart_transports.dart';

/// 🚀 Демонстрация высокоуровневых HTTP/2 классов
///
/// Показывает как RpcHttp2Server и RpcHttp2Client взаимодействуют с транспортами
Future<void> main() async {
  RpcLogger.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  print('🚀 === ВЫСОКОУРОВНЕВЫЕ HTTP/2 КЛАССЫ === 🚀\n');
  print('📊 Архитектура взаимодействия с транспортами:\n');

  const port = 8080;

  // === СОЗДАЕМ HTTP/2 СЕРВЕР ===
  print('🏗️  1. Создание RpcHttp2Server (высокоуровневый)');

  final server = RpcHttp2Server(
    port: port,
    logger: RpcLogger('Server'),
    onEndpointCreated: (endpoint) {
      print('   ⚡ Новый RPC endpoint создан!');
      print('   🔌 Транспорт: ${endpoint.transport.runtimeType}');

      // Регистрируем демо-сервис на каждый endpoint
      final contract = DemoServiceContract();
      endpoint.registerServiceContract(contract);
      print('   📋 Зарегистрирован DemoService');
    },
    onConnectionError: (error, stack) {
      print('   ❌ Ошибка соединения: $error');
    },
  );

  try {
    // Запускаем сервер
    await server.start();
    print('   ✅ Сервер запущен на порту $port');
    print('   📈 Активных соединений: ${server.activeConnections}');

    print('\n' + '=' * 60);
    print('📱 АРХИТЕКТУРА СЕРВЕРНОЙ СТОРОНЫ:');
    print('┌─ RpcHttp2Server ────────────────────────────┐');
    print('│  • Принимает TCP соединения                 │');
    print('│  • Создает http2.ServerTransportConnection  │');
    print('└─────────────────────────────────────────────┘');
    print('                    │');
    print('                    ▼');
    print('┌─ RpcHttp2ResponderTransport ───────────────┐');
    print('│  • HTTP/2 протокол (низкий уровень)        │');
    print('│  • Парсинг gRPC сообщений                  │');
    print('│  • Управление streams                      │');
    print('└─────────────────────────────────────────────┘');
    print('                    │');
    print('                    ▼');
    print('┌─ RpcResponderEndpoint ─────────────────────┐');
    print('│  • Обработка RPC вызовов                   │');
    print('│  • Выполнение контрактов                   │');
    print('│  • Маршрутизация методов                   │');
    print('└─────────────────────────────────────────────┘');
    print('=' * 60);

    // Даем серверу время на запуск
    await Future.delayed(Duration(milliseconds: 500));

    // === СОЗДАЕМ HTTP/2 КЛИЕНТА ===
    print('\n🔌 2. Создание RpcHttp2Client (высокоуровневый)');

    final client = RpcHttp2Client(
      host: 'localhost',
      port: port,
      logger: RpcLogger('Client'),
    );

    try {
      // Подключаемся к серверу
      await client.connect();
      print('   ✅ Клиент подключен к серверу');
      print('   🔗 Endpoint: ${client.endpoint.runtimeType}');

      print('\n' + '=' * 60);
      print('📱 АРХИТЕКТУРА КЛИЕНТСКОЙ СТОРОНЫ:');
      print('┌─ RpcHttp2Client ───────────────────────────┐');
      print('│  • Подключение к HTTP/2 серверу            │');
      print('│  • Создает http2.ClientTransportConnection │');
      print('└─────────────────────────────────────────────┘');
      print('                    │');
      print('                    ▼');
      print('┌─ RpcHttp2CallerTransport ──────────────────┐');
      print('│  • HTTP/2 протокол (низкий уровень)        │');
      print('│  • Сериализация gRPC сообщений             │');
      print('│  • Управление streams                      │');
      print('└─────────────────────────────────────────────┘');
      print('                    │');
      print('                    ▼');
      print('┌─ RpcCallerEndpoint ────────────────────────┐');
      print('│  • Выполнение RPC вызовов                  │');
      print('│  • Типизированные методы                   │');
      print('│  • Управление таймаутами                   │');
      print('└─────────────────────────────────────────────┘');
      print('=' * 60);

      print('\n💡 КЛЮЧЕВОЕ РАЗЛИЧИЕ:');
      print('🏗️  СЕРВЕР: endpoint.registerServiceContract(responder)');
      print('    ↳ "Я ОБРАБАТЫВАЮ эти RPC методы"');
      print('');
      print('📱 КЛИЕНТ: просто создает Caller\'ы');
      print('    ↳ "Я ВЫЗЫВАЮ эти RPC методы"');
      print('    ↳ БЕЗ регистрации контрактов!');

      print('\n📈 Активных соединений на сервере: ${server.activeConnections}');

      // === ДЕМОНСТРИРУЕМ RPC ВЫЗОВЫ ===
      print('\n🎯 3. Демонстрация RPC вызовов через высокоуровневый API');

      // Unary RPC через высокоуровневый API
      print('\n📤 Unary RPC через RpcHttp2Client:');
      final echoResponse = await client.endpoint.unaryRequest<RpcString, RpcString>(
        serviceName: 'DemoService',
        methodName: 'Echo',
        requestCodec: RpcString.codec,
        responseCodec: RpcString.codec,
        request: RpcString('Привет из высокоуровневого клиента!'),
      );
      print('   📨 Ответ: "${echoResponse.value}"');

      // Server Streaming RPC
      print('\n📤 Server Streaming через RpcHttp2Client:');
      final streamResponse = client.endpoint.serverStream<RpcString, RpcString>(
        serviceName: 'DemoService',
        methodName: 'GetStream',
        requestCodec: RpcString.codec,
        responseCodec: RpcString.codec,
        request: RpcString('Дайте поток данных!'),
      );

      await for (final response in streamResponse.take(3)) {
        print('   📨 Стрим: "${response.value}"');
      }

      print('\n✨ === КЛЮЧЕВЫЕ ПРЕИМУЩЕСТВА ВЫСОКОУРОВНЕВЫХ КЛАССОВ === ✨');
      print('🎯 1. Автоматическое управление транспортами');
      print('🎯 2. Простая регистрация RPC сервисов');
      print('🎯 3. Удобные методы для клиентских вызовов');
      print('🎯 4. Автоматическая обработка соединений');
      print('🎯 5. Встроенное логирование и обработка ошибок');
    } finally {
      await client.disconnect();
      print('\n🔌 HTTP/2 клиент отключен');
    }
  } finally {
    await server.stop();
    print('🛑 HTTP/2 сервер остановлен');
  }

  print('\n🎉 Демонстрация завершена!');
}

/// Демонстрационный RPC сервис
final class DemoServiceContract extends RpcResponderContract {
  DemoServiceContract() : super('DemoService');

  @override
  void setup() {
    // Echo метод
    addUnaryMethod<RpcString, RpcString>(
      methodName: 'Echo',
      handler: (request, {context}) async {
        final message = request.value;
        print('   🔄 Echo: получен "$message"');
        return RpcString('Эхо: $message');
      },
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
    );

    // Streaming метод
    addServerStreamMethod<RpcString, RpcString>(
      methodName: 'GetStream',
      handler: (request, {context}) async* {
        final message = request.value;
        print('   🔄 GetStream: запрос "$message"');

        for (int i = 1; i <= 5; i++) {
          await Future.delayed(Duration(milliseconds: 200));
          yield RpcString('Поток #$i: ответ на "$message"');
        }
        print('   🔄 GetStream: завершен');
      },
      requestCodec: RpcString.codec,
      responseCodec: RpcString.codec,
    );
  }
}
