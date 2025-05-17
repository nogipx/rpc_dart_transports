import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';
import 'fixtures/test_factory.dart';
import 'fixtures/test_contract.dart';

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
    return ProgressMessage(
      taskId: json['taskId'] as String,
      progress: json['progress'] as int,
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }
}

// Контракт сервиса для тестирования серверного стриминга
abstract class TaskServiceContract extends RpcServiceContract {
  // Константа для имени метода
  static const String startTaskMethod = 'startTask';

  TaskServiceContract() : super('TaskService');

  @override
  void setup() {
    // Регистрируем метод серверного стриминга
    addServerStreamingMethod<TaskRequest, ProgressMessage>(
      methodName: startTaskMethod,
      handler: startTask,
      argumentParser: TaskRequest.fromJson,
      responseParser: ProgressMessage.fromJson,
    );
    super.setup();
  }

  // Метод для прямого доступа к responseParser
  dynamic getProgressMessageParser() {
    return ProgressMessage.fromJson;
  }

  // Метод, который должен быть реализован в конкретном классе
  ServerStreamingBidiStream<TaskRequest, ProgressMessage> startTask(
      TaskRequest request);
}

// Серверная реализация сервиса задач
class ServerTaskService extends TaskServiceContract {
  ServerTaskService() : super() {
    // Явно вызываем setup для инициализации методов
    print('Debug: Инициализация ServerTaskService');
    setup();

    // Выводим дополнительную информацию для отладки
    print('Debug: methods = ${methods.map((m) => m.methodName).join(", ")}');
  }

  @override
  ServerStreamingBidiStream<TaskRequest, ProgressMessage> startTask(
      TaskRequest request) {
    return BidiStreamGenerator<TaskRequest, ProgressMessage>((_) async* {
      // Начальный статус
      yield ProgressMessage(
        taskId: request.taskId,
        progress: 0,
        status: 'initializing',
        message: 'Задача запущена. Подготовка к выполнению...',
      );

      // Ставим небольшую задержку для имитации работы
      await Future.delayed(Duration(milliseconds: 10));

      // Отправляем серию сообщений о прогрессе
      for (int i = 1; i <= request.steps; i++) {
        final progress = (i / request.steps * 100).round();
        final status = i == request.steps ? 'completed' : 'in_progress';
        final message = 'Прогресс задачи: $progress%';

        yield ProgressMessage(
          taskId: request.taskId,
          progress: progress,
          status: status,
          message: message,
        );

        // Добавляем небольшую задержку между сообщениями
        await Future.delayed(Duration(milliseconds: 5));
      }
    }).createServerStreaming();
  }
}

// Клиентская реализация для вызова метода
class ClientTaskService extends TaskServiceContract {
  final RpcEndpoint _endpoint;

  ClientTaskService(this._endpoint) : super() {
    // Явно вызываем setup для инициализации методов
    print('Debug: Инициализация ClientTaskService');
    setup();

    // Выводим дополнительную информацию для отладки
    print('Debug: methods = ${methods.map((m) => m.methodName).join(", ")}');
  }

  @override
  ServerStreamingBidiStream<TaskRequest, ProgressMessage> startTask(
      TaskRequest request) {
    print(
        'Debug: serviceName = $serviceName, methodName = ${TaskServiceContract.startTaskMethod}');

    return _endpoint
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
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientTaskService clientService;
    late ServerTaskService serverService;

    setUp(() {
      print('\nDebug: === Начало настройки теста ===');

      // Используем фабрику для создания тестового окружения
      final testEnv = TestFactory.setupTestEnvironment(
        contractFactories: [
          (
            type: TaskServiceContract,
            clientFactory: (endpoint) => ClientTaskService(endpoint),
            serverFactory: () => ServerTaskService(),
          ),
        ],
      );

      print('Debug: Окружение теста создано');

      clientEndpoint = testEnv.clientEndpoint;
      serverEndpoint = testEnv.serverEndpoint;

      // Получаем конкретные реализации из мапы расширений
      clientService = testEnv.clientContract as ClientTaskService;
      serverService = testEnv.serverContract as ServerTaskService;

      // Дополнительная явная регистрация метода startTask
      print('Debug: Явная регистрация метода startTask с вызовом напрямую');
      serverEndpoint
          .serverStreaming(
            serviceName: 'TaskService',
            methodName: 'startTask',
          )
          .register<TaskRequest, ProgressMessage>(
            handler: serverService.startTask,
            requestParser: TaskRequest.fromJson,
            responseParser: ProgressMessage.fromJson,
          );

      print('Debug: Клиентский сервис: ${clientService.serviceName}');
      print('Debug: Серверный сервис: ${serverService.serviceName}');
      print('Debug: === Завершение настройки теста ===\n');
    });

    tearDown(() async {
      await TestFixtureUtils.tearDown(clientEndpoint, serverEndpoint);
    });

    test('Базовый тест серверного стриминга', () async {
      // Создаём запрос
      final request = createTaskRequest(steps: 5);

      // Получаем стрим
      final progressStream = clientService.startTask(request);

      // Собираем все ответы
      final responses = await progressStream.toList();

      // Проверяем, что получили нужное количество ответов
      expect(responses.length,
          equals(request.steps + 1)); // +1 для начального статуса

      // Проверяем первое сообщение (начальный статус)
      expect(responses.first.taskId, equals(request.taskId));
      expect(responses.first.progress, equals(0));
      expect(responses.first.status, equals('initializing'));

      // Проверяем последнее сообщение (завершение)
      expect(responses.last.taskId, equals(request.taskId));
      expect(responses.last.progress, equals(100));
      expect(responses.last.status, equals('completed'));

      // Проверяем, что прогресс увеличивается
      for (int i = 0; i < responses.length - 1; i++) {
        expect(responses[i].progress <= responses[i + 1].progress, isTrue);
      }
    });

    test('Тест с большим количеством шагов', () async {
      // Создаём запрос с большим количеством шагов
      final request = createTaskRequest(steps: 20);

      // Получаем стрим
      final progressStream = clientService.startTask(request);

      // Собираем все ответы
      final responses = await progressStream.toList();

      // Проверяем, что получили нужное количество ответов
      expect(responses.length,
          equals(request.steps + 1)); // +1 для начального статуса

      // Проверяем, что последнее сообщение имеет прогресс 100%
      expect(responses.last.progress, equals(100));
      expect(responses.last.status, equals('completed'));
    });

    test('Обработка потока событий последовательно', () async {
      // Создаём запрос
      final request = createTaskRequest(steps: 10);

      // Получаем стрим
      final progressStream = clientService.startTask(request);

      // Проверяем, что события приходят последовательно с увеличивающимся прогрессом
      int lastProgress = -1;

      await for (final progress in progressStream) {
        expect(progress.progress >= lastProgress, isTrue);
        lastProgress = progress.progress;
      }

      // Проверяем, что прогресс дошел до 100%
      expect(lastProgress, equals(100));
    });
  });
}
