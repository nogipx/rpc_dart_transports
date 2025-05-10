import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования клиентского стриминга (поток запросов -> один ответ)
/// Демонстрирует как отправлять поток данных от клиента и получить агрегированный ответ
void main() async {
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

  // Создаем контракты для сервисов
  final demoContract = SimpleRpcServiceContract('DemoService');
  final streamContract = SimpleRpcServiceContract('StreamService');

  // Регистрируем контракты на сервере и клиенте
  print('Регистрируем контракты сервисов...');
  server.registerServiceContract(demoContract);
  server.registerServiceContract(streamContract);

  client.registerServiceContract(demoContract);
  client.registerServiceContract(streamContract);

  // Добавляем middleware для логирования
  server.addMiddleware(DebugMiddleware(id: 'server'));
  client.addMiddleware(DebugMiddleware(id: 'client'));

  try {
    // Регистрируем методы на сервере
    print('Регистрируем методы на сервере...');
    registerServerMethods(server);

    // Демонстрация агрегации числовых данных
    await demonstrateNumberAggregation(client);

    // Демонстрация обработки сложных объектов
    await demonstrateComplexObjects(client);

    // Демонстрация потоковой передачи блоков данных
    await demonstrateDataBlocks(client);

    // Демонстрация обработки ошибок
    await demonstrateErrorHandling(client);
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

/// Регистрация методов на сервере
void registerServerMethods(RpcEndpoint server) {
  // 1. Метод агрегации чисел
  server
      .clientStreaming('DemoService', 'aggregateNumbers')
      .register<RpcInt, RpcMap>(
        handler: (stream) async {
          print('Сервер начал обработку потока чисел');

          int sum = 0;
          int count = 0;
          int min = 0;
          int max = 0;
          bool firstValue = true;

          await for (final number in stream) {
            final value = number.value;

            // Инициализируем min/max при первом значении
            if (firstValue) {
              min = value;
              max = value;
              firstValue = false;
            }

            count++;
            sum += value;
            min = value < min ? value : min;
            max = value > max ? value : max;

            print('  Получено число #$count: $value');
          }

          print('Сервер завершил обработку $count чисел');

          // Формируем ответ со статистикой
          return RpcMap({
            'count': RpcInt(count),
            'sum': RpcInt(sum),
            'average': RpcDouble(count > 0 ? sum / count : 0),
            'min': RpcInt(min),
            'max': RpcInt(max),
          });
        },
        requestParser: RpcInt.fromJson,
        responseParser: RpcMap.fromJson,
      );

  // 2. Обработка сложных объектов
  server
      .clientStreaming('DemoService', 'processItems')
      .register<Item, ProcessingSummary>(
        handler: (stream) async {
          print('Сервер начал обработку потока объектов');

          final List<Item> items = [];
          int totalValue = 0;

          await for (final item in stream) {
            items.add(item);
            totalValue += item.value;
            print('  Получен объект: ${item.name} (${item.value})');
          }

          print('Сервер завершил обработку ${items.length} объектов');

          return ProcessingSummary(
            processedCount: items.length,
            totalValue: totalValue,
            names: items.map((e) => e.name).toList(),
            timestamp: DateTime.now().toIso8601String(),
          );
        },
        requestParser: Item.fromJson,
        responseParser: ProcessingSummary.fromJson,
      );

  // 3. Обработка блоков данных
  server
      .clientStreaming('StreamService', 'processDataBlocks')
      .register<DataBlock, DataBlockResult>(
        handler: (stream) async {
          print('Сервер начал обработку блоков данных');

          int blockCount = 0;
          int totalSize = 0;
          String? metadata;

          await for (final block in stream) {
            blockCount++;
            totalSize += block.data.length;

            // Сохраняем метаданные из первого блока
            if (metadata == null && block.metadata.isNotEmpty) {
              metadata = block.metadata;
            }

            print('  Получен блок #${block.index}: ${block.data.length} байт');

            // Имитация обработки больших блоков
            if (block.data.length > 1000) {
              await Future.delayed(Duration(milliseconds: 50));
            }
          }

          print(
              'Сервер завершил обработку $blockCount блоков данных, всего: $totalSize байт');

          return DataBlockResult(
            blockCount: blockCount,
            totalSize: totalSize,
            metadata: metadata ?? 'no-metadata',
            processingTime: DateTime.now().toIso8601String(),
          );
        },
        requestParser: DataBlock.fromJson,
        responseParser: DataBlockResult.fromJson,
      );

  // 4. Метод с проверкой данных, который может выбросить ошибку
  server
      .clientStreaming('StreamService', 'validateInput')
      .register<RpcString, ValidationResult>(
        handler: (stream) async {
          print('Сервер начал валидацию входных данных');

          final List<String> errors = [];
          int processed = 0;

          await for (final item in stream) {
            processed++;
            final value = item.value;
            print('  Проверяется элемент #$processed: $value');

            if (value.isEmpty) {
              errors.add('Элемент #$processed: Пустое значение');
            } else if (value == 'error') {
              // Демонстрация обработки ошибок: выбрасываем исключение
              throw Exception('Обнаружено запрещенное значение');
            } else if (value.length < 3) {
              errors.add('Элемент #$processed: Значение слишком короткое');
            }
          }

          print(
              'Сервер завершил валидацию: $processed элементов, ${errors.length} ошибок');

          return ValidationResult(
            valid: errors.isEmpty,
            processedCount: processed,
            errors: errors,
          );
        },
        requestParser: RpcString.fromJson,
        responseParser: ValidationResult.fromJson,
      );
}

/// Демонстрация агрегации числовых данных
Future<void> demonstrateNumberAggregation(RpcEndpoint client) async {
  print('\n=== Демонстрация агрегации числовых данных ===\n');

  // Создаем клиентский стрим для отправки чисел
  final stream = client
      .clientStreaming('DemoService', 'aggregateNumbers')
      .openClientStream<RpcInt, RpcMap>(
        responseParser: RpcMap.fromJson,
      );

  print('Отправляем последовательность чисел...');

  // Отправляем числа в поток
  for (int i = 1; i <= 5; i++) {
    print('Клиент отправляет число: $i');
    stream.controller.add(RpcInt(i));
    await Future.delayed(Duration(milliseconds: 100));
  }

  // Завершаем поток и ждем ответа
  print('Клиент завершает поток');
  stream.controller.close();
  final result = await stream.response;

  // Обрабатываем результат
  print('\nПолучен результат агрегации:');
  print('  Количество: ${result['count']}');
  print('  Сумма: ${result['sum']}');
  print('  Среднее: ${result['average']}');
  print('  Минимум: ${result['min']}');
  print('  Максимум: ${result['max']}');
}

/// Демонстрация обработки сложных объектов
Future<void> demonstrateComplexObjects(RpcEndpoint client) async {
  print('\n=== Демонстрация обработки сложных объектов ===\n');

  // Создаем клиентский стрим для отправки объектов
  final stream = client
      .clientStreaming('DemoService', 'processItems')
      .openClientStream<Item, ProcessingSummary>(
        responseParser: ProcessingSummary.fromJson,
      );

  print('Отправляем объекты в поток...');

  // Список тестовых объектов
  final items = [
    Item(name: 'Item1', value: 10, active: true),
    Item(name: 'Item2', value: 20, active: false),
    Item(name: 'Item3', value: 30, active: true),
    Item(name: 'Item4', value: 40, active: true),
  ];

  // Отправляем объекты в поток
  for (final item in items) {
    print('Клиент отправляет объект: ${item.name}');
    stream.controller.add(item);
    await Future.delayed(Duration(milliseconds: 150));
  }

  // Завершаем поток и ждем ответа
  print('Клиент завершает поток');
  stream.controller.close();
  final result = await stream.response;

  // Обрабатываем результат
  print('\nПолучен результат обработки:');
  print('  Обработано объектов: ${result.processedCount}');
  print('  Общее значение: ${result.totalValue}');
  print('  Имена объектов: ${result.names.join(', ')}');
  print('  Время обработки: ${result.timestamp}');
}

/// Демонстрация потоковой передачи блоков данных
Future<void> demonstrateDataBlocks(RpcEndpoint client) async {
  print('\n=== Демонстрация передачи блоков данных ===\n');

  // Создаем клиентский стрим для отправки блоков данных
  final stream = client
      .clientStreaming('StreamService', 'processDataBlocks')
      .openClientStream<DataBlock, DataBlockResult>(
        responseParser: DataBlockResult.fromJson,
      );

  print('Передаем блоки данных...');

  // Имитируем отправку нескольких блоков данных разного размера
  final blocks = [
    DataBlock(
        index: 1,
        data: List.generate(500, (i) => i % 256),
        metadata: 'Первый блок с метаданными'),
    DataBlock(index: 2, data: List.generate(800, (i) => i % 256), metadata: ''),
    DataBlock(
        index: 3, data: List.generate(1200, (i) => i % 256), metadata: ''),
    DataBlock(index: 4, data: List.generate(300, (i) => i % 256), metadata: ''),
  ];

  // Отправляем блоки в поток
  for (final block in blocks) {
    print('Клиент отправляет блок #${block.index}: ${block.data.length} байт');
    stream.controller.add(block);
    await Future.delayed(Duration(milliseconds: 200));
  }

  // Завершаем поток и ждем ответа
  print('Клиент завершает поток');
  stream.controller.close();
  final result = await stream.response;

  // Обрабатываем результат
  print('\nПолучен результат обработки блоков:');
  print('  Количество блоков: ${result.blockCount}');
  print('  Общий размер: ${result.totalSize} байт');
  print('  Метаданные: ${result.metadata}');
  print('  Время обработки: ${result.processingTime}');
}

/// Демонстрация обработки ошибок
Future<void> demonstrateErrorHandling(RpcEndpoint client) async {
  print('\n=== Демонстрация обработки ошибок ===\n');

  // Сначала успешный случай
  print('1. Успешная валидация:');

  final validStream = client
      .clientStreaming('StreamService', 'validateInput')
      .openClientStream<RpcString, ValidationResult>(
        responseParser: ValidationResult.fromJson,
      );

  // Отправляем валидные значения
  validStream.controller.add(RpcString('valid1'));
  await Future.delayed(Duration(milliseconds: 100));
  validStream.controller.add(RpcString('valid2'));
  await Future.delayed(Duration(milliseconds: 100));

  // Закрываем поток и получаем результат
  validStream.controller.close();
  final validResult = await validStream.response;

  print('\nРезультат успешной валидации:');
  print('  Валидно: ${validResult.valid}');
  print('  Обработано: ${validResult.processedCount}');
  if (validResult.errors.isNotEmpty) {
    print('  Ошибки: ${validResult.errors.join(', ')}');
  }

  // Затем случай с ошибками валидации, но без исключения
  print('\n2. Валидация с ошибками:');

  final invalidStream = client
      .clientStreaming('StreamService', 'validateInput')
      .openClientStream<RpcString, ValidationResult>(
        responseParser: ValidationResult.fromJson,
      );

  // Отправляем невалидные значения
  invalidStream.controller.add(RpcString('valid'));
  await Future.delayed(Duration(milliseconds: 100));
  invalidStream.controller.add(RpcString('')); // Пустая строка
  await Future.delayed(Duration(milliseconds: 100));
  invalidStream.controller.add(RpcString('ok')); // Короткая строка
  await Future.delayed(Duration(milliseconds: 100));

  // Закрываем поток и получаем результат
  invalidStream.controller.close();
  final invalidResult = await invalidStream.response;

  print('\nРезультат валидации с ошибками:');
  print('  Валидно: ${invalidResult.valid}');
  print('  Обработано: ${invalidResult.processedCount}');
  print('  Ошибки: ${invalidResult.errors.join('\n             ')}');

  // Наконец, случай с исключением
  print('\n3. Валидация с исключением:');

  final errorStream = client
      .clientStreaming('StreamService', 'validateInput')
      .openClientStream<RpcString, ValidationResult>(
        responseParser: ValidationResult.fromJson,
      );

  try {
    // Отправляем значение, вызывающее исключение
    errorStream.controller.add(RpcString('valid'));
    await Future.delayed(Duration(milliseconds: 100));
    errorStream.controller.add(RpcString('error')); // Вызовет исключение
    await Future.delayed(Duration(milliseconds: 100));

    // Закрываем поток и пытаемся получить результат
    errorStream.controller.close();
    print('Этот код не должен выполниться');
  } catch (e) {
    print('\nПоймано исключение: $e');
  }
}

/// Простой класс объекта
class Item implements IRpcSerializableMessage {
  final String name;
  final int value;
  final bool active;

  Item({required this.name, required this.value, required this.active});

  @override
  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'active': active,
      };

  static Item fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      value: json['value'] as int,
      active: json['active'] as bool,
    );
  }
}

/// Класс с результатом обработки
class ProcessingSummary implements IRpcSerializableMessage {
  final int processedCount;
  final int totalValue;
  final List<String> names;
  final String timestamp;

  ProcessingSummary({
    required this.processedCount,
    required this.totalValue,
    required this.names,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
        'processedCount': processedCount,
        'totalValue': totalValue,
        'names': names,
        'timestamp': timestamp,
      };

  static ProcessingSummary fromJson(Map<String, dynamic> json) {
    return ProcessingSummary(
      processedCount: json['processedCount'] as int,
      totalValue: json['totalValue'] as int,
      names: (json['names'] as List<dynamic>).cast<String>(),
      timestamp: json['timestamp'] as String,
    );
  }
}

/// Класс блока данных
class DataBlock implements IRpcSerializableMessage {
  final int index;
  final List<int> data;
  final String metadata;

  DataBlock({
    required this.index,
    required this.data,
    required this.metadata,
  });

  @override
  Map<String, dynamic> toJson() => {
        'index': index,
        'data': data,
        'metadata': metadata,
      };

  static DataBlock fromJson(Map<String, dynamic> json) {
    return DataBlock(
      index: json['index'] as int,
      data: (json['data'] as List<dynamic>).cast<int>(),
      metadata: json['metadata'] as String,
    );
  }
}

/// Класс результата обработки блоков данных
class DataBlockResult implements IRpcSerializableMessage {
  final int blockCount;
  final int totalSize;
  final String metadata;
  final String processingTime;

  DataBlockResult({
    required this.blockCount,
    required this.totalSize,
    required this.metadata,
    required this.processingTime,
  });

  @override
  Map<String, dynamic> toJson() => {
        'blockCount': blockCount,
        'totalSize': totalSize,
        'metadata': metadata,
        'processingTime': processingTime,
      };

  static DataBlockResult fromJson(Map<String, dynamic> json) {
    return DataBlockResult(
      blockCount: json['blockCount'] as int,
      totalSize: json['totalSize'] as int,
      metadata: json['metadata'] as String,
      processingTime: json['processingTime'] as String,
    );
  }
}

/// Класс результата валидации
class ValidationResult implements IRpcSerializableMessage {
  final bool valid;
  final int processedCount;
  final List<String> errors;

  ValidationResult({
    required this.valid,
    required this.processedCount,
    required this.errors,
  });

  @override
  Map<String, dynamic> toJson() => {
        'valid': valid,
        'processedCount': processedCount,
        'errors': errors,
      };

  static ValidationResult fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      valid: json['valid'] as bool,
      processedCount: json['processedCount'] as int,
      errors: (json['errors'] as List<dynamic>).cast<String>(),
    );
  }
}
