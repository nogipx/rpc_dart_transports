import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

class StringMessage implements RpcSerializableMessage {
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

/// Пример простого использования двунаправленного канала без контрактной системы
void main() async {
  print('=== Простой пример двунаправленного канала ===\n');

  // Создаем транспорт в памяти для локального теста
  final transport1 = MemoryTransport("server");
  final transport2 = MemoryTransport("client");

  // Соединяем транспорты
  transport1.connect(transport2);
  transport2.connect(transport1);

  // Создаем сервер и клиент
  final serverEndpoint = RpcEndpoint(transport1, JsonSerializer());
  final clientEndpoint = RpcEndpoint(transport2, JsonSerializer());

  // Добавляем middleware для логирования на обоих endpoints
  serverEndpoint.addMiddleware(LoggingMiddleware(id: "server"));
  clientEndpoint.addMiddleware(LoggingMiddleware(id: "client"));

  // Имя сервиса и метода
  const serviceName = 'EchoService';
  const methodName = 'echo';

  // Регистрируем обработчик на сервере
  serverEndpoint.registerBidirectionalHandler<StringMessage, StringMessage>(
    serviceName: serviceName,
    methodName: methodName,
    requestParser: StringMessage.fromJson,
    responseParser: StringMessage.fromJson,
    handler: (incomingStream, messageId) {
      // Просто отправляем назад сообщения с префиксом
      return incomingStream.map((data) {
        return StringMessage(text: 'Эхо: ${data.text}');
      });
    },
  );

  // Создаем двунаправленный канал на клиенте
  final channel =
      clientEndpoint.createBidirectionalChannel<StringMessage, StringMessage>(
    serviceName: serviceName,
    methodName: methodName,
    requestParser: StringMessage.fromJson,
    responseParser: StringMessage.fromJson,
  );

  // Подписываемся на входящие сообщения
  final subscription = channel.listen(
    (message) => print('Клиент получил: $message'),
    onError: (e) => print('Ошибка: $e'),
    onDone: () => print('Соединение закрыто'),
  );

  // Отправляем простые текстовые сообщения
  print('\n--- Отправляем текстовые сообщения ---\n');

  channel.send(StringMessage(text: 'Привет, сервер!'));
  await Future.delayed(Duration(milliseconds: 300));

  channel.send(StringMessage(text: 'Это тест двунаправленного стрима'));
  await Future.delayed(Duration(milliseconds: 300));

  channel.send(StringMessage(text: 'Отправляем структурированные данные'));
  await Future.delayed(Duration(milliseconds: 300));

  // Ждем немного для получения ответов
  await Future.delayed(Duration(seconds: 1));

  // Корректное закрытие ресурсов
  print('\n--- Завершение работы ---');

  // Сначала закрываем канал
  await channel.close();
  // Затем отменяем подписку
  await subscription.cancel();

  // В последнюю очередь закрываем клиента и сервер
  // Важно сначала закрыть клиент, затем сервер
  await clientEndpoint.close();
  await Future.delayed(Duration(milliseconds: 100));
  await serverEndpoint.close();

  print('\n--- Пример завершен ---');
}
