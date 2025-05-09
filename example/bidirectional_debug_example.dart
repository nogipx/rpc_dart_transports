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

/// Пример для отладки проблемы с дополнительным запросом
void main() async {
  print('=== Отладка двунаправленного канала ===\n');

  // Создаем отладочный транспорт для видимости всех сообщений
  final transport1 = MemoryTransport("server");
  final transport2 = MemoryTransport("client");

  // Соединяем транспорты
  transport1.connect(transport2);
  transport2.connect(transport1);

  // Создаем сервер и клиент
  final serverEndpoint = RpcEndpoint(transport1, JsonSerializer())
    ..addMiddleware(DebugMiddleware(id: 'server'));
  final clientEndpoint = RpcEndpoint(transport2, JsonSerializer())
    ..addMiddleware(DebugMiddleware(id: 'client'));

  // Имя сервиса и метода
  const serviceName = 'EchoService';
  const methodName = 'echo';

  // Создаем и регистрируем пустой контракт для сервиса EchoService
  final serverContract = EmptyServiceContract(serviceName);
  final clientContract = EmptyServiceContract(serviceName);

  // Важно зарегистрировать контракт на обоих эндпоинтах
  serverEndpoint.registerServiceContract(serverContract);
  clientEndpoint.registerServiceContract(clientContract);

  print('Контракты зарегистрированы');

  // Регистрируем обработчик на сервере
  serverEndpoint
      .bidirectional(serviceName, methodName)
      .register<StringMessage, StringMessage>(
        handler: (incomingStream, messageId) {
          print('Вызван обработчик сервера с ID: $messageId');
          // Просто отправляем назад сообщения с префиксом
          return incomingStream.map((data) {
            return StringMessage(text: 'Эхо: ${data.text}');
          });
        },
        requestParser: StringMessage.fromJson,
        responseParser: StringMessage.fromJson,
      );

  print('Обработчик зарегистрирован');

  // Создаем двунаправленный канал на клиенте
  print('Создаем двунаправленный канал...');
  final channel = clientEndpoint
      .bidirectional(serviceName, methodName)
      .createChannel<StringMessage, StringMessage>(
        requestParser: StringMessage.fromJson,
        responseParser: StringMessage.fromJson,
      );

  print('Двунаправленный канал создан');

  // Ждем немного, чтобы увидеть все сообщения
  await Future.delayed(Duration(seconds: 1));

  // Отправляем тестовое сообщение
  channel.send(StringMessage(text: 'Тестовое сообщение'));

  // Ждем для получения ответа
  await Future.delayed(Duration(seconds: 1));

  // Закрываем ресурсы
  print('\n--- Завершение работы ---');
  await channel.close();
  await clientEndpoint.close();
  await serverEndpoint.close();

  print('\n--- Отладка завершена ---');
}

/// Пустой контракт для регистрации сервиса
class EmptyServiceContract
    implements IRpcServiceContract<RpcSerializableMessage> {
  final String _serviceName;

  EmptyServiceContract(this._serviceName);

  @override
  String get serviceName => _serviceName;

  @override
  dynamic getArgumentParser(
          RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>
              method) =>
      null;

  @override
  dynamic getHandler(
          RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>
              method) =>
      null;

  @override
  List<RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>>
      get methods => [];

  @override
  dynamic getResponseParser(
          RpcMethodContract<RpcSerializableMessage, RpcSerializableMessage>
              method) =>
      null;

  @override
  RpcMethodContract<Request, Response>? findMethodTyped<
          Request extends RpcSerializableMessage,
          Response extends RpcSerializableMessage>(String methodName) =>
      null;
}
