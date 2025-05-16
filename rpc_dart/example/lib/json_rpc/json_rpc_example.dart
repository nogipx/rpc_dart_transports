// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';
import '../utils/logger.dart';

/// Логгер для примера
final logger = ExampleLogger('JsonRpcExample');

/// Пример использования JSON-RPC транспорта для унарных методов
Future<void> main() async {
  logger.section('JSON-RPC example');

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

  // Настраиваем методы на сервере
  server.registerMethod(
    serviceName: 'calc',
    methodName: 'add',
    handler: (context) async {
      logger.debug(
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
      logger.debug('Сервер: возвращаем результат $result');
      return result;
    },
  );

  server.registerMethod(
    serviceName: 'calc',
    methodName: 'subtract',
    handler: (context) async {
      logger.debug(
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
      logger.debug('Сервер: возвращаем результат $result');
      return result;
    },
  );

  try {
    // Вызов метода сложения
    logger.section('Вызов метода add');
    final addResult = await client.invoke(
      serviceName: 'calc',
      methodName: 'add',
      request: {'a': 10, 'b': 5},
    );
    logger.info('Клиент: получен результат: 10 + 5 = ${addResult['result']}');

    // Вызов метода вычитания
    logger.section('Вызов метода subtract');
    final subtractResult = await client.invoke(
      serviceName: 'calc',
      methodName: 'subtract',
      request: {'a': 10, 'b': 5},
    );
    logger.info(
      'Клиент: получен результат: 10 - 5 = ${subtractResult['result']}',
    );

    // Демонстрация ошибки: неверные аргументы
    try {
      logger.section('Вызов метода add с неверными аргументами');
      await client.invoke(
        serviceName: 'calc',
        methodName: 'add',
        request: {'a': 'not a number', 'b': 5},
      );
    } catch (e) {
      logger.error('Клиент: получена ожидаемая ошибка (invalid arguments)', e);
    }

    // Демонстрация ошибки: метод не найден
    try {
      logger.section('Вызов несуществующего метода multiply');
      await client.invoke(
        serviceName: 'calc',
        methodName: 'multiply',
        request: {'a': 10, 'b': 5},
      );
    } catch (e) {
      logger.error('Клиент: получена ожидаемая ошибка (method not found)', e);
    }
  } finally {
    // Закрываем клиент и сервер
    await client.close();
    await server.close();
  }

  logger.section('JSON-RPC example completed');
}
