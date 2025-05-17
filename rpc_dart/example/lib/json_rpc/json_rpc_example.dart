// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

/// Константа с источником логов
const String _source = 'JsonRpcExample';

/// Пример использования JSON-RPC транспорта для унарных методов
Future<void> main() async {
  printHeader('JSON-RPC example');

  // Создаем память и базовый транспорт (в реальном приложении это бы был HTTP/WebSocket)
  final transport1 = MemoryTransport('transport1');
  final transport2 = MemoryTransport('transport2');

  // Соединяем транспорты
  transport1.connect(transport2);
  transport2.connect(transport1);

  // Создаем адаптеры JSON-RPC поверх базовых транспортов с включенной отладкой
  final clientTransport = JsonRpcTransport(
    'jsonrpc-client',
    transport1,
    debug: true,
  );
  final serverTransport = JsonRpcTransport(
    'jsonrpc-server',
    transport2,
    debug: true,
  );

  // Создаем клиент и сервер с JSON сериализатором (важно для JSON-RPC транспорта)
  final client = RpcEndpoint(
    serializer: const JsonSerializer(),
    transport: clientTransport,
    debugLabel: 'client',
  );

  final server = RpcEndpoint(
    serializer: const JsonSerializer(),
    transport: serverTransport,
    debugLabel: 'server',
  );

  final serverLogger = RpcLogger('server');
  final clientLogger = RpcLogger('client');

  // Настраиваем методы на сервере
  server.registerMethod(
    serviceName: 'calc',
    methodName: 'add',
    handler: (context) async {
      serverLogger.debug(
        'Сервер: обработка запроса add с данными ${context.payload}',
      );
      if (context.payload is! Map<String, dynamic>) {
        throw RpcInvalidArgumentException(
          'Invalid arguments',
          details: {'expected': 'Object with a and b fields'},
        );
      }

      final data = context.payload as Map<String, dynamic>;
      if (data['a'] is! num || data['b'] is! num) {
        throw RpcInvalidArgumentException(
          'Invalid arguments',
          details: {'expected': 'a and b must be numbers'},
        );
      }

      final a = data['a'] as num;
      final b = data['b'] as num;
      final result = {'result': a + b};
      serverLogger.debug('Сервер: возвращаем результат $result');
      return result;
    },
  );

  server.registerMethod(
    serviceName: 'calc',
    methodName: 'subtract',
    handler: (context) async {
      serverLogger.debug(
        'Сервер: обработка запроса subtract с данными ${context.payload}',
      );
      if (context.payload is! Map<String, dynamic>) {
        throw RpcInvalidArgumentException(
          'Invalid arguments',
          details: {'expected': 'Object with a and b fields'},
        );
      }

      final data = context.payload as Map<String, dynamic>;
      if (data['a'] is! num || data['b'] is! num) {
        throw RpcInvalidArgumentException(
          'Invalid arguments',
          details: {'expected': 'a and b must be numbers'},
        );
      }

      final a = data['a'] as num;
      final b = data['b'] as num;
      final result = {'result': a - b};
      serverLogger.debug('Сервер: возвращаем результат $result');
      return result;
    },
  );

  try {
    // Вызов метода сложения
    printHeader('Вызов метода add');
    final addResult = await client.invoke(
      serviceName: 'calc',
      methodName: 'add',
      request: {'a': 10, 'b': 5},
    );
    clientLogger.info(
      'Клиент: получен результат: 10 + 5 = ${addResult['result']}',
    );

    // Вызов метода вычитания
    printHeader('Вызов метода subtract');
    final subtractResult = await client.invoke(
      serviceName: 'calc',
      methodName: 'subtract',
      request: {'a': 10, 'b': 5},
    );
    clientLogger.info(
      'Клиент: получен результат: 10 - 5 = ${subtractResult['result']}',
    );

    // Демонстрация ошибки: неверные аргументы
    try {
      printHeader('Вызов метода add с неверными аргументами');
      await client.invoke(
        serviceName: 'calc',
        methodName: 'add',
        request: {'a': 'not a number', 'b': 5},
      );
    } catch (e) {
      clientLogger.error(
        'Клиент: получена ожидаемая ошибка (invalid arguments)',
        error: {'error': e.toString()},
      );
    }

    // Демонстрация ошибки: метод не найден
    try {
      printHeader('Вызов несуществующего метода multiply');
      await client.invoke(
        serviceName: 'calc',
        methodName: 'multiply',
        request: {'a': 10, 'b': 5},
      );
    } catch (e) {
      clientLogger.error(
        'Клиент: получена ожидаемая ошибка (method not found)',
        error: {'error': e.toString()},
      );
    }
  } finally {
    // Закрываем клиент и сервер
    await client.close();
    await server.close();
  }

  printHeader('JSON-RPC example completed');
}

/// Печатает заголовок раздела
void printHeader(String title) {
  RpcLogger('JsonRpcExample').info('-------------------------');
  RpcLogger('JsonRpcExample').info(' $title');
  RpcLogger('JsonRpcExample').info('-------------------------');
}
