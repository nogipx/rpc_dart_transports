import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Модели для тестирования клиентского стриминга
class FileChunk implements IRpcSerializableMessage {
  final String fileId;
  final int chunkIndex;
  final String data;
  final bool isLastChunk;

  FileChunk({
    required this.fileId,
    required this.chunkIndex,
    required this.data,
    this.isLastChunk = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'chunkIndex': chunkIndex,
        'data': data,
        'isLastChunk': isLastChunk,
      };

  static FileChunk fromJson(Map<String, dynamic> json) {
    print('Parsing FileChunk from: $json');
    return FileChunk(
      fileId: json['fileId'] as String,
      chunkIndex: json['chunkIndex'] as int,
      data: json['data'] as String,
      isLastChunk: json['isLastChunk'] as bool,
    );
  }
}

class UploadResult implements IRpcSerializableMessage {
  final String fileId;
  final int totalChunks;
  final int totalSize;
  final String status;

  UploadResult({
    required this.fileId,
    required this.totalChunks,
    required this.totalSize,
    required this.status,
  });

  @override
  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'totalChunks': totalChunks,
        'totalSize': totalSize,
        'status': status,
      };

  static UploadResult fromJson(Map<String, dynamic> json) {
    print('Parsing UploadResult from: $json');
    return UploadResult(
      fileId: json['fileId'] as String,
      totalChunks: json['totalChunks'] as int,
      totalSize: json['totalSize'] as int,
      status: json['status'] as String,
    );
  }
}

// Контракт сервиса для тестирования клиентского стриминга
abstract base class FileServiceContract
    extends RpcServiceContract<IRpcSerializableMessage> {
  FileServiceContract() : super('FileService');

  // Константа для имени метода
  static const String uploadFileMethod = 'uploadFile';

  @override
  void setup() {
    print('Setting up FileServiceContract');
    // Регистрируем метод клиентского стриминга
    addClientStreamingMethod<FileChunk, UploadResult>(
      methodName: uploadFileMethod,
      handler: uploadFile,
      argumentParser: FileChunk.fromJson,
      responseParser: UploadResult.fromJson,
    );
    super.setup();
  }

  // Метод, который должен быть реализован в конкретном классе
  ClientStreamingBidiStream<FileChunk, UploadResult> uploadFile();
}

// Серверная реализация сервиса файлов
base class ServerFileService extends FileServiceContract {
  @override
  ClientStreamingBidiStream<FileChunk, UploadResult> uploadFile() {
    print('Server: Creating file upload handler');

    // Создаем контроллер для чанков
    final requestController = StreamController<FileChunk>();
    // Создаем контроллер для ответов
    final responseController = StreamController<UploadResult>();

    // Запускаем обработку файла в отдельной зоне
    Future<void> processFile() async {
      int totalChunks = 0;
      int totalSize = 0;
      String? fileId;

      try {
        print('Server: Processing file chunks');
        print('Server: Starting to listen for chunks...');

        // Обрабатываем все входящие чанки
        await for (final chunk in requestController.stream) {
          print(
              'Server: Received chunk ${chunk.chunkIndex} for file ${chunk.fileId}');

          // Сохраняем ID файла из первого чанка
          fileId ??= chunk.fileId;
          totalChunks++;
          totalSize += chunk.data.length;

          // Проверка соответствия fileId для всех чанков
          if (fileId != chunk.fileId) {
            throw StateError('File ID mismatch between chunks');
          }
        }

        print(
            'Server: Stream completed, all chunks received. Total: $totalChunks');
        print('Server: Upload complete, generating result');

        // После обработки всех чанков возвращаем результат
        final result = UploadResult(
          fileId: fileId ?? 'unknown',
          totalChunks: totalChunks,
          totalSize: totalSize,
          status: 'completed',
        );

        print('Server: Sending result: ${result.toJson()}');
        // Отправляем результат через контроллер ответов
        responseController.add(result);
        print('Server: Result sent to response stream');
      } catch (e, stack) {
        print('Server error during file upload: $e');
        print('Stack trace: $stack');
        responseController.addError(e, stack);
      } finally {
        // Закрываем контроллер ответов
        await responseController.close();
        print('Server: Response stream closed');
      }
    }

    // Запускаем обработку файла
    processFile();

    // Создаем BidiStream с нашими контроллерами
    final bidiStream = BidiStream<FileChunk, UploadResult>(
      responseStream: responseController.stream,
      sendFunction: (chunk) {
        if (!requestController.isClosed) {
          requestController.add(chunk);
        }
      },
      finishTransferFunction: () async {
        // При завершении передачи закрываем входящий поток
        if (!requestController.isClosed) {
          await requestController.close();
        }
      },
      closeFunction: () async {
        // Закрываем оба контроллера при закрытии потока
        if (!requestController.isClosed) {
          await requestController.close();
        }
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );

    print('Server: BidiStream created, wrapping in ClientStreamingBidiStream');
    return ClientStreamingBidiStream<FileChunk, UploadResult>(bidiStream);
  }
}

// Клиентская реализация для вызова метода
base class ClientFileService extends FileServiceContract {
  final RpcEndpoint client;

  ClientFileService(this.client);

  @override
  ClientStreamingBidiStream<FileChunk, UploadResult> uploadFile() {
    print('Client: Creating file upload stream');
    return client
        .clientStreaming(
      serviceName: serviceName,
      methodName: FileServiceContract.uploadFileMethod,
    )
        .call<FileChunk, UploadResult>(
      responseParser: (data) {
        // Проверяем, что данные содержат правильные поля для UploadResult
        if (data.containsKey('fileId') && data.containsKey('totalChunks')) {
          return UploadResult.fromJson(data);
        }

        // Если не удается определить тип, пытаемся использовать UploadResult по умолчанию
        print('Парсим ответ из неизвестных данных: $data');
        return UploadResult.fromJson(data);
      },
    );
  }
}

// Вспомогательный метод для создания чанк
// Вспомогательный метод для создания чанков файла
List<FileChunk> createFileChunks({
  required String fileId,
  required int numberOfChunks,
  int chunkSize = 10,
}) {
  final chunks = <FileChunk>[];

  for (int i = 0; i < numberOfChunks; i++) {
    // Генерируем данные для чанка
    final data =
        List.generate(chunkSize, (index) => 'Data_${i}_$index').join('-');

    chunks.add(FileChunk(
      fileId: fileId,
      chunkIndex: i,
      data: data,
      isLastChunk: i == numberOfChunks - 1,
    ));
  }

  return chunks;
}

void main() {
  group('Клиентский стриминг RPC', () {
    // Транспорт через память для имитации соединения клиент-сервер
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;

    // Эндпоинты для клиента и сервера
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;

    // Сервисы
    late ServerFileService serverService;
    late ClientFileService clientService;

    // Сериализатор
    late MsgPackSerializer serializer;

    setUp(() {
      print('\n---------- Test Setup ----------');
      // Создаем сериализатор
      serializer = MsgPackSerializer();

      // Создаем транспорты
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');

      // Соединяем транспорты между собой
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);
      print('Transports connected');

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: serializer,
        debugLabel: 'client',
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: serializer,
        debugLabel: 'server',
      );
      print('Endpoints created');

      // Добавляем middleware для отладки
      clientEndpoint.addMiddleware(DebugMiddleware(RpcLogger("client")));
      serverEndpoint.addMiddleware(DebugMiddleware(RpcLogger("server")));
      print('Debug middleware added');

      // Создаем сервисы
      serverService = ServerFileService();
      clientService = ClientFileService(clientEndpoint);
      print('Services created');

      // Регистрируем контракт на сервере
      print('Регистрируем серверный контракт');
      serverEndpoint.registerServiceContract(serverService);
      print('Server contract registered');

      // Регистрируем контракт на клиенте
      print('Регистрируем клиентский контракт');
      clientEndpoint.registerServiceContract(clientService);
      print('Client contract registered');
      print('---------- Setup Complete ----------\n');
    });

    tearDown(() async {
      print('\n---------- Test Teardown ----------');
      // Закрываем эндпоинты
      await clientEndpoint.close();
      await serverEndpoint.close();
      print('Endpoints closed');
      print('---------- Teardown Complete ----------\n');
    });

    test('загрузка_файла_из_нескольких_чанков', () async {
      print('\n---------- Test Started ----------');

      final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}';
      final numberOfChunks = 5;
      final chunkSize = 20;

      print('Creating file chunks for file $fileId');
      final chunks = createFileChunks(
        fileId: fileId,
        numberOfChunks: numberOfChunks,
        chunkSize: chunkSize,
      );

      // Получаем стрим для загрузки файла
      final clientStreamBidi = clientService.uploadFile();

      print('Sending chunks to server...');

      // Отправляем чанки последовательно
      for (final chunk in chunks) {
        clientStreamBidi.send(chunk);
        print('Sent chunk ${chunk.chunkIndex} with size ${chunk.data.length}');
        await Future.delayed(
            Duration(milliseconds: 10)); // Имитируем задержку сети
      }

      // Сигнализируем о завершении передачи данных и ждем ответ
      await clientStreamBidi.finishSending();
      print('Finished sending data');

      try {
        // Получаем результат от сервера
        final result = await clientStreamBidi.getResponse().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
                'Превышено время ожидания ответа от сервера');
          },
        );

        print('Upload completed with result: ${result.toJson()}');

        // Проверяем результат
        expect(result.fileId, equals(fileId));
        expect(result.totalChunks, equals(numberOfChunks));
        expect(
            result.totalSize,
            equals(
                chunks.fold<int>(0, (sum, chunk) => sum + chunk.data.length)));
        expect(result.status, equals('completed'));
      } finally {
        // Закрываем стрим отправки
        await clientStreamBidi.close();
        print('Upload stream closed');
      }

      print('---------- Test Completed ----------\n');
    });
  });
}

// Специальный сервис, генерирующий ошибку для тестирования
base class ServerFileServiceWithError extends ServerFileService {
  @override
  ClientStreamingBidiStream<FileChunk, UploadResult> uploadFile() {
    // Создаем контроллер для чанков
    final requestController = StreamController<FileChunk>();
    // Создаем контроллер для ответов
    final responseController = StreamController<UploadResult>();

    // Запускаем обработку файла с ошибкой
    Future<void> processFile() async {
      try {
        // Читаем первый чанк и генерируем ошибку
        await for (final chunk in requestController.stream) {
          print('Error service received chunk: ${chunk.chunkIndex}');
          throw Exception(
              'Test error: Cannot process chunk ${chunk.chunkIndex}');
        }
      } catch (e, stack) {
        print('Error service received error: $e');
        responseController.addError(e, stack);
      } finally {
        // Закрываем контроллер ответов
        await responseController.close();
      }
    }

    // Запускаем обработку файла
    processFile();

    // Создаем BidiStream с нашими контроллерами
    final bidiStream = BidiStream<FileChunk, UploadResult>(
      responseStream: responseController.stream,
      sendFunction: (chunk) {
        if (!requestController.isClosed) {
          requestController.add(chunk);
        }
      },
      finishTransferFunction: () async {
        // При завершении передачи закрываем входящий поток
        if (!requestController.isClosed) {
          await requestController.close();
        }
      },
      closeFunction: () async {
        // Закрываем оба контроллера при закрытии потока
        if (!requestController.isClosed) {
          await requestController.close();
        }
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );

    return ClientStreamingBidiStream<FileChunk, UploadResult>(bidiStream);
  }
}
