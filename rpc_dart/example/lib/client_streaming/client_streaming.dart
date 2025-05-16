// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import 'package:rpc_dart/rpc_dart.dart';
import '../utils/logger.dart';
import 'client_streaming_contract.dart';
import 'client_streaming_models.dart';

final logger = ExampleLogger('ClientStreamingExample');

/// Главная функция примера клиентского стриминга
Future<void> runClientStreamingExample({bool debug = false}) async {
  logger.section('Пример клиентского стриминга RPC');

  // Создаем два локальных транспорта для демонстрации
  final serverTransport = MemoryTransport('server');
  final clientTransport = MemoryTransport('client');

  // Соединяем транспорты между собой
  serverTransport.connect(clientTransport);
  clientTransport.connect(serverTransport);
  logger.info('Транспорты соединены');

  try {
    // Создаем эндпоинты для сервера и клиента
    final serverEndpoint = RpcEndpoint(
      transport: serverTransport,
      debugLabel: 'server',
    );

    final clientEndpoint = RpcEndpoint(
      transport: clientTransport,
      debugLabel: 'client',
    );

    // Добавляем middleware в зависимости от режима отладки
    if (debug) {
      serverEndpoint.addMiddleware(DebugMiddleware(id: "server"));
      clientEndpoint.addMiddleware(DebugMiddleware(id: "client"));
    } else {
      serverEndpoint.addMiddleware(LoggingMiddleware(id: "server"));
      clientEndpoint.addMiddleware(LoggingMiddleware(id: "client"));
    }

    logger.info('Эндпоинты созданы');

    // Создаем и регистрируем серверную часть
    final serverService = ServerStreamService();
    serverEndpoint.registerServiceContract(serverService);
    logger.info('Серверный сервис зарегистрирован');

    // Создаем клиентскую часть
    final clientService = ClientStreamService(clientEndpoint);
    clientEndpoint.registerServiceContract(clientService);
    logger.info('Клиентский сервис зарегистрирован');

    // Запускаем демонстрацию
    await demonstrateFileUpload(clientService);
  } catch (e, stack) {
    logger.error('Произошла ошибка', e, stack);
    logger.info('Закрываем эндпоинты...');
  } finally {
    await serverTransport.close();
    logger.info('Эндпоинты закрыты');
  }

  logger.section('Пример завершен');
}

/// Демонстрирует процесс загрузки файла частями
Future<void> demonstrateFileUpload(ClientStreamService clientService) async {
  logger.section('Демонстрация загрузки файла частями');

  // Создаем тестовые данные (имитация большого файла)
  logger.emoji('📁', 'Подготовка тестовых данных...');
  final fileData = List.generate(
    10,
    (i) => DataBlock(
      index: i,
      data: _generateData(100000, i).toList(), // 100 KB на блок
      metadata:
          'filename=test_file.dat;mime=application/octet-stream;chunkSize=100000',
    ),
  );

  int totalSize = 0;
  for (final block in fileData) {
    totalSize += block.data.length;
  }

  try {
    // Открываем поток для отправки данных
    logger.emoji('🔄', 'Открытие канала для отправки файла...');
    final uploadStream = clientService.processDataBlocks();

    // Отправляем блоки файла
    logger.emoji('📤', 'Отправка файла частями...');

    for (final block in fileData) {
      // Отправляем каждый блок в потоке
      uploadStream.send(block);
      logger.emoji(
        '📦',
        'Отправлен блок #${block.index}: ${block.data.length} байт',
      );
    }

    // Завершаем отправку (это сигнализирует серверу, что все данные отправлены)
    logger.emoji('✅', 'Завершение отправки файла ($totalSize байт)');
    await uploadStream.finishSending();

    // Закрываем поток клиентской части и ждем ответ
    logger.emoji('🔒', 'Канал отправки закрыт, ожидаем ответ сервера...');
    final result = await uploadStream.getResponse();

    // Получаем и выводим результат обработки
    if (result.blockCount > 0) {
      logger.section('Результат загрузки и обработки файла');
      logger.bulletList([
        'Обработано блоков: ${result.blockCount}',
        'Общий размер: ${result.totalSize} байт',
        'Файл: ${result.metadata}',
        'Время обработки: ${result.processingTime}',
      ]);
      logger.emoji('✅', 'Файл успешно загружен и обработан!');
    }
  } catch (e) {
    logger.emoji('❌', 'Ошибка при отправке файла: $e');
  }
}

/// Генерирует тестовые данные указанного размера
Uint8List _generateData(int size, int seed) {
  final data = Uint8List(size);
  for (var i = 0; i < size; i++) {
    data[i] = (i + seed) % 256;
  }
  return data;
}

/// Основная функция
Future<void> main({bool debug = false}) async {
  await runClientStreamingExample(debug: debug);
}
