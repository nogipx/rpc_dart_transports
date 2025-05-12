import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'client_streaming_contract.dart';
import 'client_streaming_models.dart';

/// Пример использования клиентского стриминга (поток запросов -> один ответ)
/// Демонстрирует использование клиентского стриминга для загрузки файла частями
Future<void> main({bool debug = true}) async {
  print('=== Пример клиентского стриминга RPC ===\n');

  // Создаем транспорты в памяти для локального примера
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты между собой
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  print('Транспорты соединены');

  // Создаем эндпоинты с метками для отладки
  final clientEndpoint = RpcEndpoint(
    transport: clientTransport,
    debugLabel: 'client',
  );
  final serverEndpoint = RpcEndpoint(
    transport: serverTransport,
    debugLabel: 'server',
  );

  if (debug) {
    // Добавляем отладочные middleware для логирования запросов и ответов
    clientEndpoint.addMiddleware(DebugMiddleware());
    serverEndpoint.addMiddleware(DebugMiddleware());
  }

  print('Эндпоинты созданы');

  // Регистрируем сервис стриминга на серверном эндпоинте
  final serverService = ServerStreamService();
  serverEndpoint.registerServiceContract(serverService);
  print('Серверный сервис зарегистрирован');

  // Создаем клиентский сервис
  final streamService = ClientStreamService(clientEndpoint);
  clientEndpoint.registerServiceContract(streamService);
  print('Клиентский сервис зарегистрирован');

  try {
    // Демонстрируем загрузку файла частями
    await demonstrateDataBlocksTransfer(streamService);
  } catch (e, stack) {
    print('Произошла ошибка: $e');
    print('Стек вызовов: $stack');
  } finally {
    print('\nЗакрываем эндпоинты...');
    await clientEndpoint.close();
    await serverEndpoint.close();
    print('Эндпоинты закрыты');
  }

  print('\n=== Пример завершен ===');
}

/// Демонстрирует загрузку файла блоками данных с использованием клиентского стриминга
Future<void> demonstrateDataBlocksTransfer(
  ClientStreamService streamService,
) async {
  print('\n=== Демонстрация загрузки файла частями ===\n');

  // Генерируем тестовые данные - блоки файла
  print('📁 Подготовка тестовых данных...');
  final blocks = <DataBlock>[
    // Первый блок, 500 байт
    DataBlock(
      index: 1,
      data: List.generate(500, (i) => i % 256),
      metadata: 'my_document.pdf',
    ),
    // Второй блок, 800 байт
    DataBlock(index: 2, data: List.generate(800, (i) => i % 256), metadata: ''),
    // Третий блок, 1200 байт
    DataBlock(
      index: 3,
      data: List.generate(1200, (i) => i % 256),
      metadata: '',
    ),
    // Четвертый блок, 300 байт
    DataBlock(index: 4, data: List.generate(300, (i) => i % 256), metadata: ''),
  ];

  // Открываем поток для отправки файла
  print('🔄 Открытие канала для отправки файла...');

  // Создаем клиентский стрим для отправки блоков данных
  final clientStreamBidi = streamService.processDataBlocks();

  print('📤 Отправка файла частями...');

  // Отправляем блоки данных
  int totalSize = 0;
  for (final block in blocks) {
    clientStreamBidi.send(block);
    totalSize += block.data.length;
    print('  📦 Отправлен блок #${block.index}: ${block.data.length} байт');
    await Future.delayed(Duration(milliseconds: 50));
  }

  print('✅ Завершение отправки файла ($totalSize байт)');

  // Сигнализируем о завершении передачи данных
  await clientStreamBidi.finishSending();

  print('🔒 Канал отправки закрыт, ожидаем ответ сервера...');

  try {
    // Получаем результат обработки файла
    // Увеличиваем таймаут до 5 секунд для избежания таймаута в примере
    final result = await clientStreamBidi.getResponse().timeout(
      Duration(seconds: 5),
      onTimeout:
          () => throw TimeoutException('Не удалось получить ответ от сервера'),
    );

    print('\n📋 Результат загрузки и обработки файла:');
    print('  • Обработано блоков: ${result.blockCount}');
    print('  • Общий размер: ${result.totalSize} байт');
    print('  • Файл: ${result.metadata}');
    print('  • Время обработки: ${result.processingTime}');
    print('✅ Файл успешно загружен и обработан!');
  } catch (e) {
    print('❌ Ошибка при отправке файла: $e');
    rethrow;
  } finally {
    // Полностью закрываем поток и освобождаем ресурсы
    await clientStreamBidi.close();
  }
}
