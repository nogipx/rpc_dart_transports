import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования двунаправленных и клиентских стримов
void main() async {
  print('=== Пример использования различных типов стримингов ===\n');

  // Инициализация транспорта и эндпоинтов
  final endpoints = setupEndpoints();
  final serverEndpoint = endpoints.server;
  final clientEndpoint = endpoints.client;

  // Регистрация обработчиков
  registerServerHandlers(serverEndpoint);

  // Демонстрация клиентского стриминга
  await demonstrateClientStreaming(clientEndpoint);

  // Демонстрация двунаправленного стрима
  await demonstrateBidirectionalStream(clientEndpoint);

  // Закрытие соединений
  await cleanupResources(clientEndpoint, serverEndpoint);

  print('\n--- Пример завершен ---');
}

/// Настройка и инициализация транспорта и эндпоинтов
({RpcEndpoint server, RpcEndpoint client}) setupEndpoints() {
  // Создаем транспорт в памяти для локального теста
  final transport1 = MemoryTransport("server");
  final transport2 = MemoryTransport("client");

  // Соединяем транспорты
  transport1.connect(transport2);
  transport2.connect(transport1);

  // Создаем сервер и клиент с метками для отладки
  final serverEndpoint = RpcEndpoint(
    transport: transport1,
    serializer: JsonSerializer(),
    debugLabel: "server",
  );
  final clientEndpoint = RpcEndpoint(
    transport: transport2,
    serializer: JsonSerializer(),
    debugLabel: "client",
  );

  final serviceContract = SimpleRpcServiceContract(serviceName);

  // Добавляем middleware для логирования на обоих endpoints
  serverEndpoint.addMiddleware(DebugMiddleware(id: "server"));
  clientEndpoint.addMiddleware(DebugMiddleware(id: "client"));

  // Регистрируем контракт на обоих эндпоинтах
  serverEndpoint.registerServiceContract(serviceContract);
  clientEndpoint.registerServiceContract(serviceContract);

  return (server: serverEndpoint, client: clientEndpoint);
}

/// Константы для имен сервисов и методов
const serviceName = 'EchoService';
const methodName = 'echo';
const clientStreamMethodName = 'streamData';

/// Регистрация обработчиков на сервере
void registerServerHandlers(RpcEndpoint serverEndpoint) {
  // Регистрируем обработчик двунаправленного стрима
  serverEndpoint
      .bidirectional(serviceName, methodName)
      .register<StringMessage, StringMessage>(
        handler: (incomingStream, messageId) {
          // Просто отправляем назад сообщения с префиксом
          return incomingStream.map((data) {
            return StringMessage(text: 'Эхо: ${data.text}');
          });
        },
        requestParser: StringMessage.fromJson,
        responseParser: StringMessage.fromJson,
      );

  // Регистрируем обработчик клиентского стриминга
  serverEndpoint
      .clientStreaming(serviceName, clientStreamMethodName)
      .register<StringMessage, StringMessage>(
        handler: (requests) async {
          print('\nСервер: начал обработку потока клиентских сообщений\n');
          StringMessage? lastMessage;
          int count = 0;

          try {
            await for (final message in requests) {
              count++;
              print('Сервер: получил сообщение #$count: ${message.text}');
              lastMessage = message;

              // Имитация обработки данных
              await Future.delayed(Duration(milliseconds: 300));
            }

            print(
                '\nСервер: поток клиентских сообщений завершен, всего получено: $count\n');

            // Подготавливаем итоговый ответ на основе последнего полученного сообщения
            final response = lastMessage != null
                ? StringMessage(
                    text:
                        'Обработано $count сообщений. Последнее: ${lastMessage.text}')
                : StringMessage(text: 'Не получено ни одного сообщения');

            return response;
          } catch (e) {
            print('\nСервер: ошибка при обработке потока: $e\n');
            return StringMessage(text: 'Ошибка: $e');
          }
        },
        requestParser: StringMessage.fromJson,
        responseParser: StringMessage.fromJson,
      );

  // Регистрируем обработчик для простого клиентского стриминга
  serverEndpoint
      .clientStreaming(serviceName, 'test')
      .register<StringMessage, StringMessage>(
        handler: (requests) async {
          int tickCount = 0;

          await for (final tick in requests) {
            tickCount++;
            print('Сервер получил тик: ${tick.text}');
          }

          return StringMessage(text: 'Сервер получил $tickCount тиков');
        },
        requestParser: StringMessage.fromJson,
        responseParser: StringMessage.fromJson,
      );
}

/// Демонстрация клиентского стриминга
Future<void> demonstrateClientStreaming(RpcEndpoint clientEndpoint) async {
  print('\n=== Демонстрация клиентского стриминга ===\n');
  print('Клиент: открытие потока для отправки данных на сервер...');

  // Открываем клиентский поток
  final clientStream = clientEndpoint
      .clientStreaming(serviceName, clientStreamMethodName)
      .openClientStream<StringMessage, StringMessage>(
        responseParser: StringMessage.fromJson,
        requestParser: StringMessage.fromJson,
      );

  // Отслеживаем ответ сервера
  clientStream.response.then(
    (response) =>
        print('\nКлиент: получен финальный ответ: ${response.text}\n'),
    onError: (e) => print('\nКлиент: ошибка при получении ответа: $e\n'),
  );

  // Определяем источник данных для отправки
  final dataSource = Stream<StringMessage>.periodic(Duration(seconds: 1),
      (index) => StringMessage(text: 'Пакет данных #$index')).take(5);

  print('Клиент: начинаем отправку данных...');

  // Отправляем данные в поток
  await dataSource.forEach((message) {
    print('Клиент: отправка ${message.text}');
    clientStream.controller.add(message);
  });

  // Закрываем контроллер после отправки всех данных
  print('Клиент: завершаем отправку данных');
  clientStream.controller.close();

  // Ждем получения результата
  await clientStream.response;

  print('\n=== Демонстрация клиентского стриминга завершена ===\n');

  // Временная пауза перед запуском следующего примера
  await Future.delayed(Duration(seconds: 1));
}

/// Демонстрация двунаправленного стрима
Future<void> demonstrateBidirectionalStream(RpcEndpoint clientEndpoint) async {
  print('\n=== Демонстрация двунаправленного стрима ===\n');

  // Создаем двунаправленный канал на клиенте
  final channel = clientEndpoint
      .bidirectional(serviceName, methodName)
      .createChannel<StringMessage, StringMessage>(
        requestParser: StringMessage.fromJson,
        responseParser: StringMessage.fromJson,
      );

  // Подписываемся на входящие сообщения
  final subscription = channel.incoming.listen(
    (message) => print('\nКлиент получил: $message\n'),
    onError: (e) => print('\nОшибка: $e\n'),
    onDone: () => print('\nСоединение закрыто\n'),
  );

  channel.send(StringMessage(text: 'Привет, сервер!'));
  await Future.delayed(Duration(milliseconds: 300));

  channel.send(StringMessage(text: 'Это тест двунаправленного стрима'));
  await Future.delayed(Duration(milliseconds: 300));

  channel.send(StringMessage(text: 'Отправляем структурированные данные'));
  await Future.delayed(Duration(milliseconds: 300));

  // Ждем немного для получения ответов
  await Future.delayed(Duration(seconds: 1));

  // Сначала закрываем канал
  await channel.close();
  // Затем отменяем подписку
  await subscription.cancel();

  print('\n=== Демонстрация двунаправленного стрима завершена ===\n');
}

/// Закрытие ресурсов
Future<void> cleanupResources(
    RpcEndpoint clientEndpoint, RpcEndpoint serverEndpoint) async {
  print('\nЗакрытие соединений...');

  // Важно сначала закрыть клиент, затем сервер
  await clientEndpoint.close();
  await Future.delayed(Duration(milliseconds: 100));
  await serverEndpoint.close();
}

/// Сообщение с текстовым полем
class StringMessage implements IRpcSerializableMessage {
  final String text;

  StringMessage({required this.text});

  @override
  Map<String, dynamic> toJson() {
    return {'text': text};
  }

  @override
  factory StringMessage.fromJson(Map<String, dynamic> json) {
    return StringMessage(text: json['text']);
  }

  @override
  String toString() => 'StringMessage(text: $text)';
}
