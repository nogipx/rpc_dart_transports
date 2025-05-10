import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

/// Имена сервиса и методов
const serviceName = 'DemoService';
const simpleBidiMethod = 'simpleBidi';
const complexBidiMethod = 'complexBidi';

/// Пример использования двунаправленного (bidirectional) стрима
/// Демонстрирует обмен данными в обе стороны между клиентом и сервером
void main() async {
  print('=== Пример двунаправленной коммуникации ===\n');

  // Создаем и настраиваем эндпоинты
  final endpoints = setupEndpoints();
  final serverEndpoint = endpoints.server;
  final clientEndpoint = endpoints.client;

  // Регистрируем обработчики RPC
  registerHandlers(serverEndpoint, clientEndpoint);

  // Демонстрация простого двунаправленного стрима
  await demonstrateSimpleBidirectional(clientEndpoint);

  // Демонстрация двунаправленного стрима с комплексными данными
  await demonstrateComplexBidirectional(clientEndpoint);

  // Закрываем соединения
  await cleanupResources(clientEndpoint, serverEndpoint);

  print('\n--- Пример завершен ---');
}

/// Настраиваем транспорт и эндпоинты для примера
({RpcEndpoint server, RpcEndpoint client}) setupEndpoints() {
  // Создаем транспорт в памяти для локального тестирования
  final serverTransport = MemoryTransport("server");
  final clientTransport = MemoryTransport("client");

  // Соединяем транспорты между собой
  serverTransport.connect(clientTransport);
  clientTransport.connect(serverTransport);

  // Создаем эндпоинты с метками для отладки
  final serverEndpoint = RpcEndpoint(
    transport: serverTransport,
    serializer: JsonSerializer(),
    debugLabel: "server",
  );
  final clientEndpoint = RpcEndpoint(
    transport: clientTransport,
    serializer: JsonSerializer(),
    debugLabel: "client",
  );

  // Регистрируем контракт сервиса на обоих эндпоинтах
  serverEndpoint.registerServiceContract(SimpleRpcServiceContract(serviceName));
  clientEndpoint.registerServiceContract(SimpleRpcServiceContract(serviceName));

  // Добавляем middleware для отладки
  serverEndpoint.addMiddleware(DebugMiddleware(id: "server"));
  clientEndpoint.addMiddleware(DebugMiddleware(id: "client"));

  return (server: serverEndpoint, client: clientEndpoint);
}

/// Регистрируем обработчики RPC на сервере и клиенте
void registerHandlers(RpcEndpoint serverEndpoint, RpcEndpoint clientEndpoint) {
  // Регистрация обработчиков для простого двунаправленного стрима
  serverEndpoint
      .bidirectional(serviceName, simpleBidiMethod)
      .register<RpcString, RpcString>(
        handler: (incomingStream, messageId) {
          // Для каждого входящего сообщения отправляем ответ
          return incomingStream.map((data) {
            print('Сервер получил: ${data.value}');
            return RpcString('Ответ: ${data.value}');
          });
        },
        requestParser: RpcString.fromJson,
        responseParser: RpcString.fromJson,
      );
  clientEndpoint
      .bidirectional(serviceName, simpleBidiMethod)
      .register<RpcString, RpcString>(
        handler: (incomingStream, messageId) => incomingStream,
        requestParser: RpcString.fromJson,
        responseParser: RpcString.fromJson,
      );

  // Регистрация обработчиков для комплексных данных
  serverEndpoint
      .bidirectional(serviceName, complexBidiMethod)
      .register<RpcMap, RpcMap>(
        handler: (requests, messageId) {
          return requests.map((data) {
            final result = <String, IRpcSerializableMessage>{};

            // Обрабатываем каждое поле входящих данных
            data.forEach((key, value) {
              if (value is RpcString) {
                result[key] = RpcString('${value.value} (обработано)');
              } else if (value is RpcInt) {
                result[key] = RpcInt(value.value * 2);
              } else if (value is RpcBool) {
                result[key] = RpcBool(!value.value);
              } else {
                result[key] = value;
              }
            });

            // Добавляем таймстамп обработки
            result['timestamp'] = RpcString(DateTime.now().toIso8601String());

            return RpcMap(result);
          });
        },
        requestParser: RpcMap.fromJson,
        responseParser: RpcMap.fromJson,
      );
  clientEndpoint
      .bidirectional(serviceName, complexBidiMethod)
      .register<RpcMap, RpcMap>(
        handler: (requests, messageId) => requests,
        requestParser: RpcMap.fromJson,
        responseParser: RpcMap.fromJson,
      );
}

/// Демонстрация простого двунаправленного стрима со строками
Future<void> demonstrateSimpleBidirectional(RpcEndpoint clientEndpoint) async {
  print('\n=== Демонстрация простого двунаправленного стрима ===\n');

  // Создаем двунаправленный канал на клиенте
  final channel = clientEndpoint
      .bidirectional(serviceName, simpleBidiMethod)
      .createChannel<RpcString, RpcString>(
        responseParser: RpcString.fromJson,
      );

  // Подписываемся на входящие сообщения
  final subscription = channel.incoming.listen(
    (message) => print('Клиент получил: ${message.value}'),
    onError: (e) => print('Ошибка: $e'),
    onDone: () => print('Стрим закрыт'),
  );

  // Отправляем несколько сообщений
  print('Клиент отправляет сообщения...');

  channel.send(RpcString('Сообщение 1'));
  await Future.delayed(Duration(milliseconds: 300));

  channel.send(RpcString('Сообщение 2'));
  await Future.delayed(Duration(milliseconds: 300));

  channel.send(RpcString('Сообщение 3'));
  await Future.delayed(Duration(milliseconds: 500));

  // Закрываем канал и подписку
  await channel.close();
  await subscription.cancel();

  print('\n=== Простой двунаправленный стрим завершен ===\n');
}

/// Демонстрация двунаправленного стрима с комплексными данными
Future<void> demonstrateComplexBidirectional(RpcEndpoint clientEndpoint) async {
  print(
      '\n=== Демонстрация двунаправленного стрима с комплексными данными ===\n');

  // Создаем двунаправленный канал для сложных данных
  final channel = clientEndpoint
      .bidirectional(serviceName, complexBidiMethod)
      .createChannel<RpcMap, RpcMap>(
        responseParser: RpcMap.fromJson,
      );

  // Подписываемся на входящие сообщения
  final subscription = channel.incoming.listen(
    (response) {
      print('\nКлиент получил ответ:');
      response.forEach((key, value) {
        if (value is RpcString) {
          print('  $key: ${value.value}');
        } else if (value is RpcInt) {
          print('  $key: ${value.value}');
        } else if (value is RpcBool) {
          print('  $key: ${value.value}');
        } else {
          print('  $key: ${value.runtimeType}');
        }
      });
    },
    onError: (e) => print('Ошибка: $e'),
    onDone: () => print('Стрим закрыт'),
  );

  // Отправляем простую структуру данных
  final simpleData = RpcMap({
    'text': RpcString('Тестовая строка'),
    'number': RpcInt(42),
    'flag': RpcBool(true),
  });

  print('\nКлиент: отправка простых данных');
  channel.send(simpleData);
  await Future.delayed(Duration(milliseconds: 500));

  // Отправляем структуру с вложенными данными
  final nestedData = RpcMap({
    'config': RpcMap({
      'enabled': RpcBool(true),
      'timeout': RpcInt(1000),
    }),
    'items': RpcList<RpcString>([
      RpcString('элемент1'),
      RpcString('элемент2'),
      RpcString('элемент3'),
    ]),
  });

  print('\nКлиент: отправка данных с вложенной структурой');
  channel.send(nestedData);
  await Future.delayed(Duration(milliseconds: 500));

  // Закрываем канал
  await channel.close();
  await subscription.cancel();

  print('\n=== Двунаправленный стрим с комплексными данными завершен ===\n');
}

/// Закрываем все ресурсы
Future<void> cleanupResources(
    RpcEndpoint clientEndpoint, RpcEndpoint serverEndpoint) async {
  print('\nЗакрытие соединений...');
  await clientEndpoint.close();
  await Future.delayed(Duration(milliseconds: 100));
  await serverEndpoint.close();
}
