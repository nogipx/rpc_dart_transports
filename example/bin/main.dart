// Экспортируем нужные классы
import 'package:example/unary/unary.dart' as unary;
import 'package:example/client_streaming/client_streaming.dart' as client_streaming;
import 'package:example/server_streaming/server_streaming.dart' as server_streaming;
import 'package:example/bidirectional/bidirectional.dart' as bidirectional;
import 'package:args/args.dart';

// Включаем middleware для отладки запросов
const bool debug = true;

void printExamples() {
  print('=== RPC Dart Examples ===');
  print('Примеры разных типов RPC взаимодействий');
  print('');
  print('> rpc_dart_example -d -e [example]');
  print('');
  print('Доступные примеры:');
  print('');
  print('1. unary - Унарный RPC: один запрос -> один ответ');
  print('2. client - Клиентский стриминг: поток запросов -> один ответ');
  print('3. server - Серверный стриминг: один запрос -> поток ответов');
  print('4. bidirectional - Двунаправленный стриминг: поток запросов <-> поток ответов');
  print('');
}

// Запуск примеров
Future<void> main(List<String> args) async {
  final parser =
      ArgParser()
        ..addOption(
          'example',
          abbr: 'e',
          help: 'Пример для запуска (unary, client, server, bidirectional)',
          allowed: ['unary', 'client', 'server', 'bidirectional', '1', '2', '3', '4'],
        )
        ..addFlag('debug', abbr: 'd', help: 'Включить режим отладки', defaultsTo: true)
        ..addFlag('help', abbr: 'h', help: 'Показать справку', negatable: false);

  ArgResults argResults;

  try {
    argResults = parser.parse(args);
  } catch (e) {
    print('Ошибка: $e');
    print('');
    print(parser.usage);
    return;
  }

  if (argResults['help'] as bool) {
    printExamples();
    print('Использование:');
    print(parser.usage);
    return;
  }

  final debugMode = argResults['debug'] as bool;
  String? example = argResults['example'] as String?;
  if (example == null) {
    printExamples();
    print('Укажите один из доступных примеров.');
    return;
  }

  // Преобразуем числовые аргументы в строковые идентификаторы
  switch (example) {
    case '1':
      example = 'unary';
      break;
    case '2':
      example = 'client';
      break;
    case '3':
      example = 'server';
      break;
    case '4':
      example = 'bidirectional';
      break;
  }

  // Запуск выбранного примера
  switch (example) {
    case 'unary':
      print('\nЗапуск унарного примера...\n');
      await unary.main(debug: debugMode);
      break;
    case 'client':
      print('\nЗапуск примера клиентского стриминга...\n');
      await client_streaming.main(debug: debugMode);
      break;
    case 'server':
      print('\nЗапуск примера серверного стриминга...\n');
      await server_streaming.main(debug: debugMode);
      break;
    case 'bidirectional':
      print('\nЗапуск примера двунаправленного стриминга...\n');
      await bidirectional.main(debug: debugMode);
      break;
    default:
      printExamples();
      print('Неизвестный пример: $example');
      print('Укажите один из доступных примеров.');
  }
}
