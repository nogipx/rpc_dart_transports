import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:rpc_dart/logger.dart';

import '../_index.dart';

/// Пример использования изолята с пользовательской entrypoint функцией
void main() async {
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
  final client = BidirectionalStreamClient<String, String>(
    transport: result.transport,
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
  final log = customParams['log'] as void Function(String);

  // Создаем сериализатор
  final serializer = SimpleStringSerializer();

  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Создаем двунаправленный стрим-сервер
  final server = BidirectionalStreamServer<String, String>(
    transport: transport,
    requestSerializer: serializer,
    responseSerializer: serializer,
    logger: RpcLogger(
      "Isolate",
      colors: RpcLoggerColors.singleColor(AnsiColor.brightGreen),
    ),
  );

  // Настраиваем префикс для ответов
  const messagePrefix = '[ECHO]: ';

  // Слушаем входящие запросы
  server.requests.listen((request) {
    final requestStr = request.toString();
    log('СЕРВЕР: Получен запрос: "$requestStr"');

    // Обработка запроса и отправка эхо-ответа
    final response = '$messagePrefix$requestStr';
    log('СЕРВЕР: Отправляем ответ: "$response"');
    server.send(response);
  });

  log('СЕРВЕР: Эхо-сервер запущен и готов к обработке запросов');
}

/// Простой сериализатор строк
class SimpleStringSerializer implements IRpcSerializer<String> {
  const SimpleStringSerializer();

  @override
  String deserialize(Uint8List bytes) {
    return utf8.decode(bytes);
  }

  @override
  Uint8List serialize(String message) {
    return Uint8List.fromList(utf8.encode(message));
  }
}
