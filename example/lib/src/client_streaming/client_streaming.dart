import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'client_streaming_contract.dart';
import 'client_streaming_models.dart';

/// Пример использования клиентского стриминга (поток запросов -> один ответ)
/// Демонстрирует как отправлять поток данных от клиента и получить агрегированный ответ
Future<void> main() async {
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
  server.addMiddleware(DebugMiddleware(id: 'server'));
  // client.addMiddleware(DebugMiddleware(id: 'client'));

  try {
    // Создаем серверные реализации сервисов
    final demoService = ServerDemoService();
    final streamService = ServerStreamService();
    server.registerServiceContract(demoService);
    server.registerServiceContract(streamService);

    // Создаем клиентские реализации сервисов
    final clientDemoService = ClientDemoService(client);
    final clientStreamService = ClientStreamService(client);
    client.registerServiceContract(clientDemoService);
    client.registerServiceContract(clientStreamService);

    // Демонстрация агрегации числовых данных
    // await demonstrateNumberAggregation(clientDemoService);

    // Демонстрация обработки сложных объектов
    // await demonstrateComplexObjects(clientDemoService);

    // Демонстрация потоковой передачи блоков данных
    await demonstrateDataBlocks(clientStreamService);

    // Демонстрация обработки ошибок
    // await demonstrateErrorHandling(clientStreamService);
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

/// Демонстрация агрегации числовых данных
Future<void> demonstrateNumberAggregation(ClientDemoService demoService) async {
  print('\n=== Демонстрация агрегации числовых данных ===\n');

  // Создаем клиентский стрим для отправки чисел
  final numberStream = await demoService.aggregateNumbers(
    RpcClientStreamParams<RpcInt, AggregationResult>(metadata: {}, streamId: 'aggregate-stream'),
  );
  final controller = numberStream.controller;
  if (controller == null) {
    throw RpcInvalidArgumentException(
      'Сервер не может обработать входящий поток',
      details: {'contract': 'DemoService', 'method': 'aggregateNumbers'},
    );
  }
  print('Отправляем последовательность чисел...');

  // Отправляем числа в поток
  for (int i = 1; i <= 5; i++) {
    print('Клиент отправляет число: $i');
    controller.add(RpcInt(i));
    await Future.delayed(Duration(milliseconds: 100));
  }

  // Завершаем поток и ждем ответа
  print('Клиент завершает поток');
  controller.close();
  final result = await numberStream.response;

  // Обрабатываем результат
  print('\nПолучен результат агрегации:');
  print('  Количество: ${result?.count}');
  print('  Сумма: ${result?.sum}');
  print('  Среднее: ${result?.average}');
  print('  Минимум: ${result?.min}');
  print('  Максимум: ${result?.max}');
}

/// Демонстрация обработки сложных объектов
Future<void> demonstrateComplexObjects(ClientDemoService demoService) async {
  print('\n=== Демонстрация обработки сложных объектов ===\n');

  // Создаем клиентский стрим для отправки объектов
  final itemStream = await demoService.processItems(
    RpcClientStreamParams<SerializableItem, ProcessingSummary>(
      metadata: {},
      streamId: 'process-stream',
    ),
  );
  final controller = itemStream.controller;
  if (controller == null) {
    throw RpcInvalidArgumentException(
      'Сервер не может обработать входящий поток',
      details: {'contract': 'DemoService', 'method': 'processItems'},
    );
  }

  print('Отправляем объекты в поток...');

  // Список тестовых объектов
  final items = [
    SerializableItem(name: 'Item1', value: 10, active: true),
    SerializableItem(name: 'Item2', value: 20, active: false),
    SerializableItem(name: 'Item3', value: 30, active: true),
    SerializableItem(name: 'Item4', value: 40, active: true),
  ];

  // Отправляем объекты в поток
  for (final item in items) {
    print('Клиент отправляет объект: ${item.name}');
    controller.add(item);
    await Future.delayed(Duration(milliseconds: 400));
  }

  // Завершаем поток и ждем ответа
  print('Клиент завершает поток');
  controller.close();
  final result = await itemStream.response;

  // Обрабатываем результат
  print('\nПолучен результат обработки:');
  print('  Обработано объектов: ${result?.processedCount}');
  print('  Общее значение: ${result?.totalValue}');
  print('  Имена объектов: ${result?.names.join(', ')}');
  print('  Время обработки: ${result?.timestamp}');
}

/// Демонстрация потоковой передачи блоков данных
Future<void> demonstrateDataBlocks(ClientStreamService streamService) async {
  print('\n=== Демонстрация передачи блоков данных ===\n');

  // Имитируем отправку нескольких блоков данных разного размера
  final blocks = [
    DataBlock(
      index: 1,
      data: List.generate(500, (i) => i % 256),
      metadata: 'Первый блок с метаданными',
    ),
    DataBlock(index: 2, data: List.generate(800, (i) => i % 256), metadata: ''),
    DataBlock(index: 3, data: List.generate(1200, (i) => i % 256), metadata: ''),
    DataBlock(index: 4, data: List.generate(300, (i) => i % 256), metadata: ''),
  ];

  // Создаем клиентский стрим для отправки блоков данных
  final processStream = await streamService.processDataBlocks(
    RpcClientStreamParams<DataBlock, DataBlockResult>(metadata: {}, streamId: 'process-stream'),
  );
  final controller = processStream.controller;
  if (controller == null) {
    throw RpcInvalidArgumentException('Сервер не может обработать входящий поток');
  }

  for (final block in blocks) {
    print('Клиент отправляет блок #${block.index}: ${block.data.length} байт');
    controller.add(block);
    await Future.delayed(Duration(milliseconds: 150));
  }

  controller.close();
  final result = await processStream.response;

  print('Передаем блоки данных...');

  // Обрабатываем результат
  print('\nПолучен результат обработки блоков:');
  print('  Количество блоков: ${result?.blockCount}');
  print('  Общий размер: ${result?.totalSize} байт');
  print('  Метаданные: ${result?.metadata}');
  print('  Время обработки: ${result?.processingTime}');
}

/// Демонстрация обработки ошибок
Future<void> demonstrateErrorHandling(ClientStreamService streamService) async {
  print('\n=== Демонстрация обработки ошибок ===\n');

  // Сначала успешный случай
  print('1. Успешная валидация:');

  final validStream = await streamService.validateInput(
    RpcClientStreamParams<RpcString, ValidationResult>(metadata: {}, streamId: 'valid-stream'),
  );
  final validController = validStream.controller;
  if (validController == null) {
    throw RpcInvalidArgumentException(
      'Сервер не может обработать входящий поток',
      details: {'contract': 'StreamService', 'method': 'validateInput'},
    );
  }

  // Отправляем валидные значения
  validController.add(RpcString('valid1'));
  await Future.delayed(Duration(milliseconds: 100));
  validController.add(RpcString('valid2'));
  await Future.delayed(Duration(milliseconds: 100));

  // Закрываем поток и получаем результат
  validController.close();
  final validResult = await validStream.response;

  print('\nРезультат успешной валидации:');
  print('  Валидно: ${validResult?.valid}');
  print('  Обработано: ${validResult?.processedCount}');
  if (validResult?.errors.isNotEmpty ?? false) {
    print('  Ошибки: ${validResult?.errors.join(', ')}');
  }

  // Затем случай с ошибками валидации, но без исключения
  print('\n2. Валидация с ошибками:');

  final invalidStream = await streamService.validateInput(
    RpcClientStreamParams<RpcString, ValidationResult>(metadata: {}, streamId: 'error-stream'),
  );
  final invalidController = invalidStream.controller;
  if (invalidController == null) {
    throw RpcInvalidArgumentException('Сервер не может обработать входящий поток');
  }

  // Отправляем невалидные значения
  invalidController.add(RpcString('valid'));
  await Future.delayed(Duration(milliseconds: 100));
  invalidController.add(RpcString('')); // Пустая строка
  await Future.delayed(Duration(milliseconds: 100));
  invalidController.add(RpcString('ok')); // Короткая строка
  await Future.delayed(Duration(milliseconds: 100));

  // Закрываем поток и получаем результат
  invalidController.close();
  final invalidResult = await invalidStream.response;

  print('\nРезультат валидации с ошибками:');
  print('  Валидно: ${invalidResult?.valid}');
  print('  Обработано: ${invalidResult?.processedCount}');
  print('  Ошибки: ${invalidResult?.errors.join('\n             ')}');

  // Наконец, случай с исключением
  print('\n3. Валидация с исключением:');

  final errorStream = await streamService.validateInput(
    RpcClientStreamParams<RpcString, ValidationResult>(metadata: {}, streamId: 'exception-stream'),
  );
  final errorController = errorStream.controller;
  if (errorController == null) {
    throw RpcInvalidArgumentException('Сервер не может обработать входящий поток');
  }

  try {
    // Отправляем значение, вызывающее исключение
    errorController.add(RpcString('valid'));
    await Future.delayed(Duration(milliseconds: 100));
    errorController.add(RpcString('error')); // Вызовет исключение
    await Future.delayed(Duration(milliseconds: 100));

    // Закрываем поток и пытаемся получить результат
    errorController.close();
    print('Этот код не должен выполниться');
  } catch (e) {
    print('\nПоймано исключение: $e');
  }
}
