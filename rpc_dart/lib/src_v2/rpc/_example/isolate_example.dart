part of '_index.dart';

/// Пример использования изолята с пользовательской entrypoint функцией
Future<void> runIsolateExample() async {
  print('\n=== Запуск примера с пользовательским entrypoint ===\n');

  // Запускаем изолят с пользовательской entrypoint функцией
  final result = await RpcIsolateTransport.spawn(
    entrypoint: customEchoServer,
    customParams: {
      'log': (String message) => print('rpc customlog: $message'),
      'serverName': 'CustomEchoServer',
      'messagePrefix': '[ECHO]: ',
    },
    isolateId: 'echo-server',
    debugName: 'EchoServer Isolate',
  );

  final killIsolate = result.kill;

  print('Изолят запущен, настраиваем клиент...');

  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Создаем клиент для двустороннего потока
  final client = BidirectionalStreamCaller<String, String>(
    transport: result.transport,
    serviceName: 'EchoService',
    methodName: 'Echo',
    requestSerializer: const SimpleStringSerializer(),
    responseSerializer: const SimpleStringSerializer(),
    logger: RpcLogger(
      "Host",
      colors: RpcLoggerColors.singleColor(AnsiColor.brightMagenta),
    ),
  );

  // Подписываемся на ответы
  final subscription = client.responses.listen((message) {
    print('КЛИЕНТ: Получен ответ: "${message.payload}"');
  }, onError: (error) {
    print('КЛИЕНТ: Ошибка: $error');
  });

  // Отправляем запросы
  print('\nОтправляем запрос: "Привет, сервер!"');
  client.send('Привет, сервер!');

  await Future.delayed(Duration(milliseconds: 500));

  print('\nОтправляем запрос: "Как дела?"');
  client.send('Как дела?');

  await Future.delayed(Duration(milliseconds: 500));

  print('\nОтправляем запрос: "Проверка эхо"');
  client.send('Проверка эхо');

  // Ждем обработки сообщений
  await Future.delayed(Duration(seconds: 1));

  // Завершаем отправку
  print('\nЗавершаем отправку...');
  client.finishSending();

  // Отменяем подписку на ответы
  await subscription.cancel();

  // Завершаем работу
  print('\nЗавершаем работу транспорта...');
  await client.close();

  // Убиваем изолят
  killIsolate();

  print('\n=== Пример завершен ===');
}

/// Пользовательская функция сервера, получающая готовый транспорт
@pragma('vm:entry-point')
void customEchoServer(
  IRpcTransport transport,
  Map<String, dynamic> customParams,
) {
  print('customParams: $customParams');
  print('СЕРВЕР: Запущен эхо-сервер с новым API');
  final logger = RpcLogger(
    "Isolate",
    colors: RpcLoggerColors.singleColor(AnsiColor.brightGreen),
  );

  // Создаем сериализатор
  final serializer = SimpleStringSerializer();

  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Создаем двунаправленный стрим-сервер
  final server = BidirectionalStreamResponder<String, String>(
    transport: transport,
    serviceName: 'EchoService',
    methodName: 'Echo',
    requestSerializer: serializer,
    responseSerializer: serializer,
    logger: logger,
  );

  // Настраиваем префикс для ответов
  const messagePrefix = '[ECHO]: ';

  // Слушаем входящие запросы
  server.requests.listen((request) {
    final requestStr = request.toString();
    logger.debug('СЕРВЕР: Получен запрос: "$requestStr"');

    // Обработка запроса и отправка эхо-ответа
    final response = '$messagePrefix$requestStr';
    logger.debug('СЕРВЕР: Отправляем ответ: "$response"');
    server.send(response);
  });

  logger.debug('СЕРВЕР: Эхо-сервер запущен и готов к обработке запросов');
}
