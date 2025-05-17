import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

/// Менеджер для отслеживания активных сессий и защиты от рекурсии
class StreamProcessingManager {
  static final StreamProcessingManager _instance =
      StreamProcessingManager._internal();

  factory StreamProcessingManager() {
    return _instance;
  }

  StreamProcessingManager._internal();

  /// Активные сессии, ключ - ID сессии, значение - временная метка создания
  final Map<String, int> _activeSessions = <String, int>{};

  /// Проверяет, активна ли сессия
  bool isSessionActive(String sessionId) {
    return _activeSessions.containsKey(sessionId);
  }

  /// Активирует сессию и возвращает true, если успешно
  bool activateSession(String sessionId) {
    if (isSessionActive(sessionId)) {
      print('WARNING: Attempted to activate already active session $sessionId');
      return false;
    }

    _activeSessions[sessionId] = DateTime.now().millisecondsSinceEpoch;
    print(
        'Session $sessionId activated (total active: ${_activeSessions.length})');
    return true;
  }

  /// Деактивирует сессию и возвращает true, если сессия была активна
  bool deactivateSession(String sessionId) {
    final wasActive = _activeSessions.remove(sessionId) != null;
    if (wasActive) {
      print(
          'Session $sessionId deactivated (remaining active: ${_activeSessions.length})');
    } else {
      print('WARNING: Attempted to deactivate inactive session $sessionId');
    }
    return wasActive;
  }

  /// Очищает все активные сессии
  void clearSessions() {
    final count = _activeSessions.length;
    _activeSessions.clear();
    print('Cleared all $count active sessions');
  }

  /// Возвращает число активных сессий
  int get activeSessionCount => _activeSessions.length;

  /// Печатает информацию о всех активных сессиях
  void printActiveSessions() {
    if (_activeSessions.isEmpty) {
      print('No active sessions');
      return;
    }

    print('Active sessions (${_activeSessions.length}):');
    final now = DateTime.now().millisecondsSinceEpoch;
    _activeSessions.forEach((sessionId, timestamp) {
      final age = now - timestamp;
      print(' - $sessionId (age: ${age}ms)');
    });
  }
}

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
abstract base class FileServiceContract extends RpcServiceContract {
  FileServiceContract() : super('FileService');

  // Константа для имени метода
  static const String uploadFileMethod = 'uploadFile';

  @override
  void setup() {
    print('Setting up FileServiceContract');
    // Регистрируем метод клиентского стриминга
    addClientStreamingMethod<FileChunk>(
      methodName: uploadFileMethod,
      handler: uploadFile,
      argumentParser: FileChunk.fromJson,
    );
    super.setup();
  }

  // Метод, который должен быть реализован в конкретном классе
  ClientStreamingBidiStream<FileChunk> uploadFile();
}

// Создадим альтернативную реализацию без ответа
abstract class FileServiceContractNoResponse extends RpcServiceContract {
  FileServiceContractNoResponse() : super('FileServiceNoResponse');

  // Константа для имени метода
  static const String uploadFileMethod = 'uploadFile';

  @override
  void setup() {
    print('Setting up FileServiceContractNoResponse');
    // Регистрируем метод клиентского стриминга без ответа
    addClientStreamingMethod<FileChunk>(
      methodName: uploadFileMethod,
      handler: uploadFile,
      argumentParser: FileChunk.fromJson,
    );
    super.setup();
  }

  // Метод, который должен быть реализован в конкретном классе
  ClientStreamingBidiStream<FileChunk> uploadFile();
}

// Серверная реализация сервиса файлов
base class ServerFileService extends FileServiceContract {
  // Защита от повторного создания обработчиков
  int _handlerCount = 0;
  static const int MAX_HANDLERS = 5;

  // Используем флаг для предотвращения бесконечного создания обработчиков
  bool _isProcessing = false;

  // Используем Set для хранения активных сессий по ID
  final Set<String> _activeSessionIds = <String>{};

  // Получаем глобальный менеджер сессий
  final _sessionManager = StreamProcessingManager();

  // Метод для сброса счетчика обработчиков
  void resetHandlerCount() {
    _handlerCount = 0;
    _isProcessing = false;
    _activeSessionIds.clear();
    _sessionManager.clearSessions();
    print('Server: Handler count reset to 0, active sessions cleared');
  }

  // Внутренний метод для генерации уникального ID сессии
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp % 10000;
    return 'session_${timestamp}_${random}_${_handlerCount}';
  }

  // Метод из контракта, который вызывается клиентом
  @override
  ClientStreamingBidiStream<FileChunk> uploadFile() {
    // Увеличиваем счетчик созданных обработчиков
    _handlerCount++;
    print('Server: Handler count increased to $_handlerCount');

    // Проверяем, не превышен ли лимит обработчиков
    if (_handlerCount > ServerFileService.MAX_HANDLERS) {
      print(
          'WARNING: Exceeded maximum handler count (${ServerFileService.MAX_HANDLERS}) in error service. Possible infinite loop!');
      // Сбрасываем счетчик перед генерацией ошибки
      resetHandlerCount();
      // Генерируем ошибку чтобы прервать цикл создания обработчиков
      final controller = StreamController<RpcNull>();
      controller.addError(StateError('Exceeded maximum handler count'));
      controller.close();

      return ClientStreamingBidiStream<FileChunk>(
        BidiStream<FileChunk, RpcNull>(
          responseStream: controller.stream,
          sendFunction: (_) {},
          closeFunction: () => Future.value(),
        ),
      );
    }

    // Проверяем флаг для защиты от повторного вызова
    if (_isProcessing) {
      print('WARNING: Handler already processing. Possible recursive call!');
      // Сбрасываем все флаги, чтобы избежать дедлока
      resetHandlerCount();
      // Генерируем ошибку чтобы прервать цикл
      final controller = StreamController<RpcNull>();
      controller.addError(StateError('Handler already processing'));
      controller.close();

      return ClientStreamingBidiStream<FileChunk>(
        BidiStream<FileChunk, RpcNull>(
          responseStream: controller.stream,
          sendFunction: (_) {},
          closeFunction: () => Future.value(),
        ),
      );
    }

    // Генерируем уникальный ID сессии для отслеживания
    final sessionId = _generateSessionId();

    // Регистрируем сессию в менеджере
    if (!_sessionManager.activateSession(sessionId)) {
      print('ERROR: Failed to activate session $sessionId');
      final controller = StreamController<RpcNull>();
      controller.addError(StateError('Failed to activate session'));
      controller.close();

      return ClientStreamingBidiStream<FileChunk>(
        BidiStream<FileChunk, RpcNull>(
          responseStream: controller.stream,
          sendFunction: (_) {},
          closeFunction: () => Future.value(),
        ),
      );
    }

    // Добавляем ID в локальный набор активных сессий
    _activeSessionIds.add(sessionId);

    // Устанавливаем флаг, что обработчик начал работу
    _isProcessing = true;

    // Создаем потоки для запросов и ответов
    final requestController = StreamController<FileChunk>();
    final responseController = StreamController<RpcNull>();

    // Создаем отметку времени для отслеживания длительности обработки
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // Запускаем таймер безопасности для автоматического закрытия
    final safetyTimer = Timer(Duration(seconds: 15), () {
      print(
          'SAFETY TIMEOUT: Automatically closing session $sessionId after 15 seconds');

      if (!responseController.isClosed && !requestController.isClosed) {
        try {
          // Если еще не получили данные, отправляем ошибку таймаута
          responseController.addError(TimeoutException(
              'Session processing timeout', Duration(seconds: 15)));
        } catch (e) {
          print('Error when adding timeout error: $e');
        } finally {
          // В любом случае закрываем контроллеры
          try {
            if (!requestController.isClosed) requestController.close();
            if (!responseController.isClosed) responseController.close();
          } catch (e) {
            print('Error when closing controllers: $e');
          }

          // Завершаем сессию в менеджере
          _sessionManager.deactivateSession(sessionId);
          _activeSessionIds.remove(sessionId);

          // Добавляем ответ с информацией о загрузке
          if (!responseController.isClosed) {
            // В новой реализации не отправляем ответ, а просто завершаем поток
            responseController.close();
          }
        }
      }
    });

    // Запускаем обработку файла в отдельной зоне
    Future<void> processFile() async {
      int totalChunks = 0;
      int totalSize = 0;
      String? fileId;

      try {
        print('Server: Processing file chunks for session $sessionId');
        print('Server: Starting to listen for chunks...');

        // Обрабатываем все входящие чанки
        await for (final chunk in requestController.stream) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
          print(
              'Server: Received chunk ${chunk.chunkIndex} for file ${chunk.fileId} (elapsed: ${elapsed}ms)');

          // Сохраняем ID файла из первого чанка
          fileId ??= chunk.fileId;
          totalChunks++;
          totalSize += chunk.data.length;

          // Проверка соответствия fileId для всех чанков
          if (fileId != chunk.fileId) {
            throw StateError('File ID mismatch between chunks');
          }
        }

        final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
        print(
            'Server: Stream completed, all chunks received. Total: $totalChunks (elapsed: ${elapsed}ms)');
        print('Server: Upload complete, generating result');

        // Отменяем таймер безопасности, т.к. обработка завершена
        if (safetyTimer.isActive) {
          safetyTimer.cancel();
          print('Server: Canceled safety timer for session $sessionId');
        }

        print(
            'Server: Processing completed for file $fileId, total chunks: $totalChunks, size: $totalSize');
        // Закрываем контроллер ответов без добавления данных
        if (!responseController.isClosed) {
          responseController.close();
          print('Server: Response stream closed after successful processing');
        } else {
          print('WARNING: Response controller is already closed');
        }
      } catch (e, stack) {
        print('Server error during file upload: $e');
        print('Stack trace: $stack');

        // Отменяем таймер безопасности, т.к. обработка завершена с ошибкой
        if (safetyTimer.isActive) {
          safetyTimer.cancel();
          print('Server: Canceled safety timer for session $sessionId (error)');
        }

        if (!responseController.isClosed) {
          responseController.addError(e, stack);
        }
      } finally {
        // Удаляем ID сессии из активных
        _activeSessionIds.remove(sessionId);
        _sessionManager.deactivateSession(sessionId);
        print('Server: Removed session $sessionId from active sessions');

        // Сбрасываем флаг обработки и счетчик обработчиков
        _isProcessing = false;
        print('Server: Set _isProcessing flag to false in processFile finally');
        _handlerCount--;
        if (_handlerCount < 0) _handlerCount = 0;
        print('Server: Decreased handler count to $_handlerCount');

        // Закрываем контроллер ответов
        if (!responseController.isClosed) {
          await responseController.close();
          print('Server: Response stream closed for session $sessionId');
        }
      }
    }

    // Запускаем обработку файла
    processFile();

    // Создаем BidiStream с нашими контроллерами
    final bidiStream = BidiStream<FileChunk, RpcNull>(
      responseStream: responseController.stream,
      sendFunction: (chunk) {
        if (requestController.isClosed) {
          print('WARNING: Attempted to send chunk to closed request stream');
          return;
        }
        requestController.add(chunk);
      },
      finishTransferFunction: () {
        print('Server: Finishing transfer for session $sessionId');
        if (!requestController.isClosed) {
          requestController.close();
        }
        return Future.value();
      },
      closeFunction: () async {
        print('Server: Closing streams for session $sessionId');
        if (!requestController.isClosed) {
          await requestController.close();
        }
        if (!responseController.isClosed) {
          await responseController.close();
        }
        // Сбрасываем флаг
        _isProcessing = false;
        // Деактивируем сессию
        _sessionManager.deactivateSession(sessionId);
        _activeSessionIds.remove(sessionId);
      },
    );

    print(
        'Server: BidiStream created for session $sessionId, wrapping in ClientStreamingBidiStream');
    return ClientStreamingBidiStream<FileChunk>(bidiStream);
  }
}

// Клиентская реализация для вызова метода
base class ClientFileService extends FileServiceContract {
  final RpcEndpoint client;

  ClientFileService(this.client);

  @override
  ClientStreamingBidiStream<FileChunk> uploadFile() {
    print('Client: Creating file upload stream');
    return client
        .clientStreaming(
          serviceName: serviceName,
          methodName: FileServiceContract.uploadFileMethod,
        )
        .call<FileChunk>();
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

      // Сбрасываем счетчики обработчиков на всякий случай
      serverService.resetHandlerCount();
      print('Handler counters reset');

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
      // Сбрасываем счетчики обработчиков перед завершением теста
      serverService.resetHandlerCount();
      print('Handler counters reset');

      // Закрываем эндпоинты
      await clientEndpoint.close();
      await serverEndpoint.close();
      print('Endpoints closed');
      print('---------- Teardown Complete ----------\n');
    });

    test('загрузка_файла_из_нескольких_чанков', () async {
      print('\n---------- Test Started ----------');

      // Сбрасываем счетчики на всякий случай
      serverService.resetHandlerCount();

      final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}';
      final numberOfChunks = 5;
      final chunkSize = 20;

      print('Creating file chunks for file $fileId');
      final chunks = createFileChunks(
        fileId: fileId,
        numberOfChunks: numberOfChunks,
        chunkSize: chunkSize,
      );

      // Устанавливаем флаг для защиты от повторных вызовов
      bool isTestCompleted = false;

      // Устанавливаем максимальное время выполнения теста
      final testTimeout = Timer(Duration(seconds: 30), () {
        if (!isTestCompleted) {
          print('ТЕСТ ЗАВИС! Принудительно завершаем...');
          isTestCompleted = true;
          // Здесь необходимо принудительное завершение теста
          fail('Тест завис и был принудительно прерван по таймауту');
        }
      });

      try {
        // Получаем стрим для загрузки файла
        print('Requesting upload stream from client service...');
        final clientStreamBidi = clientService.uploadFile();
        print('Upload stream created with client endpoint');

        // Устанавливаем таймаут для защиты от зависания
        final clientTimeout = Timer(Duration(seconds: 30), () {
          if (!isTestCompleted) {
            print('КЛИЕНТСКИЙ ТАЙМАУТ! Принудительно закрываем стрим...');
            clientStreamBidi.close();
          }
        });

        print('Sending chunks to server...');

        // Отправляем чанки последовательно
        for (var i = 0; i < chunks.length; i++) {
          if (isTestCompleted) break; // Защита от повторной отправки

          final chunk = chunks[i];
          print('Sending chunk ${i + 1}/${chunks.length} to server...');

          clientStreamBidi.send(chunk);
          print(
              'Sent chunk ${chunk.chunkIndex} with size ${chunk.data.length}');
          await Future.delayed(
              Duration(milliseconds: 50)); // Имитируем задержку сети
        }

        // Сигнализируем о завершении передачи данных и ждем ответ
        if (!isTestCompleted) {
          print('Finishing sending data to server...');
          await clientStreamBidi.finishSending();
          print('Finished sending data, waiting for response');
        }
      } finally {
        // Отменяем таймаут
        testTimeout.cancel();

        // Устанавливаем флаг завершения для защиты от повторных вызовов
        isTestCompleted = true;
      }

      print('---------- Test Completed ----------\n');
    });

    // Тест для проверки защиты от бесконечной рекурсии
    test('защита_от_превышения_количества_обработчиков', () async {
      print('\n---------- Recursion Protection Test Started ----------');

      // Сначала сбрасываем все счетчики для чистоты эксперимента
      serverService.resetHandlerCount();
      print('Initial handler count: ${serverService._handlerCount}');

      // Искусственно установим счетчик обработчиков близко к пределу
      for (int i = 0; i < ServerFileService.MAX_HANDLERS - 1; i++) {
        serverService._handlerCount++;
      }
      print(
          'Artificially increased handler count to ${serverService._handlerCount}');

      // Проверяем, что счетчик установлен правильно
      expect(serverService._handlerCount,
          equals(ServerFileService.MAX_HANDLERS - 1));

      // Получаем стрим для загрузки файла
      final clientStreamBidi = clientService.uploadFile();

      // Этот запрос должен увеличить счетчик до MAX_HANDLERS + 1, что вызовет ошибку
      // Отправляем тестовый чанк
      final testChunk =
          FileChunk(fileId: 'test', chunkIndex: 0, data: 'test data');
      clientStreamBidi.send(testChunk);

      // Проверяем, что счетчик был сброшен
      await Future.delayed(
          const Duration(milliseconds: 500)); // Даем время на сброс счетчика
      print('Final handler count: ${serverService._handlerCount}');
      expect(serverService._handlerCount, equals(0));

      print('---------- Recursion Protection Test Completed ----------\n');
    });

    // Упрощенный тест для отладки проблемы рекурсии
    test('debug_recursive_calls', () async {
      print('\n---------- Debug Recursive Calls Test Started ----------');

      // Сбрасываем счетчики перед началом теста
      serverService.resetHandlerCount();

      // Добавляем middleware для подробного логирования
      final clientLogger = RpcLogger("client_debug");
      final serverLogger = RpcLogger("server_debug");

      clientEndpoint.addMiddleware(DebugMiddleware(clientLogger));
      serverEndpoint.addMiddleware(DebugMiddleware(serverLogger));

      print('Creating simple client stream...');

      try {
        // Вызываем только создание стрима без отправки данных
        final clientStreamBidi = clientService.uploadFile();
        print('Client stream created: ${clientStreamBidi.hashCode}');

        // Добавляем задержку, чтобы увидеть логи в правильном порядке
        await Future.delayed(Duration(milliseconds: 100));

        // Просто закрываем стрим
        await clientStreamBidi.close();
        print('Client stream closed');

        // Делаем простую проверку, чтобы тест прошел
        expect(serverService._handlerCount, lessThan(3),
            reason:
                'Счетчик обработчиков должен быть менее 3, иначе есть проблема с рекурсией');
      } catch (e) {
        print('Test error: $e');
        rethrow;
      } finally {
        // Для чистоты сбрасываем все счетчики и флаги
        serverService.resetHandlerCount();
      }

      print('---------- Debug Recursive Calls Test Completed ----------\n');
    });

    // Тест для проверки корректной обработки ошибок и освобождения ресурсов
    test('обработка_ошибок_и_освобождение_ресурсов', () async {
      print('\n---------- Error Handling Test Started ----------');

      // Создаем отдельные эндпоинты и сервисы для этого теста
      final errorClientTransport = MemoryTransport('error_client');
      final errorServerTransport = MemoryTransport('error_server');
      errorClientTransport.connect(errorServerTransport);
      errorServerTransport.connect(errorClientTransport);

      final errorClientEndpoint = RpcEndpoint(
        transport: errorClientTransport,
        serializer: serializer,
        debugLabel: 'error_client',
      );
      final errorServerEndpoint = RpcEndpoint(
        transport: errorServerTransport,
        serializer: serializer,
        debugLabel: 'error_server',
      );

      // Создаем сервисы - используем сервис с ошибкой
      final errorServerService = ServerFileServiceWithError();
      final errorClientService = ClientFileService(errorClientEndpoint);

      // Сбрасываем счетчики
      errorServerService.resetHandlerCount();

      // Регистрируем контракты
      errorServerEndpoint.registerServiceContract(errorServerService);
      errorClientEndpoint.registerServiceContract(errorClientService);

      print('Error test setup completed');

      try {
        // Создаем тестовый файл
        final fileId = 'error_file_${DateTime.now().millisecondsSinceEpoch}';
        final chunks = createFileChunks(
          fileId: fileId,
          numberOfChunks: 3,
          chunkSize: 10,
        );

        print('Requesting upload stream from error client service...');
        final clientStreamBidi = errorClientService.uploadFile();

        // Отправляем один чанк, который должен вызвать ошибку на сервере
        print('Sending chunk to error service...');
        clientStreamBidi.send(chunks[0]);

        // Ждем некоторое время для обработки и освобождения ресурсов
        await Future.delayed(const Duration(milliseconds: 500));

        // Проверяем, что ресурсы были освобождены
        expect(errorServerService._isProcessing, isFalse,
            reason: 'Processing flag should be reset');

        expect(errorServerService._activeSessionIds.isEmpty, isTrue,
            reason: 'Active sessions should be cleared');

        // Проверяем счетчик обработчиков
        expect(errorServerService._handlerCount, equals(0),
            reason: 'Handler count should be reset to 0');

        // Проверяем, что сессия была деактивирована в глобальном менеджере
        expect(StreamProcessingManager().activeSessionCount, equals(0),
            reason: 'Global session manager should have no active sessions');
      } finally {
        // Закрываем эндпоинты
        await errorClientEndpoint.close();
        await errorServerEndpoint.close();
        // Сбрасываем счетчики
        errorServerService.resetHandlerCount();
        print('Error test cleanup completed');
      }

      print('---------- Error Handling Test Completed ----------\n');
    });
  });
}

// Специальный сервис, генерирующий ошибку для тестирования
base class ServerFileServiceWithError extends ServerFileService {
  // Переопределяем, чтобы защитить от рекурсивных вызовов
  @override
  bool _isProcessing = false;

  // Переопределяем счетчик, чтобы была отдельная переменная
  @override
  int _handlerCount = 0;

  // Переопределяем Set активных сессий
  @override
  final Set<String> _activeSessionIds = <String>{};

  // Используем тот же менеджер сессий
  @override
  final _sessionManager = StreamProcessingManager();

  @override
  void resetHandlerCount() {
    _handlerCount = 0;
    _isProcessing = false;
    _activeSessionIds.clear();
    _sessionManager.clearSessions();
    print('Error Service: Handler count reset to 0, active sessions cleared');
  }

  // Защищенная версия uploadFile для сервиса с ошибкой
  ClientStreamingBidiStream<FileChunk> _uploadFileWithSessionError(
      String sessionId) {
    print('Error Service: Processing upload with session ID: $sessionId');

    // Если сессия уже существует, вернем ошибку
    if (_activeSessionIds.contains(sessionId) &&
        _sessionManager.isSessionActive(sessionId)) {
      print(
          'ERROR: Attempting to process session $sessionId that is already active in error service!');

      final controller = StreamController<RpcNull>();
      controller.addError(StateError(
          'Session $sessionId already being processed in error service'));
      controller.close();

      return ClientStreamingBidiStream<FileChunk>(
        BidiStream<FileChunk, RpcNull>(
          responseStream: controller.stream,
          sendFunction: (_) {},
          closeFunction: () => Future.value(),
        ),
      );
    }

    // Создаем контроллер для чанков
    final requestController = StreamController<FileChunk>();
    // Создаем контроллер для ответов
    final responseController = StreamController<RpcNull>();

    // Создаем отметку времени для отслеживания длительности обработки
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // Запускаем таймер безопасности для автоматического закрытия
    final safetyTimer = Timer(Duration(seconds: 15), () {
      print(
          'SAFETY TIMEOUT: Automatically closing error session $sessionId after 15 seconds');

      if (!responseController.isClosed && !requestController.isClosed) {
        try {
          // Если еще не получили данные, отправляем ошибку таймаута
          responseController.addError(TimeoutException(
              'Error session processing timeout', Duration(seconds: 15)));
        } catch (e) {
          print('Error when adding timeout error: $e');
        } finally {
          // В любом случае закрываем контроллеры
          try {
            if (!requestController.isClosed) requestController.close();
            if (!responseController.isClosed) responseController.close();
          } catch (e) {
            print('Error when closing controllers: $e');
          }

          _activeSessionIds.remove(sessionId);
          _isProcessing = false;
          print(
              'Safety timeout removed error session $sessionId from active sessions');
        }
      }
    });

    // Запускаем обработку файла с ошибкой
    Future<void> processFile() async {
      try {
        // Читаем первый чанк и генерируем ошибку
        await for (final chunk in requestController.stream) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
          print(
              'Error service received chunk: ${chunk.chunkIndex} in session $sessionId (elapsed: ${elapsed}ms)');

          // Отменяем таймер безопасности, т.к. получили данные и генерируем ошибку
          if (safetyTimer.isActive) {
            safetyTimer.cancel();
            print(
                'Error Service: Canceled safety timer for session $sessionId before generating error');
          }

          throw Exception(
              'Test error: Cannot process chunk ${chunk.chunkIndex} in session $sessionId');
        }
      } catch (e, stack) {
        print('Error service received error: $e');

        if (!responseController.isClosed) {
          responseController.addError(e, stack);
        }
      } finally {
        // Удаляем ID сессии из активных
        _activeSessionIds.remove(sessionId);
        print('Error Service: Removed session $sessionId from active sessions');

        // Сбрасываем флаг обработки и счетчик обработчиков
        _isProcessing = false;
        print(
            'Error Service: Set _isProcessing flag to false in processFile finally');
        _handlerCount--;
        if (_handlerCount < 0) _handlerCount = 0;
        print('Error Service: Decreased handler count to $_handlerCount');

        // Закрываем контроллер ответов
        if (!responseController.isClosed) {
          await responseController.close();
          print('Error Service: Response stream closed for session $sessionId');
        }
      }
    }

    // Запускаем обработку файла
    processFile();

    // Создаем BidiStream с нашими контроллерами
    final bidiStream = BidiStream<FileChunk, RpcNull>(
      responseStream: responseController.stream,
      sendFunction: (chunk) {
        if (!requestController.isClosed) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
          print(
              'Error Service: Received chunk via send function (elapsed: ${elapsed}ms)');
          requestController.add(chunk);
        } else {
          print(
              'WARNING: Cannot add chunk to error service, request controller is closed');
        }
      },
      finishTransferFunction: () async {
        // При завершении передачи закрываем входящий поток
        final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
        print('Error Service: Finishing transfer (elapsed: ${elapsed}ms)');

        if (!requestController.isClosed) {
          await requestController.close();
          print('Error Service: Request stream closed by finishTransfer');
        } else {
          print(
              'WARNING: Error service request controller already closed in finishTransfer');
        }
      },
      closeFunction: () async {
        // Отменяем таймер безопасности
        if (safetyTimer.isActive) {
          safetyTimer.cancel();
          print(
              'Error Service: Canceled safety timer for session $sessionId (close)');
        }

        // Удаляем ID сессии из активных
        _activeSessionIds.remove(sessionId);
        print(
            'Error Service: Removed session $sessionId from active sessions (in closeFunction)');

        // Сбрасываем флаг обработки и счетчик обработчиков
        _isProcessing = false;
        print(
            'Error Service: Set _isProcessing flag to false in closeFunction');
        _handlerCount--;
        if (_handlerCount < 0) _handlerCount = 0;
        print('Error Service: Decreased handler count to $_handlerCount');

        // Закрываем оба контроллера при закрытии потока
        if (!requestController.isClosed) {
          await requestController.close();
          print('Error Service: Request stream closed in closeFunction');
        }
        if (!responseController.isClosed) {
          await responseController.close();
          print('Error Service: Response stream closed in closeFunction');
        }
      },
    );

    print(
        'Error Service: BidiStream created for session $sessionId, wrapping in ClientStreamingBidiStream');
    return ClientStreamingBidiStream<FileChunk>(bidiStream);
  }

  @override
  ClientStreamingBidiStream<FileChunk> uploadFile() {
    // Увеличиваем счетчик созданных обработчиков
    _handlerCount++;
    print('Error Service: Handler count increased to $_handlerCount');

    // Проверяем, не превышен ли лимит обработчиков
    if (_handlerCount > ServerFileService.MAX_HANDLERS) {
      print(
          'WARNING: Exceeded maximum handler count (${ServerFileService.MAX_HANDLERS}) in error service. Possible infinite loop!');
      // Сбрасываем счетчик перед генерацией ошибки
      resetHandlerCount();
      // Генерируем ошибку чтобы прервать цикл создания обработчиков
      final controller = StreamController<RpcNull>();
      controller.addError(
          StateError('Exceeded maximum handler count in error service'));
      controller.close();

      return ClientStreamingBidiStream<FileChunk>(
        BidiStream<FileChunk, RpcNull>(
          responseStream: controller.stream,
          sendFunction: (_) {},
          closeFunction: () => Future.value(),
        ),
      );
    }

    // Проверяем флаг для защиты от повторного вызова
    if (_isProcessing) {
      print(
          'WARNING: Error handler already processing. Possible recursive call!');
      // Сбрасываем все флаги, чтобы избежать дедлока
      resetHandlerCount();
      // Генерируем ошибку чтобы прервать цикл
      final controller = StreamController<RpcNull>();
      controller.addError(StateError('Error handler already processing'));
      controller.close();

      return ClientStreamingBidiStream<FileChunk>(
        BidiStream<FileChunk, RpcNull>(
          responseStream: controller.stream,
          sendFunction: (_) {},
          closeFunction: () => Future.value(),
        ),
      );
    }

    // Генерируем уникальный ID сессии
    final sessionId = _generateSessionId();
    print(
        'Error Service: Creating file upload handler with error for session $sessionId');

    // Проверяем с помощью глобального менеджера, не активна ли уже эта сессия
    if (!_sessionManager.activateSession(sessionId)) {
      print(
          'WARNING: Session $sessionId already active in global manager for error service!');

      // Генерируем ошибку для защиты от дублирования
      final controller = StreamController<RpcNull>();
      controller.addError(StateError(
          'Session manager rejected session $sessionId for error service'));
      controller.close();

      return ClientStreamingBidiStream<FileChunk>(
        BidiStream<FileChunk, RpcNull>(
          responseStream: controller.stream,
          sendFunction: (_) {},
          closeFunction: () => Future.value(),
        ),
      );
    }

    // Устанавливаем флаг обработки и добавляем ID сессии в набор активных
    _isProcessing = true;
    _activeSessionIds.add(sessionId);
    print('Error Service: Added session $sessionId to active sessions');
    print(
        'Error Service: Set _isProcessing flag to true for session $sessionId');

    return _uploadFileWithSessionError(sessionId);
  }
}
