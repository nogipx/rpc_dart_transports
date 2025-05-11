import 'package:rpc_dart/rpc_dart.dart';

import 'server_streaming_models.dart';

/// Пример использования серверного стриминга (один запрос -> поток ответов)
/// Демонстрирует мониторинг прогресса выполнения длительной задачи
Future<void> main({bool debug = false}) async {
  print('=== Пример серверного стриминга ===\n');

  // Создаем транспорты в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  print('Транспорты соединены');

  // Создаем эндпоинты с метками для отладки
  final client = RpcEndpoint(transport: clientTransport, debugLabel: 'client');
  final server = RpcEndpoint(transport: serverTransport, debugLabel: 'server');
  print('Эндпоинты созданы');

  if (debug) {
    server.addMiddleware(DebugMiddleware(id: "server"));
    client.addMiddleware(DebugMiddleware(id: "client"));
  } else {
    server.addMiddleware(LoggingMiddleware(id: "server"));
    client.addMiddleware(LoggingMiddleware(id: 'client'));
  }

  try {
    // Регистрируем метод на сервере
    registerTaskService(server);
    print('Сервис задач зарегистрирован');

    // Демонстрация прогресса задачи
    await demonstrateTaskProgress(client);
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

/// Регистрация сервиса задач на сервере
void registerTaskService(RpcEndpoint server) {
  // Создаем сервисный контракт для сервиса задач
  final taskServiceContract = SimpleRpcServiceContract('TaskService');

  // Регистрируем контракт на сервере
  server.registerServiceContract(taskServiceContract);

  // Имитация прогресса задачи
  server
      .serverStreaming(serviceName: 'TaskService', methodName: 'startTask')
      .register<TaskRequest, ProgressMessage>(
        handler: (request) async* {
          print(
            'Сервер: Начинаем задачу "${request.taskName}" (ID: ${request.taskId})',
          );

          final int steps = request.steps;
          final List<String> stages = [
            'initializing',
            'in_progress',
            'processing',
            'analyzing',
            'in_progress',
          ];
          final List<String> messages = [
            'Инициализация анализа...',
            'Загрузка набора данных...',
            'Предварительная обработка...',
            'Статистический анализ...',
            'Обработка результатов...',
            'Генерация отчетов...',
            'Применение фильтров...',
            'Оптимизация данных...',
            'Финальная проверка...',
            'Формирование результатов...',
          ];

          // Начальный статус
          yield ProgressMessage(
            taskId: request.taskId,
            progress: 0,
            status: 'initializing',
            message: 'Задача запущена. Подготовка к выполнению...',
          );

          await Future.delayed(Duration(milliseconds: 500));

          // Имитация процесса обработки
          for (int i = 1; i <= steps; i++) {
            final progress = (i / steps * 100).round();
            final stageIndex = i % stages.length;
            final messageIndex = i - 1;
            final status = i == steps ? 'completed' : stages[stageIndex];
            final message =
                i == steps
                    ? 'Обработано ${(3000 + (i * 500)).toStringAsFixed(0)} элементов данных'
                    : messages[messageIndex];

            // Разная задержка для разных этапов
            final delay =
                status == 'analyzing'
                    ? Duration(milliseconds: 1000)
                    : Duration(milliseconds: 500);
            await Future.delayed(delay);

            yield ProgressMessage(
              taskId: request.taskId,
              progress: progress,
              status: status,
              message: message,
            );
          }

          print('Сервер: Задача "${request.taskName}" успешно завершена');
        },
        requestParser: TaskRequest.fromJson,
        responseParser: ProgressMessage.fromJson,
      );
}

/// Демонстрация прогресса задачи
Future<void> demonstrateTaskProgress(RpcEndpoint client) async {
  print('\n--- Мониторинг длительного процесса ---');

  // Создаем запрос на выполнение сложной задачи
  final request = TaskRequest(
    taskId: 'data-proc-${DateTime.now().millisecondsSinceEpoch}',
    taskName: 'Анализ большого набора данных',
    steps: 10,
  );

  print('🚀 Запускаем задачу "${request.taskName}" (ID: ${request.taskId})');
  print('⌛ Запрос отправлен, ожидаем получение потока обновлений...');

  // Открываем стрим для получения обновлений о прогрессе
  final stream = client
      .serverStreaming(serviceName: 'TaskService', methodName: 'startTask')
      .call<TaskRequest, ProgressMessage>(
        request: request,
        responseParser: ProgressMessage.fromJson,
      );

  print('\n📊 Прогресс выполнения:');
  print('┌────────────────────────────────────────────────────┐');

  // Отображаем индикатор прогресса
  await for (final progress in stream) {
    // Формируем строку прогресса
    final progressBar = _buildProgressBar(progress.progress);
    final statusIcon = _getStatusIcon(progress.status);

    // Очищаем предыдущую строку и выводим новый прогресс
    print(
      '│ $statusIcon $progressBar ${progress.progress.toString().padLeft(3)}% │',
    );

    if (progress.status == 'completed') {
      print('└────────────────────────────────────────────────────┘');
      print('\n✅ Задача успешно завершена!');
      print('📋 Итоговый отчет:');
      print('  • ID задачи: ${progress.taskId}');
      print('  • Время выполнения: ${DateTime.now().toString()}');
      print('  • Результат: ${progress.message}');
    }
  }
}

/// Возвращает иконку статуса
String _getStatusIcon(String status) {
  switch (status) {
    case 'initializing':
      return '🔄';
    case 'in_progress':
      return '⏳';
    case 'processing':
      return '🔍';
    case 'analyzing':
      return '📊';
    case 'completed':
      return '✅';
    case 'error':
      return '❌';
    default:
      return '⏱️';
  }
}

/// Создает строку прогресса
String _buildProgressBar(int progress) {
  const barLength = 30;
  final completed = (progress / 100 * barLength).round();
  final remaining = barLength - completed;

  return '[${'█' * completed}${' ' * remaining}]';
}
