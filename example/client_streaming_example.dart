import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования клиентского стриминга (поток запросов -> один ответ)
void main() async {
  print('=== Пример клиентского стриминга ===\n');

  // Создаем транспорты в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
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

  // Создаем отдельные контракты для сервера и клиента
  final mathContract = SimpleRpcServiceContract('MathService');
  final dataContract = SimpleRpcServiceContract('DataService');
  final fileContract = SimpleRpcServiceContract('FileService');
  final validationContract = SimpleRpcServiceContract('ValidationService');

  // Регистрируем контракты на сервере и клиенте
  print('Регистрируем контракты сервисов...');
  server.registerServiceContract(mathContract);
  server.registerServiceContract(dataContract);
  server.registerServiceContract(fileContract);
  server.registerServiceContract(validationContract);

  client.registerServiceContract(mathContract);
  client.registerServiceContract(dataContract);
  client.registerServiceContract(fileContract);
  client.registerServiceContract(validationContract);

  // Добавляем middleware для логирования
  server.addMiddleware(DebugMiddleware(id: 'server'));
  client.addMiddleware(DebugMiddleware(id: 'client'));

  server.addMiddleware(
    RpcMiddlewareWrapper(
      debugLabel: 'ServerLogger',
      onStreamDataHandler: (service, method, data, streamId, direction) {
        if (direction == RpcDataDirection.fromRemote) {
          print('Сервер получил данные в поток: $data');
        }
        return data;
      },
    ),
  );

  try {
    // Проверяем регистрацию контрактов
    final serverMathService = server.getServiceContract('MathService');
    print(
        'MathService зарегистрирован на сервере: ${serverMathService != null}');
    if (serverMathService != null) {
      print('  Методы в контракте: ${serverMathService.methods.length}');
      for (final method in serverMathService.methods) {
        print('  - ${method.methodName} (${method.methodType})');
      }
    }

    // Регистрируем методы на сервере
    print('Регистрируем методы на сервере...');
    registerServerMethods(server);

    // Регистрируем методы на клиенте
    print('Регистрируем методы на клиенте...');
    registerClientMethods(client);

    // Проверяем методы после регистрации
    final serverMathServiceAfter = server.getServiceContract('MathService');
    print('MathService после регистрации методов:');
    if (serverMathServiceAfter != null) {
      print('  Методы в контракте: ${serverMathServiceAfter.methods.length}');
      for (final method in serverMathServiceAfter.methods) {
        print('  - ${method.methodName} (${method.methodType})');
      }
    }

    // Демонстрация суммирования чисел
    await demonstrateSumming(client);

    // Демонстрация сбора и обработки данных
    await demonstrateDataCollection(client);

    // Демонстрация загрузки файла
    await demonstrateFileUpload(client);

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
  // Затем регистрируем его в эндпоинте
  server.clientStreaming('MathService', 'sum').register<RpcNum, RpcInt>(
        handler: (stream) async {
          print('Сервер начал обработку потока чисел');
          int sum = 0;

          await for (final number in stream) {
            print('  Получено число: ${number.value}');
            sum += number.value.toInt();
          }

          print('Сервер закончил суммирование: $sum');
          return RpcInt(sum);
        },
        requestParser: RpcNum.fromJson,
        responseParser: RpcInt.fromJson,
      );

  // 2. Сбор и объединение данных
  server
      .clientStreaming('DataService', 'collectData')
      .register<DataItem, DataSummary>(
        handler: (stream) async {
          print('Сервер начал сбор данных');

          final items = <DataItem>[];
          int totalSize = 0;

          await for (final item in stream) {
            items.add(item);
            totalSize += item.size;
            print('  Получен элемент данных: ${item.name} (${item.size} байт)');
          }

          final summary = DataSummary(
            itemCount: items.length,
            totalSize: totalSize,
            names: items.map((e) => e.name).toList(),
          );

          print('Сервер завершил сбор данных: ${summary.itemCount} элементов');
          return summary;
        },
        requestParser: DataItem.fromJson,
        responseParser: DataSummary.fromJson,
      );

  // 3. Загрузка файла (имитация)
  server
      .clientStreaming('FileService', 'uploadFile')
      .register<FileChunk, UploadResult>(
        handler: (stream) async {
          print('Сервер начал прием файла');

          String? fileName;
          String? fileType;
          int totalChunks = 0;
          int totalBytes = 0;

          await for (final chunk in stream) {
            if (fileName == null) {
              fileName = chunk.fileName;
              fileType = chunk.fileType;
            }

            totalChunks++;
            totalBytes += chunk.data.length;

            print('  Получен чанк ${chunk.chunkIndex}/${chunk.totalChunks} '
                '(${chunk.data.length} байт)');

            // Имитация обработки для долгих чанков
            if (chunk.data.length > 1000) {
              await Future.delayed(Duration(milliseconds: 100));
            }
          }

          print(
              'Сервер завершил прием файла: $totalBytes байт в $totalChunks чанках');

          return UploadResult(
            fileName: fileName ?? 'unknown',
            fileType: fileType ?? 'application/octet-stream',
            fileSize: totalBytes,
            uploadedChunks: totalChunks,
            success: true,
            message: 'Файл успешно загружен',
          );
        },
        requestParser: FileChunk.fromJson,
        responseParser: UploadResult.fromJson,
      );

  // 4. Метод с проверкой данных и возможной ошибкой
  server
      .clientStreaming('ValidationService', 'validateData')
      .register<RpcString, ValidationResult>(
        handler: (stream) async {
          print('Сервер начал валидацию данных');

          final errors = <String>[];
          int processedItems = 0;

          await for (final item in stream) {
            processedItems++;
            print('  Валидация элемента: ${item.value}');

            if (item.value.isEmpty) {
              errors.add(
                  'Элемент #$processedItems: значение не может быть пустым');
            } else if (item.value == 'error') {
              throw Exception('Обнаружено запрещенное значение: ${item.value}');
            } else if (item.value.length < 3) {
              errors.add('Элемент #$processedItems: значение слишком короткое');
            }
          }

          print(
              'Сервер завершил валидацию: $processedItems элементов, ${errors.length} ошибок');

          return ValidationResult(
            valid: errors.isEmpty,
            processedItems: processedItems,
            errors: errors,
          );
        },
        requestParser: RpcString.fromJson,
        responseParser: ValidationResult.fromJson,
      );
}

/// Регистрация методов на клиенте
void registerClientMethods(RpcEndpoint client) {
  // 1. Суммирование чисел
  client.clientStreaming('MathService', 'sum').register<RpcNum, RpcInt>(
        handler: (stream) async {
          // Клиент обычно не обрабатывает вызовы, но мы всё равно
          // регистрируем обработчики для полноты контракта
          int sum = 0;
          await for (final number in stream) {
            sum += number.value.toInt();
          }
          return RpcInt(sum);
        },
        requestParser: RpcNum.fromJson,
        responseParser: RpcInt.fromJson,
      );

  // 2. Сбор и объединение данных
  client
      .clientStreaming('DataService', 'collectData')
      .register<DataItem, DataSummary>(
        handler: (stream) async {
          final items = <DataItem>[];
          int totalSize = 0;

          await for (final item in stream) {
            items.add(item);
            totalSize += item.size;
          }

          return DataSummary(
            itemCount: items.length,
            totalSize: totalSize,
            names: items.map((e) => e.name).toList(),
          );
        },
        requestParser: DataItem.fromJson,
        responseParser: DataSummary.fromJson,
      );

  // 3. Загрузка файла
  client
      .clientStreaming('FileService', 'uploadFile')
      .register<FileChunk, UploadResult>(
        handler: (stream) async {
          int totalChunks = 0;
          int totalBytes = 0;
          String? fileName;

          await for (final chunk in stream) {
            fileName ??= chunk.fileName;
            totalChunks++;
            totalBytes += chunk.data.length;
          }

          return UploadResult(
            fileName: fileName ?? 'unknown',
            fileType: 'application/octet-stream',
            fileSize: totalBytes,
            uploadedChunks: totalChunks,
            success: true,
            message: 'Файл успешно загружен (клиент)',
          );
        },
        requestParser: FileChunk.fromJson,
        responseParser: UploadResult.fromJson,
      );

  // 4. Валидация данных
  client
      .clientStreaming('ValidationService', 'validateData')
      .register<RpcString, ValidationResult>(
        handler: (stream) async {
          final errors = <String>[];
          int processedItems = 0;

          await for (final item in stream) {
            processedItems++;
            if (item.value.isEmpty || item.value.length < 3) {
              errors.add('Ошибка валидации: ${item.value}');
            }
          }

          return ValidationResult(
            valid: errors.isEmpty,
            processedItems: processedItems,
            errors: errors,
          );
        },
        requestParser: RpcString.fromJson,
        responseParser: ValidationResult.fromJson,
      );
}

/// Демонстрация суммирования чисел
Future<void> demonstrateSumming(RpcEndpoint client) async {
  print('\n--- Суммирование потока чисел ---');

  // Открываем клиентский поток
  final clientStream = client
      .clientStreaming('MathService', 'sum')
      .openClientStream<RpcNum, RpcInt>(
        responseParser: RpcInt.fromJson,
        requestParser: RpcNum.fromJson,
      );

  // Отправляем числа в поток
  print('Отправляем числа в поток:');
  final numbers = [5, 10, 15, 20, 25];

  for (final number in numbers) {
    print('  Отправка: $number');
    clientStream.controller.add(RpcNum(number));
    await Future.delayed(Duration(milliseconds: 200));
  }

  // Закрываем поток и получаем результат
  print('Закрываем поток и ждем результат...');
  clientStream.controller.close();

  final result = await clientStream.response;
  print('Получен результат: сумма = ${result.value}');
}

/// Демонстрация сбора и обработки данных
Future<void> demonstrateDataCollection(RpcEndpoint client) async {
  print('\n--- Сбор и обработка данных ---');

  // Открываем клиентский поток
  final clientStream = client
      .clientStreaming('DataService', 'collectData')
      .openClientStream<DataItem, DataSummary>(
        responseParser: DataSummary.fromJson,
        requestParser: DataItem.fromJson,
      );

  // Отправляем данные в поток
  print('Отправляем данные для сбора:');

  final dataItems = [
    DataItem(name: 'config.json', size: 256),
    DataItem(name: 'image.png', size: 1024),
    DataItem(name: 'document.txt', size: 512),
    DataItem(name: 'settings.xml', size: 128),
  ];

  for (final item in dataItems) {
    print('  Отправка: ${item.name} (${item.size} байт)');
    clientStream.controller.add(item);
    await Future.delayed(Duration(milliseconds: 300));
  }

  // Закрываем поток и получаем результат
  print('Закрываем поток данных...');
  clientStream.controller.close();

  final summary = await clientStream.response;
  print('Получена сводка:');
  print('  Количество элементов: ${summary.itemCount}');
  print('  Общий размер: ${summary.totalSize} байт');
  print('  Имена элементов: ${summary.names.join(", ")}');
}

/// Демонстрация загрузки файла
Future<void> demonstrateFileUpload(RpcEndpoint client) async {
  print('\n--- Загрузка файла ---');

  // Открываем клиентский поток
  final clientStream = client
      .clientStreaming('FileService', 'uploadFile')
      .openClientStream<FileChunk, UploadResult>(
        responseParser: UploadResult.fromJson,
        requestParser: FileChunk.fromJson,
      );

  // Имитируем загрузку файла по частям
  print('Начинаем загрузку файла "example.dat":');

  // Генерируем данные для имитации файла
  final fileData = List.generate(5000, (i) => (i % 256));
  final chunkSize = 1024;
  final totalChunks = (fileData.length / chunkSize).ceil();

  for (var i = 0; i < totalChunks; i++) {
    final start = i * chunkSize;
    final end = (start + chunkSize < fileData.length)
        ? start + chunkSize
        : fileData.length;
    final chunkData = fileData.sublist(start, end);

    final chunk = FileChunk(
      fileName: 'example.dat',
      fileType: 'application/octet-stream',
      chunkIndex: i + 1,
      totalChunks: totalChunks,
      data: chunkData,
    );

    print('  Отправка чанка ${i + 1}/$totalChunks (${chunkData.length} байт)');
    clientStream.controller.add(chunk);

    // Имитируем задержку сети
    await Future.delayed(Duration(milliseconds: 200));
  }

  // Закрываем поток и получаем результат
  print('Завершаем загрузку файла...');
  clientStream.controller.close();

  final result = await clientStream.response;
  print('Получен результат загрузки:');
  print('  Успех: ${result.success}');
  print('  Сообщение: ${result.message}');
  print('  Размер файла: ${result.fileSize} байт');
  print('  Загружено чанков: ${result.uploadedChunks}');
}

/// Демонстрация обработки ошибок
Future<void> demonstrateErrorHandling(RpcEndpoint client) async {
  print('\n--- Валидация данных с обработкой ошибок ---');

  // 1. Сначала успешный кейс
  print('Отправка валидных данных:');

  final validStream = client
      .clientStreaming('ValidationService', 'validateData')
      .openClientStream<RpcString, ValidationResult>(
        responseParser: ValidationResult.fromJson,
        requestParser: RpcString.fromJson,
      );

  final validItems = ['item1', 'test', 'hello', 'world'];

  for (final value in validItems) {
    print('  Отправка: "$value"');
    validStream.controller.add(RpcString(value));
    await Future.delayed(Duration(milliseconds: 200));
  }

  print('Закрываем поток валидации...');
  validStream.controller.close();

  try {
    final validResult = await validStream.response;
    print('Результат валидации:');
    print('  Валидно: ${validResult.valid}');
    print('  Обработано элементов: ${validResult.processedItems}');
    print(
        '  Ошибки: ${validResult.errors.isEmpty ? "нет" : validResult.errors.join(", ")}');
  } catch (e) {
    print('  Ошибка: $e');
  }

  // 2. Теперь кейс с ошибкой
  print('\nОтправка невалидных данных с ошибкой:');

  final invalidStream = client
      .clientStreaming('ValidationService', 'validateData')
      .openClientStream<RpcString, ValidationResult>(
        responseParser: ValidationResult.fromJson,
        requestParser: RpcString.fromJson,
      );

  final invalidItems = ['good', 'ok', 'error', 'valid'];

  try {
    for (final value in invalidItems) {
      print('  Отправка: "$value"');
      invalidStream.controller.add(RpcString(value));
      await Future.delayed(Duration(milliseconds: 200));
    }

    print('Закрываем поток валидации...');
    invalidStream.controller.close();

    // Этот код не должен выполниться, так как произойдет ошибка
    await invalidStream.response;
    print('Этот код не должен выполниться');
  } catch (e) {
    print('  Перехвачена ошибка: $e');
  }
}

/// Элемент данных
class DataItem implements IRpcSerializableMessage {
  final String name;
  final int size;

  DataItem({required this.name, required this.size});

  @override
  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
      };

  static DataItem fromJson(Map<String, dynamic> json) {
    return DataItem(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Сводка по данным
class DataSummary implements IRpcSerializableMessage {
  final int itemCount;
  final int totalSize;
  final List<String> names;

  DataSummary({
    required this.itemCount,
    required this.totalSize,
    required this.names,
  });

  @override
  Map<String, dynamic> toJson() => {
        'itemCount': itemCount,
        'totalSize': totalSize,
        'names': names,
      };

  static DataSummary fromJson(Map<String, dynamic> json) {
    return DataSummary(
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      totalSize: (json['totalSize'] as num?)?.toInt() ?? 0,
      names:
          (json['names'] as List?)?.map((e) => e as String? ?? '').toList() ??
              [],
    );
  }
}

/// Чанк файла
class FileChunk implements IRpcSerializableMessage {
  final String fileName;
  final String fileType;
  final int chunkIndex;
  final int totalChunks;
  final List<int> data;

  FileChunk({
    required this.fileName,
    required this.fileType,
    required this.chunkIndex,
    required this.totalChunks,
    required this.data,
  });

  @override
  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'fileType': fileType,
        'chunkIndex': chunkIndex,
        'totalChunks': totalChunks,
        'data': data,
      };

  static FileChunk fromJson(Map<String, dynamic> json) {
    return FileChunk(
      fileName: json['fileName'] as String? ?? 'unknown',
      fileType: json['fileType'] as String? ?? 'application/octet-stream',
      chunkIndex: (json['chunkIndex'] as num?)?.toInt() ?? 0,
      totalChunks: (json['totalChunks'] as num?)?.toInt() ?? 1,
      data: (json['data'] as List?)
              ?.map((e) => (e as num?)?.toInt() ?? 0)
              .toList() ??
          [],
    );
  }
}

/// Результат загрузки файла
class UploadResult implements IRpcSerializableMessage {
  final String fileName;
  final String fileType;
  final int fileSize;
  final int uploadedChunks;
  final bool success;
  final String message;

  UploadResult({
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadedChunks,
    required this.success,
    required this.message,
  });

  @override
  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'fileType': fileType,
        'fileSize': fileSize,
        'uploadedChunks': uploadedChunks,
        'success': success,
        'message': message,
      };

  static UploadResult fromJson(Map<String, dynamic> json) {
    return UploadResult(
      fileName: json['fileName'] as String? ?? 'unknown',
      fileType: json['fileType'] as String? ?? 'application/octet-stream',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      uploadedChunks: (json['uploadedChunks'] as num?)?.toInt() ?? 0,
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Результат валидации
class ValidationResult implements IRpcSerializableMessage {
  final bool valid;
  final int processedItems;
  final List<String> errors;

  ValidationResult({
    required this.valid,
    required this.processedItems,
    required this.errors,
  });

  @override
  Map<String, dynamic> toJson() => {
        'valid': valid,
        'processedItems': processedItems,
        'errors': errors,
      };

  static ValidationResult fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      valid: json['valid'] as bool? ?? false,
      processedItems: (json['processedItems'] as num?)?.toInt() ?? 0,
      errors:
          (json['errors'] as List?)?.map((e) => e as String? ?? '').toList() ??
              [],
    );
  }
}
