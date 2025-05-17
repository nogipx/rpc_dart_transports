import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

import 'server_streaming_models.dart';

final _logger = RpcLogger('ServerStreamingExample');

/// Пример использования серверного стриминга (один запрос -> поток ответов)
/// Демонстрирует мониторинг прогресса выполнения длительной задачи
Future<void> main({bool debug = true}) async {
  printHeader('Пример серверного стриминга');

  // Создаем транспорты в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);

  // Создаем эндпоинты с метками для отладки
  final client = RpcEndpoint(transport: clientTransport, debugLabel: 'client');
  final server = RpcEndpoint(transport: serverTransport, debugLabel: 'server');

  if (debug) {
    server.addMiddleware(DebugMiddleware(RpcLogger('server')));
    client.addMiddleware(DebugMiddleware(RpcLogger('client')));
  } else {
    server.addMiddleware(LoggingMiddleware(RpcLogger('server')));
    client.addMiddleware(LoggingMiddleware(RpcLogger('client')));
  }

  // Регистрируем метод на сервере
  // Создаем сервисный контракт для сервиса задач
  final serverContract = ServerTaskService();
  final clientContract = ClientTaskService(client);

  // Регистрируем контракт на сервере
  server.registerServiceContract(serverContract);
  client.registerServiceContract(clientContract);

  // Демонстрация прогресса задачи
  await demonstrateTaskProgress(client);

  printHeader('Пример завершен');
}

abstract class TaskServiceContract extends RpcServiceContract {
  TaskServiceContract() : super('TaskService');

  static const String methodName = 'startTask';

  @override
  void setup() {
    addServerStreamingMethod(
      methodName: methodName,
      handler: handler,
      argumentParser: TaskRequest.fromJson,
      responseParser: ProgressMessage.fromJson,
    );
    super.setup();
  }

  ServerStreamingBidiStream<TaskRequest, ProgressMessage> handler(
    TaskRequest request,
  );
}

class ServerTaskService extends TaskServiceContract {
  @override
  ServerStreamingBidiStream<TaskRequest, ProgressMessage> handler(
    TaskRequest request,
  ) {
    _logger.info(
      'Сервер: Начинаем задачу "${request.taskName}" (ID: ${request.taskId})',
    );

    final bidiStream =
        BidiStreamGenerator<TaskRequest, ProgressMessage>((requests) async* {
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

          _logger.info(
            'Сервер: Задача "${request.taskName}" успешно завершена',
          );
        }).create();

    // Оборачиваем BidiStream в ServerStreamingBidiStream
    final serverStream =
        ServerStreamingBidiStream<TaskRequest, ProgressMessage>(
          stream: bidiStream,
          sendFunction: bidiStream.send,
          closeFunction: bidiStream.close,
        );

    // Отправляем начальный запрос в стрим
    serverStream.sendRequest(request);

    return serverStream;
  }
}

class ClientTaskService extends TaskServiceContract {
  final RpcEndpoint endpoint;

  ClientTaskService(this.endpoint);

  @override
  ServerStreamingBidiStream<TaskRequest, ProgressMessage> handler(
    TaskRequest request,
  ) {
    return endpoint
        .serverStreaming(
          serviceName: serviceName,
          methodName: TaskServiceContract.methodName,
        )
        .call<TaskRequest, ProgressMessage>(
          request: request,
          responseParser: ProgressMessage.fromJson,
        );
  }
}

/// Печатает заголовок раздела
void printHeader(String title) {
  _logger.info('-------------------------');
  _logger.info(' $title');
  _logger.info('-------------------------');
}

/// Возвращает иконку статуса
String _getStatusIcon(String status) {
  switch (status) {
    case 'initializing':
      return '🔄';
    case 'in_progress':
      return '🔹';
    case 'processing':
      return '🔧';
    case 'analyzing':
      return '🔍';
    case 'completed':
      return '✅';
    default:
      return '📊';
  }
}

/// Формирует строку индикатора прогресса
String _buildProgressBar(int percent) {
  final barLength = 10;
  final filled = (barLength * percent / 100).round();
  final empty = barLength - filled;
  return '[${'█' * filled}${' ' * empty}]';
}

/// Демонстрация прогресса задачи
Future<void> demonstrateTaskProgress(RpcEndpoint client) async {
  printHeader('Мониторинг длительного процесса');

  // Создаем запрос на выполнение сложной задачи
  final request = TaskRequest(
    taskId: 'data-proc-${DateTime.now().millisecondsSinceEpoch}',
    taskName: 'Анализ большого набора данных',
    steps: 10,
  );

  _logger.info(
    '🚀 Запускаем задачу "${request.taskName}" (ID: ${request.taskId})',
  );
  _logger.info('Запрос отправлен, ожидаем получение потока обновлений...');

  // Открываем стрим для получения обновлений о прогрессе
  final stream = client
      .serverStreaming(serviceName: 'TaskService', methodName: 'startTask')
      .call<TaskRequest, ProgressMessage>(
        request: request,
        responseParser: ProgressMessage.fromJson,
      );

  try {
    _logger.info('Прогресс выполнения:');
    _logger.info('┌────────────────────────────────────────────────────┐');

    // Отображаем индикатор прогресса
    await for (final progress in stream) {
      // Формируем строку прогресса
      final progressBar = _buildProgressBar(progress.progress);
      final statusIcon = _getStatusIcon(progress.status);

      // Очищаем предыдущую строку и выводим новый прогресс
      _logger.info(
        '│ $statusIcon $progressBar ${progress.progress.toString().padLeft(3)}% │',
      );

      if (progress.status == 'completed') {
        _logger.info('✅ Задача успешно завершена!');
        _logger.info('Итоговый отчет:');

        _logger.info('  • ID задачи: ${progress.taskId}');
        _logger.info('  • Время выполнения: ${DateTime.now().toString()}');
        _logger.info('  • Результат: ${progress.message}');
      }
    }
  } catch (e) {
    _logger.error(
      'Произошла ошибка при получении обновлений',
      error: {'error': e.toString()},
    );
  }
}
