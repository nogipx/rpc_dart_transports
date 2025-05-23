part of '_index.dart';

/// Запускает пример использования унарного RPC вызова
Future<void> runUnaryExample() async {
  await UnaryRpcExample.run();
}

/// Пример использования унарного RPC вызова.
///
/// Демонстрирует простой запрос-ответ с использованием UnaryClient и UnaryServer.
class UnaryRpcExample {
  /// Запускает демонстрацию унарного RPC вызова.
  ///
  /// Создает клиент и сервер в одном потоке и выполняет
  /// несколько унарных вызовов разных типов.
  static Future<void> run() async {
    print('\n=== Запуск примера унарного RPC вызова ===\n');

    // Создаем пару соединенных транспортов для клиента и сервера
    final pairs = <(IRpcTransport, IRpcTransport)>[];

    // Создаем 5 пар транспортов для разных вызовов
    for (int i = 0; i < 5; i++) {
      pairs.add(RpcInMemoryTransport.pair());
    }

    // Создаем сериализаторы для строк
    final stringSerializer = SimpleStringSerializer();

    // Инициализируем серверную часть для каждого транспорта
    final servers = <UnaryServer>[];

    for (final (_, serverTransport) in pairs) {
      final server = UnaryServer<String, String>(
        transport: serverTransport,
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
        handler: (request) {
          print('СЕРВЕР: Получен запрос: "$request"');

          // Обрабатываем разные запросы
          switch (request.toLowerCase()) {
            case 'привет':
              return 'Здравствуйте!';
            case 'время':
              return 'Текущее время: ${DateTime.now()}';
            case 'статус':
              return 'Все системы работают нормально';
            case 'ошибка':
              throw Exception('Тестовая ошибка');
            default:
              return 'Эхо: $request';
          }
        },
      );

      servers.add(server);
    }

    try {
      // Пример 1: Простой вызов
      print('КЛИЕНТ: Выполняем запрос "Привет"');
      final client1 = UnaryClient<String, String>(
        transport: pairs[0].$1,
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
      );
      final response1 = await client1.call('Привет');
      print('КЛИЕНТ: Получен ответ: "$response1"');
      await client1.close();

      // Пример 2: Запрос с данными
      print('\nКЛИЕНТ: Выполняем запрос "Время"');
      final client2 = UnaryClient<String, String>(
        transport: pairs[1].$1,
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
      );
      final response2 = await client2.call('Время');
      print('КЛИЕНТ: Получен ответ: "$response2"');
      await client2.close();

      // Пример 3: Запрос с таймаутом
      print('\nКЛИЕНТ: Выполняем запрос "Статус" с таймаутом 500мс');
      final client3 = UnaryClient<String, String>(
        transport: pairs[2].$1,
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
      );
      final response3 = await client3.call(
        'Статус',
        timeout: Duration(milliseconds: 500),
      );
      print('КЛИЕНТ: Получен ответ: "$response3"');
      await client3.close();

      // Пример 4: Вызов с ошибкой
      print('\nКЛИЕНТ: Выполняем запрос "Ошибка" (должен вернуть ошибку)');
      final client4 = UnaryClient<String, String>(
        transport: pairs[3].$1,
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
      );
      try {
        await client4.call('Ошибка');
      } catch (e) {
        print('КЛИЕНТ: Получена ожидаемая ошибка: $e');
      }
      await client4.close();

      // Пример 5: Запрос с очень коротким таймаутом
      print('\nКЛИЕНТ: Выполняем запрос с очень коротким таймаутом (10мс)');
      final client5 = UnaryClient<String, String>(
        transport: pairs[4].$1,
        requestSerializer: stringSerializer,
        responseSerializer: stringSerializer,
      );
      try {
        await client5.call(
          'Запрос с очень коротким таймаутом',
          timeout: Duration(milliseconds: 10),
        );
      } catch (e) {
        print('КЛИЕНТ: Получена ошибка таймаута: $e');
      }
      await client5.close();
    } finally {
      // Закрываем все серверы
      for (final server in servers) {
        await server.close();
      }
    }

    print('\n=== Пример унарного RPC вызова завершен ===\n');
  }
}
