// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:io';
import 'package:rpc_dart/diagnostics.dart';
import 'utils/logger.dart';

import 'bidirectional/bidirectional.dart' as bidirectional;
import 'client_streaming/client_streaming.dart' as client_streaming;
import 'json_rpc/json_rpc_example.dart' as json_rpc;
import 'server_streaming/server_streaming.dart' as server_streaming;
import 'unary/unary.dart' as unary;

final logger = ExampleLogger('ExampleRunner');

/// Главная функция запуска примеров
Future<void> main(List<String> args) async {
  logger.section('RPC Dart Examples');

  if (args.isEmpty) {
    printHelp();
    exit(0);
  }

  final example = args.first.toLowerCase();
  final debug = args.length > 1 && args[1] == '--debug';

  if (debug) {
    RpcLog.setMinLogLevel(RpcLogLevel.debug);
    logger.info('Включен режим отладки');
  } else {
    RpcLog.setMinLogLevel(RpcLogLevel.info);
  }

  try {
    switch (example) {
      case 'bidirectional':
      case 'bidi':
        await bidirectional.main(debug: debug);
        break;
      case 'client':
      case 'client-streaming':
        await client_streaming.main();
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
      case 'all':
        await runAllExamples(debug);
        break;
      case 'help':
      default:
        printHelp();
    }
  } catch (e, stack) {
    logger.error('Произошла ошибка при выполнении примера', e, stack);
    exit(1);
  }
}

/// Запускает все примеры последовательно
Future<void> runAllExamples(bool debug) async {
  logger.section('Запуск всех примеров');

  try {
    logger.emoji('🔄', 'Запуск примера унарных вызовов...');
    await unary.main(debug: debug);

    logger.emoji('🔄', 'Запуск примера JSON-RPC...');
    await json_rpc.main();

    logger.emoji('🔄', 'Запуск примера клиентского стриминга...');
    await client_streaming.main();

    logger.emoji('🔄', 'Запуск примера серверного стриминга...');
    await server_streaming.main(debug: debug);

    logger.emoji('🔄', 'Запуск примера двунаправленного стриминга...');
    await bidirectional.main(debug: debug);

    logger.emoji('✅', 'Все примеры успешно выполнены!');
  } catch (e) {
    logger.error('Ошибка при выполнении примеров', e);
  }
}

/// Выводит справку по использованию
void printHelp() {
  logger.section('Справка по использованию');
  logger.info('Доступные примеры:');
  logger.bulletList([
    'unary - Пример унарных вызовов (один запрос -> один ответ)',
    'client - Пример клиентского стриминга (поток запросов -> один ответ)',
    'server - Пример серверного стриминга (один запрос -> поток ответов)',
    'bidi - Пример двунаправленного стриминга (поток запросов <-> поток ответов)',
    'json - Пример использования JSON-RPC',
    'all - Запустить все примеры последовательно',
    'help - Показать эту справку',
  ]);

  logger.info('Использование:');
  logger.info('dart run example/lib/module.dart <example> [--debug]');
  logger.info('  --debug: включить режим отладки');
}
