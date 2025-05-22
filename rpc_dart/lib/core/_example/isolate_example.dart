part of '../_index.dart';

/// Пример использования транспорта через изоляты.
///
/// Демонстрирует, как настроить клиент и сервер в разных изолятах
/// и организовать взаимодействие между ними с помощью IsolateTransport.
class IsolateRpcExample {
  /// Запускает демонстрацию работы RPC через изоляты.
  ///
  /// Создает сервер в отдельном изоляте и взаимодействует с ним через
  /// двунаправленный стрим, используя транспорт на основе изолятов.
  static Future<void> run() async {
    // Создаем порт для получения транспорта от серверного изолята
    final pair = IsolateTransportPair.create();

    // Запускаем серверный изолят
    final serverIsolate = await Isolate.spawn(
      _startServerIsolate,
      pair.$1,
    );

    // Создаем клиентский транспорт
    final clientTransport = pair.$2;

    // Создаем сериализаторы для запросов и ответов
    final stringSerializer = StringSerializer();

    // Создаем двунаправленный клиент
    final client = BidirectionalStreamClient<String, String>(
      transport: clientTransport,
      requestSerializer: stringSerializer,
      responseSerializer: stringSerializer,
    );

    // Подписываемся на ответы от сервера
    final subscription = client.responses.listen((message) {
      if (!message.isMetadataOnly) {
        print('Клиент получил: ${message.payload}');
      }
    });

    // Отправляем несколько запросов
    client.send('Привет, сервер!');
    await Future.delayed(Duration(milliseconds: 100));

    client.send('Как дела?');
    await Future.delayed(Duration(milliseconds: 100));

    client.send('Завершаю работу');
    await Future.delayed(Duration(milliseconds: 100));

    // Завершаем отправку и закрываем клиент
    client.finishSending();
    await Future.delayed(Duration(milliseconds: 500));

    await subscription.cancel();
    await client.close();
    serverIsolate.kill();

    // Завершаем работу
    print('Клиент завершил работу');
  }
}

/// Функция для запуска серверного изолята.
///
/// [sendPort] Порт для отправки транспорта клиентскому изоляту
@pragma('vm:entry-point')
void _startServerIsolate(IsolateTransport serverTransport) async {
  // Создаем сериализаторы
  final stringSerializer = StringSerializer();

  // Создаем серверный обработчик стрима
  final server = BidirectionalStreamServer<String, String>(
    transport: serverTransport,
    requestSerializer: stringSerializer,
    responseSerializer: stringSerializer,
  );

  // Создаем эхо-обработчик, который отвечает на каждый запрос
  server.requests.listen((request) {
    print('Сервер получил: $request');

    // Отвечаем на запрос
    if (request == 'Привет, сервер!') {
      server.send('Привет, клиент!');
    } else if (request == 'Как дела?') {
      server.send('Отлично! У меня много памяти и CPU времени!');
    } else if (request == 'Завершаю работу') {
      server.send('До свидания! Буду ждать следующего подключения.');

      // Завершаем отправку ответов
      server.finishSending();
    }
  });

  // Ждем завершения работы
  await Future.delayed(Duration(seconds: 60));
}

/// Простой сериализатор строк.
///
/// Преобразует строки в UTF-8 байты и обратно.
class StringSerializer implements IRpcSerializer<String> {
  @override
  Uint8List serialize(String message) {
    return Uint8List.fromList(message.codeUnits);
  }

  @override
  String deserialize(Uint8List bytes) {
    return String.fromCharCodes(bytes);
  }
}

/// Пример запуска RPC через изоляты.
///
/// Запускает пример и выводит результат в консоль.
Future<void> runIsolateExample() async {
  print('Запуск примера RPC через изоляты...');
  await IsolateRpcExample.run();
  print('Пример завершен.');
}
