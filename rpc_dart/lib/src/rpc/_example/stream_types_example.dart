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
    RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

    print('\n=== Пример серверного стриминга (1 запрос -> N ответов) ===\n');

    // Создаем пару соединенных транспортов
    final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

    // Создаем сериализаторы для строк
    final stringSerializer = RpcBinarySerializer(RpcString.fromBytes);

    // Инициализируем серверную часть с обработчиком
    final server = ServerStreamResponder<RpcString, RpcString>(
      transport: serverTransport,
      serviceName: 'DataService',
      methodName: 'GetServerStream',
      requestCodec: stringSerializer,
      responseCodec: stringSerializer,
      logger: RpcLogger(
        'ServerStreamingExample',
        colors: RpcLoggerColors.singleColor(AnsiColor.brightGreen),
      ),
      handler: (request, responder) async {
        print('СЕРВЕР: Получен запрос: "$request"');

        // Отправляем несколько ответов с задержкой
        for (int i = 1; i <= 5; i++) {
          final response = 'Ответ #$i на запрос "$request"';
          print('СЕРВЕР: Отправляем: "$response"');
          responder.send(response.rpc);

          // Делаем реальную задержку между ответами
          await Future.delayed(Duration(milliseconds: 50));
        }

        // Завершаем поток ответов
        print('СЕРВЕР: Завершаем поток ответов');
        responder.complete();
      },
    );

    // Инициализируем клиентскую часть
    final client = ServerStreamCaller<RpcString, RpcString>(
      transport: clientTransport,
      serviceName: 'DataService',
      methodName: 'GetServerStream',
      requestCodec: stringSerializer,
      responseCodec: stringSerializer,
      logger: RpcLogger(
        'ServerStreamingExample',
        colors: RpcLoggerColors.singleColor(AnsiColor.brightGreen),
      ),
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
    await client.send('Дай мне данные'.rpc);

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
    RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

    print('\n=== Пример клиентского стриминга (N запросов -> 1 ответ) ===\n');

    // Создаем пару соединенных транспортов
    final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

    // Создаем сериализаторы для строк
    final stringSerializer = RpcBinarySerializer(RpcString.fromBytes);

    // Инициализируем серверную часть с обработчиком
    final server = ClientStreamResponder<RpcString, RpcString>(
      transport: serverTransport,
      serviceName: 'DataAggregatorService',
      methodName: 'ProcessClientStream',
      requestCodec: stringSerializer,
      responseCodec: stringSerializer,
      logger: RpcLogger(
        'ClientStreamingExample',
        colors: RpcLoggerColors.singleColor(AnsiColor.brightMagenta),
      ),
      handler: (Stream<RpcString> requests) async {
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
        return response.rpc;
      },
    );

    // Инициализируем клиентскую часть
    final client = ClientStreamCaller<RpcString, RpcString>(
      transport: clientTransport,
      serviceName: 'DataAggregatorService',
      methodName: 'ProcessClientStream',
      requestCodec: stringSerializer,
      responseCodec: stringSerializer,
      logger: RpcLogger(
        'ClientStreamingExample',
        colors: RpcLoggerColors.singleColor(AnsiColor.brightMagenta),
      ),
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
      client.send(request.rpc);
      await Future.delayed(Duration(milliseconds: 50));
    }

    // Ждем итоговый ответ с увеличенным таймаутом
    print('КЛИЕНТ: Ожидаем итоговый ответ от сервера...');
    try {
      // Ждем до 5 секунд, чтобы дать серверу больше времени
      final response = await client.finishSending().timeout(
            Duration(seconds: 5),
            onTimeout: () => 'Таймаут ожидания ответа'.rpc,
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
