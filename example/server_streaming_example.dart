import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования серверного стриминга (один запрос -> поток ответов)
void main() async {
  print('=== Пример серверного стриминга ===\n');

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

  try {
    // Регистрируем методы на сервере
    registerServerMethods(server);
    print('Методы зарегистрированы');

    // Демонстрация числовой последовательности
    await demonstrateNumberSequence(client);

    // Демонстрация прогресса задачи
    await demonstrateTaskProgress(client);

    // Демонстрация типизированного серверного стриминга
    await demonstrateTypedServerStreaming(client);

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
  // Создаем сервисные контракты для каждого сервиса
  final numberServiceContract = SimpleRpcServiceContract('NumberService');
  final taskServiceContract = SimpleRpcServiceContract('TaskService');
  final errorServiceContract = SimpleRpcServiceContract('ErrorService');

  // Регистрируем контракты на сервере
  server.registerServiceContract(numberServiceContract);
  server.registerServiceContract(taskServiceContract);
  server.registerServiceContract(errorServiceContract);

  // 1. Генерация числовой последовательности
  server
      .serverStreaming('NumberService', 'generateSequence')
      .register<RpcInt, RpcNum>(
        handler: (request) async* {
          print(
              'Сервер начал генерацию последовательности до ${request.value}');

          for (int i = 1; i <= request.value; i++) {
            await Future.delayed(Duration(milliseconds: 300));
            yield RpcNum(i);
          }

          print('Сервер завершил генерацию последовательности');
        },
        requestParser: RpcInt.fromJson,
        responseParser: RpcNum.fromJson,
      );

  // 2. Имитация прогресса задачи
  server
      .serverStreaming('TaskService', 'startTask')
      .register<TaskRequest, ProgressMessage>(
        handler: (request) async* {
          print('Сервер начал задачу "${request.taskName}"');

          final int steps = request.steps;

          for (int i = 0; i <= steps; i++) {
            final progress = (i / steps * 100).round();

            await Future.delayed(Duration(milliseconds: 500));

            yield ProgressMessage(
              taskId: request.taskId,
              progress: progress,
              status: i == steps ? 'completed' : 'in_progress',
              message: i == steps ? 'Задача завершена' : 'Выполнено $progress%',
            );
          }
        },
        requestParser: TaskRequest.fromJson,
        responseParser: ProgressMessage.fromJson,
      );

  // 3. Метод с ошибкой
  server
      .serverStreaming('ErrorService', 'riskyOperation')
      .register<RpcBool, ResultMessage>(
        handler: (request) async* {
          print(
              'Сервер начал рискованную операцию (shouldFail=${request.value})');

          for (int i = 1; i <= 5; i++) {
            // Имитация сбоя на 3-м шаге, если shouldFail = true
            if (i == 3 && request.value) {
              throw Exception('Произошла ошибка на шаге $i');
            }

            await Future.delayed(Duration(milliseconds: 300));
            yield ResultMessage(step: i, data: 'Данные шага $i');
          }
        },
        requestParser: RpcBool.fromJson,
        responseParser: ResultMessage.fromJson,
      );
}

/// Демонстрация генерации числовой последовательности
Future<void> demonstrateNumberSequence(RpcEndpoint client) async {
  print('\n--- Генерация числовой последовательности ---');

  final request = RpcInt(5);

  print('Клиент запрашивает последовательность до ${request.value}');

  final stream = client
      .serverStreaming('NumberService', 'generateSequence')
      .openStream<RpcInt, RpcNum>(
        request: request,
        responseParser: RpcNum.fromJson,
      );

  print('Получаем числа:');

  await for (final number in stream) {
    print('  Получено число: ${number.value}');
  }

  print('Последовательность завершена');
}

/// Демонстрация прогресса задачи
Future<void> demonstrateTaskProgress(RpcEndpoint client) async {
  print('\n--- Прогресс задачи ---');

  final request = TaskRequest(
    taskId: 'task-${DateTime.now().millisecondsSinceEpoch}',
    taskName: 'Демонстрационная задача',
    steps: 5,
  );

  print('Клиент запускает задачу "${request.taskName}"');

  final stream = client
      .serverStreaming('TaskService', 'startTask')
      .openStream<TaskRequest, ProgressMessage>(
        request: request,
        responseParser: ProgressMessage.fromJson,
      );

  print('Отслеживаем прогресс:');

  await for (final progress in stream) {
    final icon = progress.status == 'completed' ? '✅' : '⏳';
    print('  $icon ${progress.progress}%: ${progress.message}');
  }
}

/// Демонстрация типизированного серверного стриминга с автоматической сериализацией
Future<void> demonstrateTypedServerStreaming(RpcEndpoint client) async {
  // Этот пример аналогичен предыдущим, но показывает возможность
  // регистрации обработчика через RpcServiceContract (см. calculator_example.dart)
}

/// Демонстрация обработки ошибок
Future<void> demonstrateErrorHandling(RpcEndpoint client) async {
  print('\n--- Обработка ошибок в стриме ---');

  // 1. Сначала демонстрация успешного завершения
  print('Запуск успешной операции...');

  final successRequest = RpcBool(false);

  final successStream = client
      .serverStreaming('ErrorService', 'riskyOperation')
      .openStream<RpcBool, ResultMessage>(
        request: successRequest,
        responseParser: ResultMessage.fromJson,
      );

  try {
    await for (final result in successStream) {
      print('  Шаг ${result.step}: ${result.data}');
    }
    print('Операция успешно завершена');
  } catch (e) {
    print('  Ошибка: $e');
  }

  // 2. Теперь демонстрация с ошибкой
  print('\nЗапуск операции с ошибкой...');

  final failRequest = RpcBool(true);

  final failStream = client
      .serverStreaming('ErrorService', 'riskyOperation')
      .openStream<RpcBool, ResultMessage>(
        request: failRequest,
        responseParser: ResultMessage.fromJson,
      );

  try {
    await for (final result in failStream) {
      print('  Шаг ${result.step}: ${result.data}');
    }
    print('Этот код не должен выполниться');
  } catch (e) {
    print('  Перехвачена ошибка: $e');
  }
}

/// Запрос на выполнение задачи
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

/// Сообщение о прогрессе
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

// /// Запрос для операции с риском ошибки
// class RiskyRequest implements IRpcSerializableMessage {
//   final bool shouldFail;

//   RiskyRequest({required this.shouldFail});

//   @override
//   Map<String, dynamic> toJson() => {'shouldFail': shouldFail};

//   static RiskyRequest fromJson(Map<String, dynamic> json) {
//     return RiskyRequest(shouldFail: json['shouldFail'] as bool);
//   }
// }

/// Сообщение с результатом
class ResultMessage implements IRpcSerializableMessage {
  final int step;
  final String data;

  ResultMessage({required this.step, required this.data});

  @override
  Map<String, dynamic> toJson() => {'step': step, 'data': data};

  static ResultMessage fromJson(Map<String, dynamic> json) {
    return ResultMessage(
      step: json['step'] as int,
      data: json['data'] as String,
    );
  }
}
