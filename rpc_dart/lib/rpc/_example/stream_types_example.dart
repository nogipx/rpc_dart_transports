part of '_index.dart';

/// Запускает пример использования различных типов стримов
Future<void> runStreamTypesExample() async {
  await StreamTypesExample.runAll();
}

/// Пример использования различных типов стримов.
///
/// Демонстрирует использование трех типов стриминга:
/// - Двунаправленного (bidirectional)
/// - Серверного (server)
/// - Клиентского (client)
class StreamTypesExample {
  /// Запускает демонстрацию серверного стриминга (один запрос, много ответов).
  static Future<void> runServerStreaming() async {
    print('\n=== Пример серверного стриминга (1 запрос -> N ответов) ===\n');

    // Создаем пару соединенных транспортов
    final (clientTransport, serverTransport) = InMemoryTransportPair.create();

    // Создаем сериализаторы для строк
    final stringSerializer = const SimpleStringSerializer();

    // Инициализируем серверную часть с обработчиком
    final server = ServerStreamServer<String, String>(
      transport: serverTransport,
      requestSerializer: stringSerializer,
      responseSerializer: stringSerializer,
      handler: (request, responder) async {
        print('СЕРВЕР: Получен запрос: "$request"');

        // Отправляем несколько ответов с задержкой
        for (int i = 1; i <= 5; i++) {
          final response = 'Ответ #$i на запрос "$request"';
          print('СЕРВЕР: Отправляем: "$response"');
          responder.send(response);

          // Делаем реальную задержку между ответами
          await Future.delayed(Duration(milliseconds: 50));
        }

        // Завершаем поток ответов
        print('СЕРВЕР: Завершаем поток ответов');
        responder.complete();
      },
    );

    // Инициализируем клиентскую часть
    final client = ServerStreamClient<String, String>(
      transport: clientTransport,
      requestSerializer: stringSerializer,
      responseSerializer: stringSerializer,
    );

    // Подписываемся на поток ответов
    final subscription = client.responses.listen(
      (message) {
        if (!message.isMetadataOnly) {
          print('КЛИЕНТ: Получен ответ: "${message.payload}"');
        }
      },
      onError: (error, stackTrace) {
        if (error.toString().contains('Cannot add event after closing')) {
          print('КЛИЕНТ: Игнорируем ожидаемую ошибку при закрытии потока');
        } else {
          print('КЛИЕНТ: Ошибка: $error');
        }
      },
      onDone: () {
        print('КЛИЕНТ: Поток ответов завершен');
      },
    );

    // Отправляем единственный запрос
    print('КЛИЕНТ: Отправляем запрос: "Дай мне данные"');
    await client.send('Дай мне данные');

    // Ждем завершения обработки всех ответов
    print('КЛИЕНТ: Ждем завершения обработки...');
    await Future.delayed(Duration(milliseconds: 1000));

    print('КЛИЕНТ: Поток ответов должен уже завершиться...');
    // Закрываем ресурсы
    await subscription.cancel();
    await client.close();
    await server.close();

    print('\n=== Пример серверного стриминга завершен ===\n');
  }

  /// Запускает демонстрацию клиентского стриминга (много запросов, один ответ).
  static Future<void> runClientStreaming() async {
    print('\n=== Пример клиентского стриминга (N запросов -> 1 ответ) ===\n');

    // Создаем пару соединенных транспортов
    final (clientTransport, serverTransport) = InMemoryTransportPair.create();

    // Создаем сериализаторы для строк
    final stringSerializer = const SimpleStringSerializer();

    // Инициализируем серверную часть с обработчиком
    final server = ClientStreamServer<String, String>(
      transport: serverTransport,
      requestSerializer: stringSerializer,
      responseSerializer: stringSerializer,
      handler: (Stream<String> requests) async {
        print('СЕРВЕР: Ожидаем запросы...');

        int count = 0;
        await for (final request in requests) {
          print('  - $request');
          count++;
        }

        // Небольшая задержка перед отправкой ответа
        await Future.delayed(Duration(milliseconds: 50));

        // Формируем и возвращаем итоговый ответ
        final response = 'Обработано $count запросов';
        print('СЕРВЕР: Отправляем ответ: "$response"');
        return response;
      },
    );

    // Инициализируем клиентскую часть
    final client = ClientStreamClient<String, String>(
      transport: clientTransport,
      requestSerializer: stringSerializer,
      responseSerializer: stringSerializer,
    );

    // Отправляем несколько запросов
    final requests = [
      'Часть 1: Привет',
      'Часть 2: Как дела?',
      'Часть 3: Это тест',
      'Часть 4: Клиентского',
      'Часть 5: Стриминга!'
    ];

    for (final request in requests) {
      print('КЛИЕНТ: Отправляем запрос: "$request"');
      client.send(request);
      await Future.delayed(Duration(milliseconds: 50));
    }

    // Ждем итоговый ответ с увеличенным таймаутом
    print('КЛИЕНТ: Ожидаем итоговый ответ от сервера...');
    try {
      // Ждем до 5 секунд, чтобы дать серверу больше времени
      final response = await client.finishSending().timeout(
            Duration(seconds: 5),
            onTimeout: () => 'Таймаут ожидания ответа',
          );
      print('КЛИЕНТ: Получен итоговый ответ: "$response"');
    } catch (e) {
      print('КЛИЕНТ: Ошибка при получении ответа: $e');
    }

    // Ждем завершения обработки
    print('КЛИЕНТ: Ждем завершения обработки...');
    await Future.delayed(Duration(milliseconds: 500));

    // Закрываем ресурсы
    print('КЛИЕНТ: Закрываем ресурсы');
    await client.close();
    await server.close();

    print('\n=== Пример клиентского стриминга завершен ===\n');
  }

  /// Запускает все типы стриминга последовательно для демонстрации
  static Future<void> runAll() async {
    await runServerStreaming();
    await runClientStreaming();
  }
}
