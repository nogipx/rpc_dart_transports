// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';
import 'dart:math' show min;
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
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  printHeader('Пример клиентского стриминга RPC');

  // Создаем два локальных транспорта для демонстрации
  final serverTransport = MemoryTransport('server');
  final clientTransport = MemoryTransport('client');

  // Соединяем транспорты между собой
  serverTransport.connect(clientTransport);
  clientTransport.connect(serverTransport);
  _logger.info('Транспорты соединены');

  RpcEndpoint? serverEndpoint;
  RpcEndpoint? clientEndpoint;

  try {
    // Создаем эндпоинты для сервера и клиента
    serverEndpoint = RpcEndpoint(
      transport: serverTransport,
      debugLabel: 'server',
    );

    clientEndpoint = RpcEndpoint(
      transport: clientTransport,
      debugLabel: 'client',
    );

    // Включаем отладку всегда для демонстрации процесса
    final serverLogger = RpcLogger("server");
    final clientLogger = RpcLogger("client");
    serverEndpoint.addMiddleware(DebugMiddleware(serverLogger));
    clientEndpoint.addMiddleware(DebugMiddleware(clientLogger));

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
    await demonstrateSimpleFileUpload(clientService);

    // Даем время на завершение логов и корректное закрытие соединений
    _logger.info('✅ Пример завершен, выход через 1 секунду...');
    await Future.delayed(Duration(seconds: 1));

    // Принудительно завершаем все соединения и ресурсы
    await clientEndpoint.close();
    _logger.info('Клиентский эндпоинт закрыт');

    await serverEndpoint.close();
    _logger.info('Серверный эндпоинт закрыт');

    // Принудительно закрываем транспорты
    await clientTransport.close();
    await serverTransport.close();
    _logger.info('Все транспорты закрыты');
  } catch (error, trace) {
    _logger.error('Произошла ошибка', error: error, stackTrace: trace);
  }

  printHeader('Пример завершен');
}

/// Демонстрирует процесс загрузки файла частями с минимальными зависимостями
Future<void> demonstrateSimpleFileUpload(
  ClientStreamService clientService,
) async {
  printHeader('Демонстрация простой загрузки файла');

  // Создаем тестовые данные (имитация файла)
  _logger.info('📁 Подготовка тестовых данных...');
  final fileData = List.generate(
    2, // Используем 2 блока для тестирования
    (i) => DataBlock(
      index: i,
      data: _generateData(500, i).toList(), // Блоки по 500 байт
      metadata:
          'filename=test_file.dat;mime=application/octet-stream;chunkSize=500',
    ),
  );

  int totalSize = 0;
  for (final block in fileData) {
    totalSize += block.data.length;
  }

  _logger.info(
    '📊 Размер тестового файла: $totalSize байт в ${fileData.length} блоках',
  );

  ClientStreamingBidiStream<DataBlock, DataBlockResult>? uploadStream;
  bool isErrorEncountered = false;

  try {
    // Шаг 1: Открытие канала для отправки данных
    _logger.info('🔄 Шаг 1: Открытие канала для отправки файла...');
    try {
      // ВАЖНО: Создаем стрим только один раз и сохраняем его в переменной
      uploadStream = clientService.processDataBlocksWithResponse();
      _logger.info(
        '✅ Канал открыт, состояние канала: active = ${!uploadStream.isClosed}, closed = ${uploadStream.isClosed}',
      );
    } catch (e) {
      if (e.toString().contains('Endpoint closed')) {
        _logger.info('❗ Невозможно открыть канал - эндпоинт закрыт');
        isErrorEncountered = true;
        return; // Завершаем метод, если эндпоинт закрыт
      } else {
        rethrow;
      }
    }

    // Шаг 2: Отправка всех блоков данных
    if (!isErrorEncountered) {
      _logger.info(
        '📤 Шаг 2: Отправка файловых блоков (${fileData.length} шт.)...',
      );

      for (final block in fileData) {
        try {
          // Отправляем все блоки через один и тот же стрим
          uploadStream.send(block);
          _logger.info(
            '📦 Отправлен блок #${block.index}: ${block.data.length} байт',
          );
          // Небольшая пауза для стабильности
          await Future.delayed(Duration(milliseconds: 20));
        } catch (e) {
          if (e.toString().contains('Endpoint closed')) {
            _logger.info('❗ Ошибка при отправке блока - эндпоинт закрыт');
            isErrorEncountered = true;
            break; // Прерываем отправку при ошибке эндпоинта
          } else {
            rethrow;
          }
        }
      }

      if (!isErrorEncountered) {
        _logger.info('✅ Все блоки отправлены');
      }
    }

    // Шаг 3: Завершение отправки
    if (!isErrorEncountered) {
      _logger.info('🏁 Шаг 3: Завершение отправки файла...');
      _logger.info(
        'Состояние перед finishSending: active = ${!uploadStream.isClosed}, closed = ${uploadStream.isClosed}',
      );

      try {
        await uploadStream.finishSending();
        _logger.info(
          '✅ Отправка завершена, состояние: active = ${!uploadStream.isClosed}, closed = ${uploadStream.isClosed}',
        );
      } catch (e) {
        if (e.toString().contains('Endpoint closed')) {
          _logger.info('❗ Ошибка при завершении отправки - эндпоинт закрыт');
          isErrorEncountered = true;
        } else {
          rethrow;
        }
      }
    }

    // Шаг 4: Получение ответа от сервера - СРАЗУ после завершения отправки данных
    if (!isErrorEncountered) {
      _logger.info('📥 Шаг 4: Ожидание ответа от сервера...');
      try {
        // Сначала получаем синхронно результат - это для случая, если ответ уже получен
        // Особенность нашей реализации - ответ может прийти до вызова getResponse()
        DataBlockResult? response;

        // Сначала проверяем, есть ли у нас доступ к полю _wasResponseProcessed
        try {
          // Получаем ответ напрямую, без ожидания
          response = await uploadStream.getResponse();
          _logger.info('✅ Ответ получен немедленно: $response');
        } catch (e) {
          _logger.info(
            'Ответ не получен немедленно, будем ждать с таймаутом: ${e.toString().substring(0, min(50, e.toString().length))}...',
          );

          // Ограничиваем время ожидания ответа до 3 секунд
          response = await uploadStream.getResponse().timeout(
            Duration(seconds: 3),
            onTimeout: () {
              _logger.error('⏱️ Превышено время ожидания ответа (3 сек)');
              isErrorEncountered = true;
              throw TimeoutException('Превышено время ожидания ответа');
            },
          );
        }

        // Безопасно проверяем ответ, поскольку он может быть null
        if (response != null) {
          _logger.info('✅ Ответ получен: $response');
        } else {
          _logger.info('⚠️ Получен пустой ответ (null)');
        }

        // После получения ответа сразу закрываем стрим, чтобы избежать любых таймаутов
        _logger.info('🔒 Закрытие канала сразу после получения ответа...');
        // Закрываем стрим вне зависимости от флага isClosed
        try {
          await uploadStream.close();
          _logger.info('✅ Канал успешно закрыт');
        } catch (e) {
          _logger.info(
            '⚠️ Ошибка при закрытии канала: ${e.toString().substring(0, min(50, e.toString().length))}...',
          );
        }
      } catch (e) {
        final errorMessage = e.toString().substring(
          0,
          min(e.toString().length, 100),
        );

        if (e is TimeoutException) {
          _logger.info('⏱️ Не удалось получить ответ: $errorMessage...');
        } else {
          _logger.info('⚠️ Не удалось получить ответ: $errorMessage...');
        }

        if (e.toString().contains('Endpoint closed')) {
          _logger.info(
            '🔍 Обнаружена ошибка закрытия эндпоинта - это ожидаемо в некоторых сценариях',
          );
          isErrorEncountered = true;
        } else {
          isErrorEncountered = true;
        }

        // Всегда пытаемся закрыть стрим при ошибках
        try {
          await uploadStream.close();
          _logger.info('✅ Канал закрыт после ошибки получения ответа');
        } catch (closeError) {
          _logger.info(
            '⚠️ Ошибка при закрытии канала: ${closeError.toString().substring(0, min(50, closeError.toString().length))}...',
          );
        }
      }
    }

    // Шаг 5: Небольшая пауза перед закрытием стрима УБРАНА, так как закрытие выполнено выше
    // И закрытие стрима УБРАНО, поскольку это уже выполнено выше
    // Оставляем только проверку состояния

    if (isErrorEncountered) {
      _logger.info('⚠️ Операция отправки файла завершена с ошибками');
    } else {
      _logger.info('✅ Операция отправки файла успешно завершена!');
    }
  } catch (e, stack) {
    _logger.error('❌ Ошибка при отправке файла', error: e, stackTrace: stack);

    // В случае общей ошибки, пытаемся закрыть ресурсы
    if (uploadStream != null && !uploadStream.isClosed) {
      try {
        await uploadStream.close();
        _logger.info('🔧 Канал закрыт после ошибки');
      } catch (closeError) {
        if (closeError.toString().contains('Endpoint closed')) {
          _logger.debug(
            'Эндпоинт уже закрыт, игнорируем ошибку при закрытии канала',
          );
        } else {
          _logger.debug(
            'Ошибка при закрытии канала после общей ошибки: $closeError',
          );
        }
      }
    }
  }
}

/// Демонстрирует процесс загрузки файла частями
Future<void> demonstrateFileUpload(ClientStreamService clientService) async {
  printHeader('Демонстрация загрузки файла частями');

  // Создаем тестовые данные (имитация файла)
  _logger.info('📁 Подготовка тестовых данных...');
  final fileData = List.generate(
    2, // Уменьшаем до 2 блоков для отладки
    (i) => DataBlock(
      index: i,
      data: _generateData(500, i).toList(), // Уменьшаем до 500 байт на блок
      metadata:
          'filename=test_file.dat;mime=application/octet-stream;chunkSize=500',
    ),
  );

  int totalSize = 0;
  for (final block in fileData) {
    totalSize += block.data.length;
  }

  try {
    // Открываем поток для отправки данных
    _logger.info('🔄 Открытие канала для отправки файла...');
    final uploadStream = clientService.processDataBlocksWithResponse();
    _logger.info(
      'Stream создан, состояние: isTransferFinished=${uploadStream.isClosed}, isClosed=${uploadStream.isClosed}',
    );

    // Отправляем блоки файла
    _logger.info('📤 Отправка файла частями...');

    for (final block in fileData) {
      // Отправляем каждый блок в потоке
      _logger.info(
        'Отправка блока #${block.index}, состояние стрима: isTransferFinished=${uploadStream.isClosed}, isClosed=${uploadStream.isClosed}',
      );
      uploadStream.send(block);
      _logger.info(
        '📦 Отправлен блок #${block.index}: ${block.data.length} байт',
      );
      // Делаем паузу между отправками для логирования
      await Future.delayed(Duration(milliseconds: 50));
    }

    // Завершаем отправку (это сигнализирует серверу, что все данные отправлены)
    _logger.info('✅ Завершение отправки файла ($totalSize байт)');
    _logger.info(
      'Вызываю finishSending(), состояние до: isTransferFinished=${uploadStream.isClosed}, isClosed=${uploadStream.isClosed}',
    );

    // ВАЖНО! Правильная последовательность:
    // 1. Завершаем отправку
    await uploadStream.finishSending();
    _logger.info(
      'finishSending() выполнен, состояние после: isTransferFinished=${uploadStream.isClosed}, isClosed=${uploadStream.isClosed}',
    );

    // 2. Ждем короткую паузу для обработки сервером
    await Future.delayed(Duration(milliseconds: 100));

    // 3. Получаем ответ сервера после завершения отправки
    _logger.info('⏳ Ожидание ответа от сервера...');

    try {
      // Устанавливаем таймаут ожидания ответа
      final response = await uploadStream.getResponse();
      _logger.info('✅ Ответ получен: $response');

      // ПРАВИЛЬНО: ждем небольшую паузу перед закрытием
      // это дает время для завершения обработки ответа сервером
      await Future.delayed(Duration(milliseconds: 100));

      // 4. Только после получения ответа закрываем поток клиентской части
      _logger.info(
        '🔒 Закрытие канала отправки, состояние до: isTransferFinished=${uploadStream.isClosed}, isClosed=${uploadStream.isClosed}',
      );

      await uploadStream.close();
      _logger.info(
        '🔒 Канал отправки закрыт, состояние после: isTransferFinished=${uploadStream.isClosed}, isClosed=${uploadStream.isClosed}',
      );
    } catch (e) {
      _logger.error('❌ Ошибка при получении ответа', error: e);

      // Если получение ответа не удалось, все равно закрываем потоки
      if (!uploadStream.isClosed) {
        try {
          await uploadStream.close();
          _logger.info('🔒 Канал закрыт после ошибки');
        } catch (closeError) {
          _logger.error('❌ Ошибка при закрытии канала', error: closeError);
        }
      }
    }

    _logger.info('✅ Операция отправки файла завершена!');
  } catch (e, stack) {
    _logger.error('❌ Ошибка при отправке файла', error: e, stackTrace: stack);
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
