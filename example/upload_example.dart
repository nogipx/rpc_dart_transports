import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования клиентского стриминга для загрузки файла
Future<void> main() async {
  print('Запуск примера загрузки с клиентским стримингом...');

  // Создаем транспорты для клиента и сервера
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  print('Транспорты подключены');

  // Создаем сериализаторы
  final serializer = JsonSerializer();

  // Создаем эндпоинты
  final clientEndpoint = RpcEndpoint(clientTransport, serializer);
  final serverEndpoint = RpcEndpoint(serverTransport, serializer);
  print('Эндпоинты созданы');

  // Добавляем middleware для логирования
  clientEndpoint.addMiddleware(LoggingMiddleware(id: 'client'));
  serverEndpoint.addMiddleware(LoggingMiddleware(id: 'server'));

  // Создаем пустой контракт для FileService
  final serviceName = 'FileService';
  final methodName = 'uploadFile';

  final serviceContract = EmptyServiceContract(serviceName);

  // Регистрируем контракт
  serverEndpoint.registerServiceContract(serviceContract);
  clientEndpoint.registerServiceContract(serviceContract);
  print('Контракты зарегистрированы');

  // Регистрируем обработчик загрузки файла на сервере
  serverEndpoint
      .clientStreaming(serviceName, methodName)
      .register<FileChunk, UploadResult>(
        handler: (stream) async {
          print('Сервер: началась загрузка файла');

          int totalChars = 0;
          int chunks = 0;
          String fileName = '';

          // Обрабатываем каждый чанк
          await for (final chunk in stream) {
            chunks++;
            totalChars += chunk.data.length;

            // Сохраняем имя файла из первого чанка
            if (fileName.isEmpty && chunk.fileName.isNotEmpty) {
              fileName = chunk.fileName;
            }

            print(
                'Получен чанк #$chunks: ${chunk.data.length} символов: "${chunk.data}"');
          }

          print('Загрузка завершена: $totalChars символов в $chunks чанках');

          // Возвращаем результат загрузки
          return UploadResult(
            success: true,
            fileName: fileName,
            totalChars: totalChars,
            chunks: chunks,
          );
        },
        requestParser: FileChunk.fromJson,
        responseParser: UploadResult.fromJson,
      );

  print('Серверный обработчик загрузки зарегистрирован');

  try {
    // Имитируем загрузку файла
    final fileName = 'example.txt';
    final fileContent =
        'Это тестовый файл для загрузки через RPC с клиентским стримингом';
    final chunkSize = 10; // Размер чанка для демонстрации

    print(
        'Начинаем загрузку файла "$fileName" (${fileContent.length} символов)');

    // Открываем клиентский стрим для отправки файла
    final (uploadController, resultFuture) = clientEndpoint
        .clientStreaming(serviceName, methodName)
        .openClientStream<FileChunk, UploadResult>(
          responseParser: UploadResult.fromJson,
        );

    // Разбиваем файл на чанки и отправляем
    for (int i = 0; i < fileContent.length; i += chunkSize) {
      final end = (i + chunkSize > fileContent.length)
          ? fileContent.length
          : i + chunkSize;

      final chunk = fileContent.substring(i, end);
      final isLast = end == fileContent.length;

      uploadController.add(FileChunk(
        fileName: fileName,
        data: chunk,
        position: i,
        isLastChunk: isLast,
      ));

      print('Отправлен чанк: ${chunk.length} символов, позиция $i: "$chunk"');

      // Делаем небольшую паузу для имитации реальной загрузки
      await Future.delayed(Duration(milliseconds: 100));
    }

    // Закрываем контроллер, чтобы завершить поток
    await uploadController.close();
    print('Все чанки отправлены, ожидаем результат...');

    // Ожидаем результат загрузки
    final result = await resultFuture;

    // Выводим результат
    print('Загрузка завершена!');
    print('Файл: ${result.fileName}');
    print('Размер: ${result.totalChars} символов');
    print('Чанков: ${result.chunks}');
    print('Успех: ${result.success}');
  } catch (e, stackTrace) {
    print('Ошибка при выполнении примера: $e');
    print('Трассировка стека: $stackTrace');
  } finally {
    // Закрываем эндпоинты
    await clientEndpoint.close();
    await serverEndpoint.close();
    print('Эндпоинты закрыты');
  }

  print('Пример завершен!');
}

/// Пустой контракт для регистрации сервиса
class EmptyServiceContract
    implements IRpcServiceContract<RpcSerializableMessage> {
  final String _serviceName;

  EmptyServiceContract(this._serviceName);

  @override
  String get serviceName => _serviceName;

  @override
  dynamic getArgumentParser(
          RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>
              method) =>
      null;

  @override
  dynamic getHandler(
          RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>
              method) =>
      null;

  @override
  List<RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>>
      get methods => [];

  @override
  dynamic getResponseParser(
          RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>
              method) =>
      null;

  @override
  RpcMethodContract<Request, Response>? findMethodTyped<
          Request extends RpcSerializableMessage,
          Response extends RpcSerializableMessage>(String methodName) =>
      null;
}

/// Модель чанка файла
class FileChunk implements RpcSerializableMessage {
  final String fileName;
  final String data; // текстовые данные
  final int position;
  final bool isLastChunk;

  FileChunk({
    required this.fileName,
    required this.data,
    required this.position,
    required this.isLastChunk,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'data': data,
      'position': position,
      'isLastChunk': isLastChunk,
    };
  }

  static FileChunk fromJson(Map<String, dynamic> json) {
    return FileChunk(
      fileName: json['fileName'] as String,
      data: json['data'] as String,
      position: json['position'] as int,
      isLastChunk: json['isLastChunk'] as bool,
    );
  }

  @override
  String toString() =>
      'FileChunk(fileName: "$fileName", data: "${data.length} bytes")';
}

/// Модель результата загрузки
class UploadResult implements RpcSerializableMessage {
  final bool success;
  final String fileName;
  final int totalChars;
  final int chunks;

  UploadResult({
    required this.success,
    required this.fileName,
    required this.totalChars,
    required this.chunks,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'fileName': fileName,
      'totalChars': totalChars,
      'chunks': chunks,
    };
  }

  static UploadResult fromJson(Map<String, dynamic> json) {
    return UploadResult(
      success: json['success'] as bool,
      fileName: json['fileName'] as String,
      totalChars: json['totalChars'] as int,
      chunks: json['chunks'] as int,
    );
  }

  @override
  String toString() =>
      'UploadResult(success: $success, fileName: "$fileName", size: $totalChars bytes, chunks: $chunks)';
}
