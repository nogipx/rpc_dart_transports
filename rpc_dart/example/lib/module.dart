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

final _logger = RpcLogger('ExampleRunner');

/// Главная функция запуска примеров
Future<void> main(List<String> args) async {
  printHeader('RPC Dart Examples');

  if (args.isEmpty) {
    printHelp();
    return;
  }

  final example = args.first.toLowerCase();
  final debug = args.length > 1 && args[1] == '--debug';

  if (debug) {
    RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);
    _logger.info('Включен режим отладки');
  } else {
    RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.info);
    _logger.info('Включен режим отладки');
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
    _logger.error(
      'Произошла ошибка при выполнении примера',
      error: {'error': e.toString()},
      stackTrace: stack,
    );
  }
}

/// Запускает все примеры последовательно
Future<void> runAllExamples(bool debug) async {
  printHeader('Запуск всех примеров');

  try {
    _logger.info('🔄 Запуск примера унарных вызовов...');
    await unary.main(debug: debug);

    _logger.info('🔄 Запуск примера JSON-RPC...');
    await json_rpc.main();

    _logger.info('🔄 Запуск примера клиентского стриминга...');
    await client_streaming.main(debug: debug);

    _logger.info('🔄 Запуск примера серверного стриминга...');
    await server_streaming.main(debug: debug);

    _logger.info('🔄 Запуск примера двунаправленного стриминга...');
    await bidirectional.main(debug: debug);

    _logger.info('🔄 Запуск примера диагностики...');
    await diagnostics.main(debug: debug);

    _logger.info('✅ Все примеры успешно выполнены!');
  } catch (e) {
    _logger.error(
      'Ошибка при выполнении примеров',
      error: {'error': e.toString()},
    );
  }
}

/// Выводит заголовок
void printHeader(String title) {
  _logger.info('-------------------------');
  _logger.info(' $title');
  _logger.info('-------------------------');
}

/// Выводит справку по использованию
void printHelp() {
  printHeader('Справка по использованию');

  _logger.info('Доступные примеры:');

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
    _logger.info('  • $example');
  }

  _logger.info('Использование:');
  _logger.info('dart run example/lib/module.dart <example> [--debug]');
  _logger.info('  --debug: включить режим отладки');
}
