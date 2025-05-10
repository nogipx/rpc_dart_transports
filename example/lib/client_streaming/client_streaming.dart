import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'client_streaming_contract.dart';
import 'client_streaming_models.dart';

/// Пример использования клиентского стриминга (поток запросов -> один ответ)
/// Демонстрирует использование клиентского стриминга для загрузки файла частями
Future<void> main({bool debug = false}) async {
  print('=== Пример клиентского стриминга RPC ===\n');

  // Создаем транспорты в памяти для локального примера
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты между собой
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  print('Транспорты соединены');

  // Создаем эндпоинты с метками для отладки
  final client = RpcEndpoint(
    transport: clientTransport,
    serializer: JsonSerializer(),
    debugLabel: 'client',
  );
  final server = RpcEndpoint(
    transport: serverTransport,
    serializer: JsonSerializer(),
    debugLabel: 'server',
  );
  print('Эндпоинты созданы');

  // Добавляем middleware для логирования
  if (debug) {
    server.addMiddleware(DebugMiddleware(id: "server"));
    client.addMiddleware(DebugMiddleware(id: "client"));
  } else {
    server.addMiddleware(LoggingMiddleware(id: "server"));
    client.addMiddleware(LoggingMiddleware(id: 'client'));
  }

  try {
    // Создаем серверные реализации сервисов
    final streamService = ServerStreamService();
    server.registerServiceContract(streamService);
    print('Серверный сервис зарегистрирован');

    // Создаем клиентские реализации сервисов
    final clientStreamService = ClientStreamService(client);
    client.registerServiceContract(clientStreamService);
    print('Клиентский сервис зарегистрирован');

    // Демонстрация загрузки файла
    await demonstrateDataBlocks(clientStreamService);
  } catch (e) {
    print('Произошла ошибка: $e');
  } finally {
    // Закрываем эндпоинты
    await client.close();
    await server.close();
    print('\nЭндпоинты закрыты');
  }

  print('\n=== Пример завершен ===');
}

/// Демонстрация загрузки файла
Future<void> demonstrateDataBlocks(ClientStreamService streamService) async {
  print('\n=== Демонстрация загрузки файла частями ===\n');

  print('📁 Подготовка загрузки файла...');

  // Имитируем разбиение файла на несколько частей (чанков)
  final fileChunks = [
    DataBlock(
      index: 1,
      data: List.generate(500, (i) => i % 256), // Первый чанк файла
      metadata: 'my_document.pdf', // Имя файла в метаданных первого чанка
    ),
    DataBlock(index: 2, data: List.generate(800, (i) => i % 256)), // Второй чанк
    DataBlock(index: 3, data: List.generate(1200, (i) => i % 256)), // Третий чанк
    DataBlock(index: 4, data: List.generate(300, (i) => i % 256)), // Последний чанк
  ];

  try {
    print('🔄 Открытие канала для отправки файла...');

    // Создаем клиентский стрим для отправки блоков данных
    final processStream = await streamService.processDataBlocks(
      RpcClientStreamParams<DataBlock, DataBlockResult>(
        metadata: {},
        streamId: 'file-upload-stream',
      ),
    );

    print('📤 Отправка файла частями...');

    // Получаем управление стримом
    final controller = processStream.controller;
    if (controller == null) {
      throw RpcInvalidArgumentException('Сервер не предоставил контроллер для потока');
    }
    var totalSent = 0;

    // Отправляем блоки данных последовательно
    for (final chunk in fileChunks) {
      controller.add(chunk);
      totalSent += chunk.data.length;
      print('  📦 Отправлен блок #${chunk.index}: ${chunk.data.length} байт');

      // Имитация задержки сети
      await Future.delayed(Duration(milliseconds: 100));
    }

    print('✅ Завершение отправки файла ($totalSent байт)');

    // Закрываем поток отправки
    await controller.close();
    print('🔒 Канал отправки закрыт');

    // Получаем результат обработки от сервера
    final result = await processStream.response;
    if (result != null) {
      print('\n📥 Получен ответ сервера:');
      print('  • Обработано блоков: ${result.blockCount}');
      print('  • Общий размер: ${result.totalSize} байт');
      print('  • Имя файла: ${result.metadata}');
      print('  • Время обработки: ${result.processingTime}');
    } else {
      print('\n⚠️ Ответ от сервера не содержит данных');
    }
  } catch (e) {
    print('❌ Ошибка при отправке файла: $e');
  }
}
