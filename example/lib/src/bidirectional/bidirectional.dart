import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

import 'bidirectional_contract.dart';
import 'bidirectional_models.dart';

/// Имена сервиса и методов
const serviceName = 'DemoService';
const simpleBidiMethod = 'simpleBidi';
const complexBidiMethod = 'complexBidi';

/// Пример использования двунаправленного (bidirectional) стрима
/// Демонстрирует обмен данными в обе стороны между клиентом и сервером
Future<void> main() async {
  print('=== Пример двунаправленной коммуникации ===\n');

  // Создаем и настраиваем эндпоинты
  final endpoints = setupEndpoints();
  final serverEndpoint = endpoints.server;
  final clientEndpoint = endpoints.client;

  // Создаем и регистрируем серверные и клиентские реализации контрактов
  final serverContract = ServerDemoServiceContract();
  final clientContract = ClientDemoServiceContract(clientEndpoint);

  serverEndpoint.registerServiceContract(serverContract);
  clientEndpoint.registerServiceContract(clientContract);

  // Демонстрация простого двунаправленного стрима
  await demonstrateSimpleBidirectional(clientContract);

  // Демонстрация двунаправленного стрима с комплексными данными
  await demonstrateComplexBidirectional(clientContract);

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

  // Добавляем middleware для отладки
  serverEndpoint.addMiddleware(DebugMiddleware(id: "server"));
  clientEndpoint.addMiddleware(DebugMiddleware(id: "client"));

  return (server: serverEndpoint, client: clientEndpoint);
}

/// Демонстрация простого двунаправленного стрима со строками
Future<void> demonstrateSimpleBidirectional(ClientDemoServiceContract demoService) async {
  print('\n=== Демонстрация простого двунаправленного стрима ===\n');

  // Открываем двунаправленный канал
  final channel = await demoService.simpleBidirectional();

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
Future<void> demonstrateComplexBidirectional(ClientDemoServiceContract demoService) async {
  print('\n=== Демонстрация двунаправленного стрима с комплексными данными ===\n');

  // Открываем двунаправленный канал
  final channel = await demoService.complexBidirectional();

  // Подписываемся на входящие сообщения
  final subscription = channel.incoming.listen(
    (response) {
      print('\nКлиент получил ответ:');
      if (response is SimpleMessageData) {
        print('  Тип: SimpleMessageData');
        print('  text: ${response.text}');
        print('  number: ${response.number}');
        print('  flag: ${response.flag}');
        if (response.timestamp != null) {
          print('  timestamp: ${response.timestamp}');
        }
      } else if (response is NestedData) {
        print('  Тип: NestedData');
        print('  config: enabled=${response.config.enabled}, timeout=${response.config.timeout}');
        print('  items: [${response.items.items.join(', ')}]');
        if (response.timestamp != null) {
          print('  timestamp: ${response.timestamp}');
        }
      } else {
        print('  Неизвестный тип: ${response.runtimeType}');
      }
    },
    onError: (e) => print('Ошибка: $e'),
    onDone: () => print('Стрим закрыт'),
  );

  // Отправляем простую структуру данных
  final simpleData = SimpleMessageData(text: 'Тестовая строка', number: 42, flag: true);

  print('\nКлиент: отправка простых данных');
  channel.send(simpleData);
  await Future.delayed(Duration(milliseconds: 500));

  // Отправляем структуру с вложенными данными
  final nestedData = NestedData(
    config: ConfigData(enabled: true, timeout: 1000),
    items: ItemList(['элемент1', 'элемент2', 'элемент3']),
  );

  print('\nКлиент: отправка данных с вложенной структурой');
  channel.send(nestedData);
  await Future.delayed(Duration(milliseconds: 500));

  // Закрываем канал
  await channel.close();
  await subscription.cancel();

  print('\n=== Двунаправленный стрим с комплексными данными завершен ===\n');
}

/// Закрываем все ресурсы
Future<void> cleanupResources(RpcEndpoint clientEndpoint, RpcEndpoint serverEndpoint) async {
  print('\nЗакрытие соединений...');
  await clientEndpoint.close();
  await Future.delayed(Duration(milliseconds: 100));
  await serverEndpoint.close();
}
