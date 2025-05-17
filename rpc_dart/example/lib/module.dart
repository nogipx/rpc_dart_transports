// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/diagnostics.dart';

import 'bidirectional/bidirectional.dart' as bidirectional;
import 'client_streaming/client_streaming.dart' as client_streaming;
import 'json_rpc/json_rpc_example.dart' as json_rpc;
import 'server_streaming/server_streaming.dart' as server_streaming;
import 'unary/unary.dart' as unary;
import 'diagnostics/diagnostics_example.dart' as diagnostics;

const String _source = 'ExampleRunner';

/// Главная функция запуска примеров
Future<void> main(List<String> args) async {
  printHeader('RPC Dart Examples');

  if (args.isEmpty) {
    printHelp();
    exit(0);
  }

  final example = args.first.toLowerCase();
  final debug = args.length > 1 && args[1] == '--debug';

  if (debug) {
    RpcLog.setDefaultMinLogLevel(RpcLoggerLevel.debug);
    RpcLog.get(_source).info(message: 'Включен режим отладки');
  } else {
    RpcLog.setDefaultMinLogLevel(RpcLoggerLevel.info);
    RpcLog.get(_source).info(message: 'Включен режим отладки');
  }

  try {
    switch (example) {
      case 'bidirectional':
      case 'bidi':
        await bidirectional.main(debug: debug);
        break;
      case 'client':
      case 'client-streaming':
        await client_streaming.main(debug: debug);
        break;
      case 'server':
      case 'server-streaming':
        await server_streaming.main(debug: debug);
        break;
      case 'unary':
        await unary.main(debug: debug);
        break;
      case 'json':
      case 'json-rpc':
        await json_rpc.main();
        break;
      case 'diagnostics':
      case 'diagnostic':
        await diagnostics.main(debug: debug);
        break;
      case 'all':
        await runAllExamples(debug);
        break;
      case 'help':
      default:
        printHelp();
    }
  } catch (e, stack) {
    RpcLog.error(
      message: 'Произошла ошибка при выполнении примера',
      source: _source,
      error: {'error': e.toString()},
      stackTrace: stack.toString(),
    );
    exit(1);
  }
}

/// Запускает все примеры последовательно
Future<void> runAllExamples(bool debug) async {
  printHeader('Запуск всех примеров');

  try {
    RpcLog.info(
      message: '🔄 Запуск примера унарных вызовов...',
      source: _source,
    );
    await unary.main(debug: debug);

    RpcLog.info(message: '🔄 Запуск примера JSON-RPC...', source: _source);
    await json_rpc.main();

    RpcLog.info(
      message: '🔄 Запуск примера клиентского стриминга...',
      source: _source,
    );
    await client_streaming.main(debug: debug);

    RpcLog.info(
      message: '🔄 Запуск примера серверного стриминга...',
      source: _source,
    );
    await server_streaming.main(debug: debug);

    RpcLog.info(
      message: '🔄 Запуск примера двунаправленного стриминга...',
      source: _source,
    );
    await bidirectional.main(debug: debug);

    RpcLog.info(message: '🔄 Запуск примера диагностики...', source: _source);
    await diagnostics.main(debug: debug);

    RpcLog.info(message: '✅ Все примеры успешно выполнены!', source: _source);
  } catch (e) {
    RpcLog.error(
      message: 'Ошибка при выполнении примеров',
      source: _source,
      error: {'error': e.toString()},
    );
  }
}

/// Выводит заголовок
void printHeader(String title) {
  RpcLog.info(message: '-------------------------', source: _source);
  RpcLog.info(message: ' $title', source: _source);
  RpcLog.info(message: '-------------------------', source: _source);
}

/// Выводит справку по использованию
void printHelp() {
  printHeader('Справка по использованию');

  RpcLog.info(message: 'Доступные примеры:', source: _source);

  final examples = [
    'unary - Пример унарных вызовов (один запрос -> один ответ)',
    'client - Пример клиентского стриминга (поток запросов -> один ответ)',
    'server - Пример серверного стриминга (один запрос -> поток ответов)',
    'bidi - Пример двунаправленного стриминга (поток запросов <-> поток ответов)',
    'json - Пример использования JSON-RPC',
    'diagnostics - Пример настройки сервиса диагностики',
    'all - Запустить все примеры последовательно',
    'help - Показать эту справку',
  ];

  for (final example in examples) {
    RpcLog.info(message: '  • $example', source: _source);
  }

  RpcLog.info(message: 'Использование:', source: _source);
  RpcLog.info(
    message: 'dart run example/lib/module.dart <example> [--debug]',
    source: _source,
  );
  RpcLog.info(message: '  --debug: включить режим отладки', source: _source);
}
