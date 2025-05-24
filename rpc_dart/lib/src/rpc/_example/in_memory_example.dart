part of '_index.dart';

/// Пример использования двунаправленного стрима через транспорт в памяти.
///
/// Демонстрирует, как настроить клиент и сервер в рамках одного потока
/// для обмена сообщениями через InMemoryTransport.
class InMemoryRpcExample {
  /// Запускает демонстрацию работы RPC через транспорт в памяти.
  ///
  /// Создает клиент и сервер в одном потоке и организует
  /// двунаправленный обмен сообщениями между ними.
  static Future<void> run() async {
    RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);
    print('Запуск примера двунаправленного стрима через транспорт в памяти...');

    // Создаем пару соединенных транспортов для клиента и сервера
    final (clientTransport, serverTransport) = RpcInMemoryTransport.pair();

    // Создаем сериализаторы для строк
    final stringSerializer = SimpleStringSerializer();

    // Инициализируем серверную часть
    final server = BidirectionalStreamResponder<String, String>(
      transport: serverTransport,
      serviceName: 'ChatService',
      methodName: 'Connect',
      requestSerializer: stringSerializer,
      responseSerializer: stringSerializer,
      logger: RpcLogger(
        'InMemoryRpcExample',
        colors: RpcLoggerColors.singleColor(AnsiColor.cyan),
      ),
    );

    // Настраиваем обработку запросов на сервере
    final serverSubscription = server.requests.listen((request) {
      print('Сервер получил: $request');

      // Эхо-обработчик с некоторой логикой
      switch (request) {
        case 'ping':
          server.send('pong');
          break;
        case 'время':
          server.send('Текущее время: ${DateTime.now()}');
          break;
        case 'случайное число':
          final random = (DateTime.now().millisecondsSinceEpoch % 100) + 1;
          server.send('Случайное число от 1 до 100: $random');
          break;
        case 'завершить':
          server.send('Сервер завершает работу...');
          // Завершаем отправку с успешным статусом
          server.finishReceiving();
          break;
        default:
          server.send('Эхо: $request');
      }
    });

    // Инициализируем клиентскую часть
    final client = BidirectionalStreamCaller<String, String>(
      transport: clientTransport,
      serviceName: 'ChatService',
      methodName: 'Connect',
      requestSerializer: stringSerializer,
      responseSerializer: stringSerializer,
      logger: RpcLogger(
        'InMemoryRpcExample',
        colors: RpcLoggerColors.singleColor(AnsiColor.black),
      ),
    );

    // Подписываемся на ответы сервера
    final clientSubscription = client.responses.listen((message) {
      if (!message.isMetadataOnly) {
        print('Клиент получил: ${message.payload}');
      } else if (message.metadata != null) {
        final statusCode =
            message.metadata!.getHeaderValue(RpcConstants.GRPC_STATUS_HEADER);

        if (statusCode != null && message.isEndOfStream) {
          print('Соединение завершено со статусом: $statusCode');
        }
      }
    });

    // Отправляем несколько запросов с небольшой задержкой
    final requests = [
      'ping',
      'время',
      'случайное число',
      'привет, мир!',
      'завершить'
    ];

    for (final request in requests) {
      print('Клиент отправляет: $request');
      client.send(request);
      await Future.delayed(Duration(milliseconds: 100));
    }

    // Завершаем отправку запросов с клиента
    client.finishSending();

    // Ждем завершения обработки всех сообщений
    await Future.delayed(Duration(milliseconds: 500));

    // Закрываем подписки и освобождаем ресурсы
    await clientSubscription.cancel();
    await serverSubscription.cancel();
    await client.close();
    await server.close();

    print('Пример завершен.');
  }
}

/// Запускает пример использования двунаправленного стрима через InMemoryTransport.
Future<void> runInMemoryExample() async {
  await InMemoryRpcExample.run();
}
