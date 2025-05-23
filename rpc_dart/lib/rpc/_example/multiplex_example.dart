part of '_index.dart';

/// Запускает пример мультиплексированных унарных вызовов
Future<void> runMultiplexExample() async {
  await MultiplexRpcExample.run();
}

/// Пример использования мультиплексирующего транспорта.
///
/// Демонстрирует возможность выполнения нескольких параллельных
/// унарных вызовов через один транспорт.
class MultiplexRpcExample {
  /// Запускает демонстрацию мультиплексированных вызовов.
  ///
  /// Создает один мультиплексирующий транспорт и выполняет
  /// через него несколько параллельных унарных вызовов.
  static Future<void> run() async {
    print('\n=== Запуск примера мультиплексированных вызовов ===\n');

    // Создаем базовый транспорт
    final (clientBaseTransport, serverBaseTransport) =
        RpcInMemoryTransport.pair();

    // Создаем мультиплексирующий транспорт для клиента
    final clientMultiplexTransport = RpcMultiplexTransport(
      baseTransport: clientBaseTransport,
      logger: RpcLogger(
        "ClientMultiplex",
        colors: RpcLoggerColors.singleColor(AnsiColor.brightCyan),
      ),
    );

    // Создаем мультиплексирующий транспорт для сервера
    final serverMultiplexTransport = RpcMultiplexTransport(
      baseTransport: serverBaseTransport,
      logger: RpcLogger(
        "ServerMultiplex",
        colors: RpcLoggerColors.singleColor(AnsiColor.brightGreen),
      ),
    );

    // Настраиваем сериализатор
    final stringSerializer = SimpleStringSerializer();

    // Обработчик для всех типов запросов
    Future<String> requestHandler(String request) async {
      // Добавляем случайную задержку для эмуляции различных времен обработки
      final delay =
          (100 + (DateTime.now().millisecondsSinceEpoch % 300)).toInt();
      print('СЕРВЕР: Получен запрос: "$request", обработка займет ${delay}мс');
      await Future.delayed(Duration(milliseconds: delay));

      // Обрабатываем запрос
      switch (request.toLowerCase()) {
        case 'привет':
          return 'Здравствуйте!';
        case 'время':
          return 'Текущее время: ${DateTime.now()}';
        case 'статус':
          return 'Все системы работают нормально';
        case 'случайное число':
          final random = (DateTime.now().millisecondsSinceEpoch % 100) + 1;
          return 'Случайное число от 1 до 100: $random';
        case 'ошибка':
          throw Exception('Тестовая ошибка');
        default:
          return 'Эхо: $request';
      }
    }

    // Создаем список параллельных запросов
    final requests = [
      'Привет',
      'Время',
      'Статус',
      'Случайное число',
      'Эхо-тест',
      'Ошибка',
    ];

    // Для каждого запроса создаем отдельный сервер
    final servers = <UnaryServer>[];

    try {
      print('КЛИЕНТ: Запуск ${requests.length} параллельных вызовов\n');

      // Запускаем параллельно все вызовы
      final futures = <Future<void>>[];

      for (int i = 0; i < requests.length; i++) {
        final request = requests[i];
        final callId = i + 1;

        // Создаем серверный транспорт и сервер для каждого вызова
        final serverCallTransport =
            serverMultiplexTransport.createCallTransport('ServerCall-$callId');
        final server = UnaryServer<String, String>(
          transport: serverCallTransport,
          requestSerializer: stringSerializer,
          responseSerializer: stringSerializer,
          handler: requestHandler,
          logger: RpcLogger(
            "Server-$callId",
            colors: RpcLoggerColors.singleColor(AnsiColor.brightGreen),
          ),
        );
        servers.add(server);

        // Создаем клиентский транспорт и клиент для вызова
        final clientCallTransport =
            clientMultiplexTransport.createCallTransport('ClientCall-$callId');
        final client = UnaryClient<String, String>(
          transport: clientCallTransport,
          requestSerializer: stringSerializer,
          responseSerializer: stringSerializer,
          logger: RpcLogger(
            "Client-$callId",
            colors: RpcLoggerColors.singleColor(AnsiColor.brightMagenta),
          ),
        );

        // Запускаем вызов асинхронно
        final future = () async {
          try {
            print('КЛИЕНТ-$callId: Отправка запроса "$request"');

            // Устанавливаем увеличенный таймаут для демонстрации
            final response = await client.call(
              request,
              timeout: Duration(seconds: 5),
            );

            print('КЛИЕНТ-$callId: Получен ответ: "$response"');
          } catch (e) {
            print('КЛИЕНТ-$callId: Ошибка: $e');
          } finally {
            await client.close();
          }
        }();

        futures.add(future);
      }

      // Ждем завершения всех вызовов
      await Future.wait(futures);
    } finally {
      // Закрываем все серверы
      for (final server in servers) {
        await server.close();
      }

      // Закрываем транспорты
      await clientMultiplexTransport.close();
      await serverMultiplexTransport.close();
    }

    print('\n=== Пример мультиплексированных вызовов завершен ===\n');
  }
}
