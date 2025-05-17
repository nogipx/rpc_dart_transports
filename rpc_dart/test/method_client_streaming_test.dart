// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';
import 'fixtures/test_contract.dart';
import 'fixtures/test_factory.dart';

// Модели для тестирования файлового клиентского стриминга
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
    return UploadResult(
      fileId: json['fileId'] as String,
      totalChunks: json['totalChunks'] as int,
      totalSize: json['totalSize'] as int,
      status: json['status'] as String,
    );
  }
}

/// Базовое сообщение для тестов клиентского стриминга
class StreamMessage implements IRpcSerializableMessage {
  final String data;

  StreamMessage(this.data);

  @override
  Map<String, dynamic> toJson() => {'data': data};

  factory StreamMessage.fromJson(Map<String, dynamic> json) {
    return StreamMessage(json['data'] as String? ?? '');
  }
}

/// Контракт для тестирования клиентского стриминга файлов
abstract class FileUploadServiceContract extends IExtensionTestContract {
  static const String uploadFileMethod = 'uploadFile';

  FileUploadServiceContract() : super('file_upload_tests');

  @override
  void setup() {
    // Регистрируем метод клиентского стриминга
    addClientStreamingMethod<FileChunk, UploadResult>(
      methodName: uploadFileMethod,
      handler: uploadFile,
      argumentParser: FileChunk.fromJson,
      responseParser: UploadResult.fromJson,
    );
    super.setup();
  }

  /// Метод для загрузки файла частями
  ClientStreamingBidiStream<FileChunk, UploadResult> uploadFile();
}

/// Контракт для тестирования базовых операций клиентского стриминга
abstract class BasicStreamServiceContract extends IExtensionTestContract {
  static const String collectDataMethod = 'collectData';
  static const String countItemsMethod = 'countItems';
  static const String errorStreamMethod = 'errorStream';

  BasicStreamServiceContract() : super('basic_stream_tests');

  @override
  void setup() {
    // Регистрируем методы клиентского стриминга
    addClientStreamingMethod<StreamMessage, StreamMessage>(
      methodName: collectDataMethod,
      handler: collectData,
      argumentParser: StreamMessage.fromJson,
      responseParser: StreamMessage.fromJson,
    );

    addClientStreamingMethod<StreamMessage, StreamMessage>(
      methodName: countItemsMethod,
      handler: countItems,
      argumentParser: StreamMessage.fromJson,
      responseParser: StreamMessage.fromJson,
    );

    addClientStreamingMethod<StreamMessage, StreamMessage>(
      methodName: errorStreamMethod,
      handler: errorStream,
      argumentParser: StreamMessage.fromJson,
      responseParser: StreamMessage.fromJson,
    );

    super.setup();
  }

  /// Собирает все полученные сообщения в строку через запятую
  ClientStreamingBidiStream<StreamMessage, StreamMessage> collectData();

  /// Подсчитывает количество полученных элементов
  ClientStreamingBidiStream<StreamMessage, StreamMessage> countItems();

  /// Генерирует ошибку при получении определенного сообщения
  ClientStreamingBidiStream<StreamMessage, StreamMessage> errorStream();
}

/// Серверная реализация контракта загрузки файлов
class FileUploadServiceServer extends FileUploadServiceContract {
  // Защита от повторного создания обработчиков
  int _handlerCount = 0;
  static const int MAX_HANDLERS = 5;

  // Используем флаг для предотвращения бесконечного создания обработчиков
  bool _isProcessing = false;

  // Используем Set для хранения активных сессий по ID
  final Set<String> _activeSessionIds = <String>{};

  // Храним собранные данные для тестирования
  final Map<String, List<FileChunk>> _fileChunks = <String, List<FileChunk>>{};

  /// Получить список чанков для указанного файла
  List<FileChunk> getFileChunks(String fileId) {
    return _fileChunks[fileId] ?? [];
  }

  /// Очистить все собранные данные
  void clearData() {
    _fileChunks.clear();
    _activeSessionIds.clear();
    _handlerCount = 0;
    _isProcessing = false;
  }

  @override
  ClientStreamingBidiStream<FileChunk, UploadResult> uploadFile() {
    if (_handlerCount >= MAX_HANDLERS) {
      throw Exception('Слишком много обработчиков создано: $_handlerCount');
    }

    _handlerCount++;

    final sessionId =
        'upload_${DateTime.now().millisecondsSinceEpoch}_${_handlerCount}';

    // Защита от рекурсии
    if (_isProcessing) {
      throw Exception('Рекурсивный вызов обработчика');
    }

    _isProcessing = true;

    try {
      if (_activeSessionIds.contains(sessionId)) {
        throw Exception('Сессия уже активна: $sessionId');
      }

      _activeSessionIds.add(sessionId);

      // Создаем контроллеры для запросов и ответов
      final requestController = StreamController<FileChunk>();
      final responseController = StreamController<UploadResult>();

      // Метаданные загрузки
      var totalChunks = 0;
      var totalSize = 0;
      String? currentFileId;
      final chunks = <FileChunk>[];

      // Обрабатываем стрим запросов
      requestController.stream.listen(
        (chunk) {
          // Инициализируем fileId при первом чанке
          currentFileId ??= chunk.fileId;

          // Проверяем, что все чанки относятся к одному файлу
          if (chunk.fileId != currentFileId) {
            responseController.addError(
              Exception('Смешивание чанков разных файлов не допускается'),
            );
            return;
          }

          chunks.add(chunk);
          totalChunks++;
          totalSize += chunk.data.length;
        },
        onDone: () {
          if (currentFileId != null) {
            // Сохраняем чанки для тестирования
            _fileChunks[currentFileId!] = List.from(chunks);

            // Создаем результат
            final result = UploadResult(
              fileId: currentFileId!,
              totalChunks: totalChunks,
              totalSize: totalSize,
              status: 'success',
            );

            // Отправляем результат
            responseController.add(result);
          } else {
            responseController.addError(
              Exception('Не получено ни одного чанка'),
            );
          }

          // Закрываем соединение
          responseController.close();
          _activeSessionIds.remove(sessionId);
          _isProcessing = false;
        },
        onError: (error) {
          responseController.addError(error);
          responseController.close();
          _activeSessionIds.remove(sessionId);
          _isProcessing = false;
        },
      );

      return ClientStreamingBidiStream<FileChunk, UploadResult>(
        BidiStream<FileChunk, UploadResult>(
          responseStream: responseController.stream,
          sendFunction: (chunk) => requestController.add(chunk),
          closeFunction: () async {
            await requestController.close();
          },
        ),
      );
    } catch (e) {
      _activeSessionIds.remove(sessionId);
      _isProcessing = false;
      rethrow;
    }
  }
}

/// Клиентская реализация контракта загрузки файлов
class FileUploadServiceClient extends FileUploadServiceContract {
  final RpcEndpoint _endpoint;

  FileUploadServiceClient(this._endpoint);

  @override
  ClientStreamingBidiStream<FileChunk, UploadResult> uploadFile() {
    final method = _endpoint.clientStreaming(
      serviceName: serviceName,
      methodName: FileUploadServiceContract.uploadFileMethod,
    );

    return method.call<FileChunk, UploadResult>(
      responseParser: UploadResult.fromJson,
    );
  }
}

/// Серверная реализация базового стримингового контракта
class BasicStreamServiceServer extends BasicStreamServiceContract {
  @override
  ClientStreamingBidiStream<StreamMessage, StreamMessage> collectData() {
    final requestController = StreamController<StreamMessage>();
    final responseController = StreamController<StreamMessage>();

    final messages = <String>[];

    requestController.stream.listen(
      (message) {
        messages.add(message.data);
      },
      onDone: () {
        final result = StreamMessage(messages.join(', '));
        responseController.add(result);
        responseController.close();
      },
      onError: (error) {
        responseController.addError(error);
        responseController.close();
      },
    );

    return ClientStreamingBidiStream<StreamMessage, StreamMessage>(
      BidiStream<StreamMessage, StreamMessage>(
        responseStream: responseController.stream,
        sendFunction: (message) => requestController.add(message),
        closeFunction: () async {
          await requestController.close();
        },
      ),
    );
  }

  @override
  ClientStreamingBidiStream<StreamMessage, StreamMessage> countItems() {
    final requestController = StreamController<StreamMessage>();
    final responseController = StreamController<StreamMessage>();

    var count = 0;

    requestController.stream.listen(
      (message) {
        count++;
      },
      onDone: () {
        final result = StreamMessage('count:$count');
        responseController.add(result);
        responseController.close();
      },
      onError: (error) {
        responseController.addError(error);
        responseController.close();
      },
    );

    return ClientStreamingBidiStream<StreamMessage, StreamMessage>(
      BidiStream<StreamMessage, StreamMessage>(
        responseStream: responseController.stream,
        sendFunction: (message) => requestController.add(message),
        closeFunction: () async {
          await requestController.close();
        },
      ),
    );
  }

  @override
  ClientStreamingBidiStream<StreamMessage, StreamMessage> errorStream() {
    final requestController = StreamController<StreamMessage>();
    final responseController = StreamController<StreamMessage>();

    requestController.stream.listen(
      (message) {
        if (message.data == 'error') {
          responseController.addError(Exception('Искусственная ошибка'));
          responseController.close();
        }
      },
      onDone: () {
        responseController.add(StreamMessage('done'));
        responseController.close();
      },
      onError: (error) {
        responseController.addError(error);
        responseController.close();
      },
    );

    return ClientStreamingBidiStream<StreamMessage, StreamMessage>(
      BidiStream<StreamMessage, StreamMessage>(
        responseStream: responseController.stream,
        sendFunction: (message) => requestController.add(message),
        closeFunction: () async {
          await requestController.close();
        },
      ),
    );
  }
}

/// Клиентская реализация базового стримингового контракта
class BasicStreamServiceClient extends BasicStreamServiceContract {
  final RpcEndpoint _endpoint;

  BasicStreamServiceClient(this._endpoint);

  @override
  ClientStreamingBidiStream<StreamMessage, StreamMessage> collectData() {
    final method = _endpoint.clientStreaming(
      serviceName: serviceName,
      methodName: BasicStreamServiceContract.collectDataMethod,
    );

    return method.call<StreamMessage, StreamMessage>(
      responseParser: StreamMessage.fromJson,
    );
  }

  @override
  ClientStreamingBidiStream<StreamMessage, StreamMessage> countItems() {
    final method = _endpoint.clientStreaming(
      serviceName: serviceName,
      methodName: BasicStreamServiceContract.countItemsMethod,
    );

    return method.call<StreamMessage, StreamMessage>(
      responseParser: StreamMessage.fromJson,
    );
  }

  @override
  ClientStreamingBidiStream<StreamMessage, StreamMessage> errorStream() {
    final method = _endpoint.clientStreaming(
      serviceName: serviceName,
      methodName: BasicStreamServiceContract.errorStreamMethod,
    );

    return method.call<StreamMessage, StreamMessage>(
      responseParser: StreamMessage.fromJson,
    );
  }
}

/// Тестируем клиентский стриминг с использованием новой инфраструктуры тестирования
void main() {
  group('Тесты клиентского стриминга', () {
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late FileUploadServiceClient fileUploadClient;
    late FileUploadServiceServer fileUploadServer;
    late BasicStreamServiceClient basicStreamClient;
    late BasicStreamServiceServer basicStreamServer;

    setUp(() {
      // Используем фабрику для создания тестового окружения с несколькими расширениями
      final testEnv = TestContractFactory.setupTestEnvironment(
        extensionFactories: [
          (
            type: FileUploadServiceContract,
            clientFactory: (endpoint) => FileUploadServiceClient(endpoint),
            serverFactory: () => FileUploadServiceServer(),
          ),
          (
            type: BasicStreamServiceContract,
            clientFactory: (endpoint) => BasicStreamServiceClient(endpoint),
            serverFactory: () => BasicStreamServiceServer(),
          ),
        ],
      );

      clientEndpoint = testEnv.clientEndpoint;
      serverEndpoint = testEnv.serverEndpoint;

      // Получаем конкретные реализации из mapы расширений
      fileUploadClient = testEnv.clientExtensions
          .get<FileUploadServiceContract>() as FileUploadServiceClient;
      fileUploadServer = testEnv.serverExtensions
          .get<FileUploadServiceContract>() as FileUploadServiceServer;
      basicStreamClient = testEnv.clientExtensions
          .get<BasicStreamServiceContract>() as BasicStreamServiceClient;
      basicStreamServer = testEnv.serverExtensions
          .get<BasicStreamServiceContract>() as BasicStreamServiceServer;

      // Очищаем данные перед каждым тестом
      fileUploadServer.clearData();
    });

    tearDown(() async {
      await TestFixtureUtils.tearDown(clientEndpoint, serverEndpoint);
    });

    test('Базовый тест загрузки файла', () async {
      // Получаем стрим для загрузки
      final uploadStream = fileUploadClient.uploadFile();

      // Отправляем несколько чанков
      final fileId = 'test-file-123';
      for (var i = 0; i < 5; i++) {
        uploadStream.send(
          FileChunk(
            fileId: fileId,
            chunkIndex: i,
            data: 'Chunk data $i',
            isLastChunk: i == 4,
          ),
        );
      }

      // Завершаем отправку и ждем ответа
      await uploadStream.finishSending();
      final result = await uploadStream.getResponse();

      // Проверяем результат
      expect(result, isNotNull);
      expect(result!.fileId, equals(fileId));
      expect(result.totalChunks, equals(5));
      expect(result.status, equals('success'));

      // Проверяем, что все чанки были получены сервером
      final serverChunks = fileUploadServer.getFileChunks(fileId);
      expect(serverChunks.length, equals(5));
      for (var i = 0; i < 5; i++) {
        expect(serverChunks[i].fileId, equals(fileId));
        expect(serverChunks[i].chunkIndex, equals(i));
        expect(serverChunks[i].data, equals('Chunk data $i'));
      }
    });

    test('Тест с большим количеством чанков', () async {
      // Получаем стрим для загрузки
      final uploadStream = fileUploadClient.uploadFile();

      // Отправляем много чанков
      final fileId = 'big-file-456';
      final chunkCount = 100;

      for (var i = 0; i < chunkCount; i++) {
        uploadStream.send(
          FileChunk(
            fileId: fileId,
            chunkIndex: i,
            data: 'Chunk data $i with some extra content ${i * i}',
            isLastChunk: i == chunkCount - 1,
          ),
        );
      }

      // Завершаем отправку и ждем ответа
      await uploadStream.finishSending();
      final result = await uploadStream.getResponse();

      // Проверяем результат
      expect(result, isNotNull);
      expect(result!.fileId, equals(fileId));
      expect(result.totalChunks, equals(chunkCount));
      expect(result.status, equals('success'));

      // Проверяем количество чанков на сервере
      final serverChunks = fileUploadServer.getFileChunks(fileId);
      expect(serverChunks.length, equals(chunkCount));
    });

    // Тест встроенных методов клиентского стриминга
    test('Метод collectData должен объединять все сообщения', () async {
      // Получаем стрим для сбора данных
      final stream = basicStreamClient.collectData();

      // Отправляем сообщения
      stream.send(StreamMessage('сообщение 1'));
      stream.send(StreamMessage('сообщение 2'));
      stream.send(StreamMessage('сообщение 3'));

      // Завершаем отправку и получаем ответ
      await stream.finishSending();
      final response = await stream.getResponse();

      // Проверяем, что все сообщения собраны
      expect(response?.data, contains('сообщение 1'));
      expect(response?.data, contains('сообщение 2'));
      expect(response?.data, contains('сообщение 3'));
    });

    test('Метод countItems должен считать количество элементов', () async {
      // Получаем стрим для подсчета элементов
      final stream = basicStreamClient.countItems();

      // Отправляем несколько сообщений
      final count = 7;
      for (var i = 0; i < count; i++) {
        stream.send(StreamMessage('item $i'));
      }

      // Завершаем отправку и получаем ответ
      await stream.finishSending();
      final response = await stream.getResponse();

      // Проверяем результат
      expect(response?.data, equals('count:$count'));
    });

    test('Метод errorStream должен генерировать ошибку', () async {
      // Получаем стрим для тестирования ошибок
      final stream = basicStreamClient.errorStream();

      // Отправляем обычное сообщение
      stream.send(StreamMessage('нормальное сообщение'));

      // Отправляем сообщение, которое вызовет ошибку
      stream.send(StreamMessage('error'));

      // Завершаем отправку
      await stream.finishSending();

      // Ожидаем ошибку при получении ответа
      expect(() async {
        await stream.getResponse();
      }, throwsA(isA<Exception>()));
    });
  });
}
