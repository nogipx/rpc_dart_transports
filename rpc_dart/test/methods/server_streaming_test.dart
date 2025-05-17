import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Модели для тестирования серверного стриминга
class TaskRequest implements IRpcSerializableMessage {
  final String taskId;
  final String taskName;
  final int steps;

  TaskRequest({
    required this.taskId,
    required this.taskName,
    required this.steps,
  });

  @override
  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'taskName': taskName,
        'steps': steps,
      };

  static TaskRequest fromJson(Map<String, dynamic> json) {
    print('Parsing TaskRequest from: $json');
    return TaskRequest(
      taskId: json['taskId'] as String,
      taskName: json['taskName'] as String,
      steps: json['steps'] as int,
    );
  }
}

class ProgressMessage implements IRpcSerializableMessage {
  final String taskId;
  final int progress;
  final String status;
  final String message;

  ProgressMessage({
    required this.taskId,
    required this.progress,
    required this.status,
    required this.message,
  });

  @override
  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'progress': progress,
        'status': status,
        'message': message,
      };

  static ProgressMessage fromJson(Map<String, dynamic> json) {
    print('Parsing ProgressMessage from: $json');
    return ProgressMessage(
      taskId: json['taskId'] as String,
      progress: json['progress'] as int,
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }
}

// Контракт сервиса для тестирования серверного стриминга
abstract base class TaskServiceContract extends RpcServiceContract {
  TaskServiceContract() : super('TaskService');

  // Константа для имени метода
  static const String startTaskMethod = 'startTask';

  @override
  void setup() {
    print('Setting up TaskServiceContract');
    // Регистрируем метод серверного стриминга
    addServerStreamingMethod<TaskRequest, ProgressMessage>(
      methodName: startTaskMethod,
      handler: startTask,
      argumentParser: TaskRequest.fromJson,
      responseParser: ProgressMessage.fromJson,
    );
    super.setup();
  }

  // Метод, который должен быть реализован в конкретном классе
  ServerStreamingBidiStream<TaskRequest, ProgressMessage> startTask(
      TaskRequest request);
}

// Серверная реализация сервиса задач
base class ServerTaskService extends TaskServiceContract {
  @override
  ServerStreamingBidiStream<TaskRequest, ProgressMessage> startTask(
      TaskRequest request) {
    print(
        'Server: Starting task ${request.taskName} with ID ${request.taskId}');
    return BidiStreamGenerator<TaskRequest, ProgressMessage>((_) async* {
      print('Server: Generator started');
      // Начальный статус
      yield ProgressMessage(
        taskId: request.taskId,
        progress: 0,
        status: 'initializing',
        message: 'Задача запущена. Подготовка к выполнению...',
      );
      print('Server: Initial status sent');

      // Ставим небольшую задержку для имитации работы
      await Future.delayed(Duration(milliseconds: 10));
      print('Server: Delay completed');

      // Отправляем серию сообщений о прогрессе
      for (int i = 1; i <= request.steps; i++) {
        final progress = (i / request.steps * 100).round();
        final status = i == request.steps ? 'completed' : 'in_progress';
        final message = 'Прогресс задачи: $progress%';

        print('Server: Sending progress $progress%');
        yield ProgressMessage(
          taskId: request.taskId,
          progress: progress,
          status: status,
          message: message,
        );

        // Добавляем небольшую задержку между сообщениями
        await Future.delayed(Duration(milliseconds: 5));
      }
      print('Server: All messages sent');
    }).createServerStreaming();
  }
}

// Клиентская реализация для вызова метода
base class ClientTaskService extends TaskServiceContract {
  final RpcEndpoint client;

  ClientTaskService(this.client);

  @override
  ServerStreamingBidiStream<TaskRequest, ProgressMessage> startTask(
      TaskRequest request) {
    print('Client: Sending task request: ${request.toJson()}');
    return client
        .serverStreaming(
          serviceName: serviceName,
          methodName: TaskServiceContract.startTaskMethod,
        )
        .call<TaskRequest, ProgressMessage>(
          request: request,
          responseParser: ProgressMessage.fromJson,
        );
  }
}

// Вспомогательный метод для создания запроса
TaskRequest createTaskRequest({
  String taskId = 'test_task',
  String taskName = 'Test Task',
  int steps = 5,
}) {
  return TaskRequest(
    taskId: taskId,
    taskName: taskName,
    steps: steps,
  );
}

void main() {
  group('Серверный стриминг RPC', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late JsonSerializer serializer;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientTaskService clientService;
    late ServerTaskService serverService;

    setUp(() {
      print('\n---------- Test Setup ----------');
      // Создаем пару связанных транспортов
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);
      print('Transports connected');

      // Сериализатор
      serializer = JsonSerializer();

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
      serverService = ServerTaskService();
      clientService = ClientTaskService(clientEndpoint);
      print('Services created');

      // Регистрируем контракт сервера
      serverEndpoint.registerServiceContract(serverService);
      print('Server contract registered');
      print('---------- Setup Complete ----------\n');
    });

    tearDown(() async {
      print('\n---------- Test Teardown ----------');
      await clientEndpoint.close();
      await serverEndpoint.close();
      print('Endpoints closed');
      print('---------- Teardown Complete ----------\n');
    });

    test('получение_потока_сообщений_о_прогрессе_выполнения', () async {
      print('\n---------- Test Started ----------');
      // Создаем запрос на выполнение задачи
      final request = createTaskRequest(
        taskId: 'test_task_1',
        taskName: 'Test Server Streaming Task',
        steps: 5,
      );
      print('Request created: ${request.toJson()}');

      // Отправляем запрос и получаем поток сообщений о прогрессе
      print('Sending request...');
      final stream = clientService.startTask(request);
      print('Stream received, listening for messages...');

      try {
        // Получаем все сообщения из потока
        final messages = await stream.toList();
        print('Received ${messages.length} messages');

        // Проверяем количество сообщений (должно быть steps + 1)
        expect(messages.length, equals(request.steps + 1));

        // Проверяем первое сообщение (инициализация)
        print('First message: ${messages.first.toJson()}');
        expect(messages.first.progress, equals(0));
        expect(messages.first.status, equals('initializing'));

        // Проверяем последнее сообщение (завершение)
        print('Last message: ${messages.last.toJson()}');
        expect(messages.last.progress, equals(100));
        expect(messages.last.status, equals('completed'));

        // Проверяем идентификатор задачи во всех сообщениях
        for (final message in messages) {
          expect(message.taskId, equals(request.taskId));
        }
        print('All assertions passed');
      } catch (e, stackTrace) {
        print('Error during test: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
      print('---------- Test Completed ----------\n');
    });

    test('закрытие_стрима_после_получения_всех_сообщений', () async {
      // Создаем запрос с меньшим количеством шагов
      final request = createTaskRequest(
        taskId: 'test_task_2',
        taskName: 'Short Task',
        steps: 3,
      );

      // Отправляем запрос и получаем поток
      final stream = clientService.startTask(request);

      // Преобразуем в обычный Dart Stream для проверки isDone
      final broadcastStream = stream.asBroadcastStream();

      // Получаем все сообщения
      await broadcastStream.toList();

      // Проверяем, что поток завершился
      expect(await broadcastStream.isEmpty, isTrue);
    });

    test('последовательное_увеличение_прогресса', () async {
      // Создаем запрос
      final request = createTaskRequest(
        taskId: 'test_task_3',
        taskName: 'Progress Test',
        steps: 5,
      );

      // Отправляем запрос и получаем поток
      final stream = clientService.startTask(request);

      // Получаем все сообщения
      final messages = await stream.toList();

      // Проверяем последовательное увеличение прогресса
      int lastProgress = -1;
      for (final message in messages) {
        expect(message.progress, greaterThanOrEqualTo(lastProgress));
        lastProgress = message.progress;
      }
    });
  });
}
