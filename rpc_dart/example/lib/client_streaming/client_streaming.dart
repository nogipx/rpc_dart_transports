// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import 'package:rpc_dart/rpc_dart.dart';
import 'client_streaming_contract.dart';
import 'client_streaming_models.dart';

const String _source = 'ClientStreamingExample';
late final RpcLogger _logger;

/// Основная функция
Future<void> main({bool debug = false}) async {
  await runClientStreamingExample(debug: debug);
}

/// Главная функция примера клиентского стриминга
Future<void> runClientStreamingExample({bool debug = false}) async {
  // Создаем логгер для примера
  _logger = RpcLogger(_source);

  printHeader('Пример клиентского стриминга RPC');

  // Создаем два локальных транспорта для демонстрации
  final serverTransport = MemoryTransport('server');
  final clientTransport = MemoryTransport('client');

  // Соединяем транспорты между собой
  serverTransport.connect(clientTransport);
  clientTransport.connect(serverTransport);
  _logger.info('Транспорты соединены');

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
      serverEndpoint.addMiddleware(DebugMiddleware(RpcLogger("server")));
      clientEndpoint.addMiddleware(DebugMiddleware(RpcLogger("client")));
    } else {
      serverEndpoint.addMiddleware(LoggingMiddleware(RpcLogger('server')));
      clientEndpoint.addMiddleware(LoggingMiddleware(RpcLogger('client')));
    }

    _logger.info('Эндпоинты созданы');

    // Создаем и регистрируем серверную часть
    final serverService = ServerStreamService();
    serverEndpoint.registerServiceContract(serverService);
    _logger.info('Серверный сервис зарегистрирован');

    // Создаем клиентскую часть
    final clientService = ClientStreamService(clientEndpoint);
    clientEndpoint.registerServiceContract(clientService);
    _logger.info('Клиентский сервис зарегистрирован');

    // Запускаем демонстрацию с обычным клиентским стримингом
    await demonstrateFileUpload(clientService);

    // Запускаем демонстрацию без ожидания ответа
    await demonstrateFileUploadWithoutResponse(clientService);

    // Запускаем демонстрацию с получением результата
    await demonstrateFileUploadWithResult(clientService);
  } catch (error, trace) {
    _logger.error('Произошла ошибка', error: error, stackTrace: trace);
    _logger.info('Закрываем эндпоинты...');
  } finally {
    await serverTransport.close();
    _logger.info('Эндпоинты закрыты');
  }

  printHeader('Пример завершен');
}

/// Демонстрирует процесс загрузки файла частями
Future<void> demonstrateFileUpload(ClientStreamService clientService) async {
  printHeader('Демонстрация загрузки файла частями');

  // Создаем тестовые данные (имитация большого файла)
  _logger.info('📁 Подготовка тестовых данных...');
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
    _logger.info('🔄 Открытие канала для отправки файла...');
    final uploadStream = clientService.processDataBlocks();

    // Отправляем блоки файла
    _logger.info('📤 Отправка файла частями...');

    for (final block in fileData) {
      // Отправляем каждый блок в потоке
      uploadStream.send(block);
      _logger.info(
        '📦 Отправлен блок #${block.index}: ${block.data.length} байт',
      );
    }

    // Завершаем отправку (это сигнализирует серверу, что все данные отправлены)
    _logger.info('✅ Завершение отправки файла ($totalSize байт)');
    await uploadStream.finishSending();

    // Закрываем поток клиентской части
    _logger.info('🔒 Канал отправки закрыт');
    await uploadStream.close();

    _logger.info('✅ Файл успешно отправлен!');
  } catch (e) {
    _logger.error(
      '❌ Ошибка при отправке файла',
      error: {'error': e.toString()},
    );
  }
}

/// Демонстрирует процесс загрузки файла частями без ожидания ответа
Future<void> demonstrateFileUploadWithoutResponse(
  ClientStreamService clientService,
) async {
  printHeader('Демонстрация загрузки файла без ожидания ответа');

  // Создаем тестовые данные (имитация большого файла)
  _logger.info('📁 Подготовка тестовых данных...');
  final fileData = List.generate(
    5,
    (i) => DataBlock(
      index: i,
      data: _generateData(50000, i).toList(), // 50 KB на блок
      metadata:
          'filename=test_file_no_response.dat;mime=application/octet-stream;chunkSize=50000',
    ),
  );

  int totalSize = 0;
  for (final block in fileData) {
    totalSize += block.data.length;
  }

  try {
    // Открываем поток для отправки данных без ожидания ответа
    _logger.info(
      '🔄 Открытие канала для отправки файла без ожидания ответа...',
    );
    final uploadStream = clientService.processDataBlocksNoResponse();

    // Отправляем блоки файла
    _logger.info('📤 Отправка файла частями...');

    for (final block in fileData) {
      // Отправляем каждый блок в потоке
      uploadStream.send(block);
      _logger.info(
        '📦 Отправлен блок #${block.index}: ${block.data.length} байт',
      );
    }

    // Завершаем отправку (это сигнализирует серверу, что все данные отправлены)
    _logger.info('✅ Завершение отправки файла ($totalSize байт)');
    await uploadStream.finishSending();

    // Завершаем поток
    _logger.info('🔒 Канал отправки закрыт');
    await uploadStream.close();

    _logger.info('✅ Файл успешно отправлен без ожидания ответа!');
  } catch (e) {
    _logger.error(
      '❌ Ошибка при отправке файла',
      error: {'error': e.toString()},
    );
  }
}

/// Демонстрирует процесс загрузки файла частями с получением результата обработки
Future<void> demonstrateFileUploadWithResult(
  ClientStreamService clientService,
) async {
  printHeader('Демонстрация загрузки файла с получением результата');

  // Создаем тестовые данные (имитация большого файла)
  _logger.info('📁 Подготовка тестовых данных...');
  final fileData = List.generate(
    8,
    (i) => DataBlock(
      index: i,
      data: _generateData(80000, i).toList(), // 80 KB на блок
      metadata:
          'filename=test_file_with_result.dat;mime=application/octet-stream;chunkSize=80000',
    ),
  );

  int totalSize = 0;
  for (final block in fileData) {
    totalSize += block.data.length;
  }

  try {
    // Открываем поток для отправки данных с ожиданием результата
    _logger.info(
      '🔄 Открытие канала для отправки файла с ожиданием результата...',
    );
    final uploadStream = clientService.processDataBlocksWithResponse();

    // Отправляем блоки файла
    _logger.info('📤 Отправка файла частями...');

    for (final block in fileData) {
      // Отправляем каждый блок в потоке
      uploadStream.send(block);
      _logger.info(
        '📦 Отправлен блок #${block.index}: ${block.data.length} байт',
      );
    }

    // Завершаем отправку (это сигнализирует серверу, что все данные отправлены)
    _logger.info('✅ Завершение отправки файла ($totalSize байт)');
    await uploadStream.finishSending();

    // Получаем результат обработки от сервера
    _logger.info('⏳ Ожидание результата обработки от сервера...');
    final result = await uploadStream.getResponse();

    if (result != null) {
      _logger.info('📊 Получен результат обработки:');
      _logger.info('  • Количество блоков: ${result.blockCount}');
      _logger.info('  • Общий размер: ${result.totalSize} байт');
      _logger.info('  • Метаданные: ${result.metadata}');
      _logger.info('  • Время обработки: ${result.processingTime}');
    } else {
      _logger.info('⚠️ Результат обработки не получен');
    }

    // Закрываем поток клиентской части
    _logger.info('🔒 Канал отправки закрыт');
    await uploadStream.close();

    _logger.info('✅ Файл успешно отправлен и обработан!');
  } catch (e) {
    _logger.error(
      '❌ Ошибка при отправке файла или получении результата',
      error: {'error': e.toString()},
    );
  }
}

/// Печатает заголовок раздела
void printHeader(String title) {
  _logger.info('-------------------------');
  _logger.info(' $title');
  _logger.info('-------------------------');
}

/// Генерирует тестовые данные указанного размера
Uint8List _generateData(int size, int seed) {
  final data = Uint8List(size);
  for (var i = 0; i < size; i++) {
    data[i] = (i + seed) % 256;
  }
  return data;
}
