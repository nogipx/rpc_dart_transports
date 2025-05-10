import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования двунаправленных и клиентских стримов
/// с примитивными типами данных
void main() async {
  print(
      '=== Пример использования различных типов стримингов с примитивами ===\n');

  // Инициализация транспорта и эндпоинтов
  final endpoints = setupEndpoints();
  final serverEndpoint = endpoints.server;
  final clientEndpoint = endpoints.client;

  // Регистрация обработчиков
  registerServerHandlers(serverEndpoint);

  // Регистрация обработчиков на клиенте
  registerClientHandlers(clientEndpoint);

  // Демонстрация двунаправленного стрима с примитивами
  await demonstrateBidirectionalStream(clientEndpoint);

  // Демонстрация с комплексными структурами данных
  await demonstrateComplexDataStructures(clientEndpoint);

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

  // Создаем и регистрируем сервисные контракты на обоих эндпоинтах
  final serviceContract = SimpleRpcServiceContract(serviceName);
  serverEndpoint.registerServiceContract(serviceContract);
  clientEndpoint.registerServiceContract(serviceContract);

  // Добавляем middleware для логирования на обоих endpoints
  serverEndpoint.addMiddleware(DebugMiddleware(id: "server"));
  clientEndpoint.addMiddleware(DebugMiddleware(id: "client"));

  return (server: serverEndpoint, client: clientEndpoint);
}

/// Константы для имен сервисов и методов
const serviceName = 'EchoService';
const echoMethodName = 'echo';
const clientStreamMethodName = 'streamData';
const complexDataMethodName = 'complexData';

/// Регистрация обработчиков на сервере
void registerServerHandlers(RpcEndpoint serverEndpoint) {
  // Регистрируем обработчик двунаправленного стрима для RpcString
  serverEndpoint
      .bidirectional(serviceName, echoMethodName)
      .register<RpcString, RpcString>(
        handler: (incomingStream, messageId) {
          // Просто отправляем назад сообщения с префиксом
          return incomingStream.map((data) {
            print('Сервер получил: ${data.value}');
            return RpcString('Эхо: ${data.value}');
          });
        },
        requestParser: RpcString.fromJson,
        responseParser: RpcString.fromJson,
      );

  // Регистрируем обработчик клиентского стриминга для RpcInt
  serverEndpoint
      .clientStreaming(serviceName, clientStreamMethodName)
      .register<RpcInt, RpcMap<String, IRpcSerializableMessage>>(
        handler: (requests) async {
          print('\nСервер: начал обработку потока числовых данных\n');

          int sum = 0;
          int count = 0;
          int max = 0;

          try {
            await for (final number in requests) {
              count++;
              sum += number.value;
              if (number.value > max) max = number.value;

              print('Сервер: получил число #$count: ${number.value}');

              // Имитация обработки данных
              await Future.delayed(Duration(milliseconds: 200));
            }

            print('\nСервер: поток чисел завершен, всего получено: $count\n');

            // Формируем сложный ответ со статистикой
            final response = RpcMap<String, IRpcSerializableMessage>({
              'count': RpcInt(count),
              'sum': RpcInt(sum),
              'average': RpcDouble(count > 0 ? sum / count : 0),
              'max': RpcInt(max),
              'status': RpcString('Успешно обработано $count чисел')
            });

            return response;
          } catch (e) {
            print('\nСервер: ошибка при обработке потока: $e\n');
            return RpcMap<String, IRpcSerializableMessage>(
                {'error': RpcString('Ошибка: $e')});
          }
        },
        requestParser: RpcInt.fromJson,
        responseParser: (json) {
          final map = json;
          final result = <String, IRpcSerializableMessage>{};

          map['value'].forEach((key, value) {
            if (value is Map<String, dynamic>) {
              if (value.containsKey('value')) {
                final val = value['value'];
                if (val is int) {
                  result[key] = RpcInt.fromJson(value);
                } else if (val is double) {
                  result[key] = RpcDouble.fromJson(value);
                } else if (val is String) {
                  result[key] = RpcString.fromJson(value);
                } else if (val is bool) {
                  result[key] = RpcBool.fromJson(value);
                } else if (val == null) {
                  result[key] = const RpcNull();
                }
              }
            }
          });

          return RpcMap<String, IRpcSerializableMessage>(result);
        },
      );

  // Регистрируем обработчик для комплексных структур данных
  serverEndpoint.bidirectional(serviceName, complexDataMethodName).register<
          RpcMap<String, IRpcSerializableMessage>,
          RpcMap<String, IRpcSerializableMessage>>(
        handler: (requests, messageId) {
          print('\nСервер: обрабатываем комплексные структуры данных\n');

          return requests.map((data) {
            // Обработка входящих данных - просто возвращаем в формате "processed_X"
            final result = <String, IRpcSerializableMessage>{};

            data.forEach((key, value) {
              final newKey = 'processed_$key';

              if (value is RpcString) {
                result[newKey] = RpcString('Обработано: ${value.value}');
              } else if (value is RpcInt) {
                result[newKey] = RpcInt(value.value * 2); // умножаем числа на 2
              } else if (value is RpcList) {
                result[newKey] = value; // для списков ничего не делаем
              } else if (value is RpcMap) {
                result[newKey] = value; // для вложенных карт ничего не делаем
              } else {
                result[newKey] = value;
              }
            });

            // Добавляем метку времени обработки
            result['timestamp'] = RpcString(DateTime.now().toIso8601String());

            return RpcMap<String, IRpcSerializableMessage>(result);
          });
        },
        // Используем новый умный парсер для автоматического определения типов
        requestParser: RpcMap.fromJson,
        // Аналогично для ответа
        responseParser: RpcMap.fromJson,
      );
}

/// Регистрация обработчиков на клиенте
void registerClientHandlers(RpcEndpoint clientEndpoint) {
  // Регистрируем обработчик двунаправленного стрима для RpcString на клиенте
  clientEndpoint
      .bidirectional(serviceName, echoMethodName)
      .register<RpcString, RpcString>(
        handler: (incomingStream, messageId) {
          // Клиент обычно не обрабатывает вызовы, но мы регистрируем обработчики
          // для корректного функционирования контрактов
          return incomingStream;
        },
        requestParser: RpcString.fromJson,
        responseParser: RpcString.fromJson,
      );

  // Регистрируем обработчик для комплексных структур данных на клиенте
  clientEndpoint.bidirectional(serviceName, complexDataMethodName).register<
          RpcMap<String, IRpcSerializableMessage>,
          RpcMap<String, IRpcSerializableMessage>>(
        handler: (requests, messageId) {
          // Клиент обычно не обрабатывает вызовы, но мы регистрируем обработчики
          // для корректного функционирования контрактов
          return requests;
        },
        requestParser: RpcMap.fromJson,
        responseParser: RpcMap.fromJson,
      );
}

/// Демонстрация двунаправленного стрима с RpcString
Future<void> demonstrateBidirectionalStream(RpcEndpoint clientEndpoint) async {
  print('\n=== Демонстрация двунаправленного стрима с RpcString ===\n');

  // Создаем двунаправленный канал на клиенте
  final channel = clientEndpoint
      .bidirectional(serviceName, echoMethodName)
      .createChannel<RpcString, RpcString>(
        requestParser: RpcString.fromJson,
        responseParser: RpcString.fromJson,
      );

  // Подписываемся на входящие сообщения
  final subscription = channel.incoming.listen(
    (message) => print('\nКлиент получил: ${message.value}\n'),
    onError: (e) => print('\nОшибка: $e\n'),
    onDone: () => print('\nСоединение закрыто\n'),
  );

  channel.send(RpcString('Привет, сервер!'));
  await Future.delayed(Duration(milliseconds: 300));

  channel.send(RpcString('Это тест двунаправленного стрима'));
  await Future.delayed(Duration(milliseconds: 300));

  channel.send(RpcString('Используем RpcString вместо своего класса'));
  await Future.delayed(Duration(milliseconds: 300));

  // Ждем немного для получения ответов
  await Future.delayed(Duration(seconds: 1));

  // Сначала закрываем канал
  await channel.close();
  // Затем отменяем подписку
  await subscription.cancel();

  print('\n=== Демонстрация двунаправленного стрима завершена ===\n');
}

/// Демонстрация работы с комплексными структурами данных
Future<void> demonstrateComplexDataStructures(
    RpcEndpoint clientEndpoint) async {
  print('\n=== Демонстрация сложных структур данных ===\n');

  // Создаем двунаправленный канал для сложных структур
  final channel = clientEndpoint
      .bidirectional(serviceName, complexDataMethodName)
      .createChannel<RpcMap<String, IRpcSerializableMessage>,
          RpcMap<String, IRpcSerializableMessage>>(
        // Используем умный парсер для обработки сложных структур
        requestParser: RpcMap.fromJson,
        // Аналогично для ответа
        responseParser: RpcMap.fromJson,
      );

  // Подписываемся на входящие сообщения
  final subscription = channel.incoming.listen(
    (response) {
      print('\nКлиент получил ответ от сервера:');
      response.forEach((key, value) {
        if (value is RpcString) {
          print('  $key: ${value.value}');
        } else if (value is RpcInt) {
          print('  $key: ${value.value}');
        } else if (value is RpcList) {
          print('  $key: список с ${value.length} элементами');
        } else {
          print('  $key: ${value.runtimeType}');
        }
      });
    },
    onError: (e) => print('\nОшибка: $e\n'),
    onDone: () => print('\nСоединение с комплексными данными закрыто\n'),
  );

  // Отправляем несколько сложных структур данных

  // 1. Простая структура с разными типами
  final simpleData = RpcMap<String, IRpcSerializableMessage>({
    'name': RpcString('Тестовый пользователь'),
    'age': RpcInt(30),
    'tags': RpcList<RpcString>(
        [RpcString('dart'), RpcString('rpc'), RpcString('примитивы')]),
  });

  print('\nКлиент: отправка простой структуры данных');
  channel.send(simpleData);
  await Future.delayed(Duration(milliseconds: 500));

  // 2. Более сложная структура с вложенностью
  final complexData = RpcMap<String, IRpcSerializableMessage>({
    'user': RpcMap<String, IRpcSerializableMessage>({
      'id': RpcInt(123),
      'name': RpcString('Администратор'),
      'roles': RpcList<RpcString>([RpcString('admin'), RpcString('manager')]),
    }),
    'settings': RpcMap<String, IRpcSerializableMessage>({
      'theme': RpcString('dark'),
      'notifications': RpcBool(true),
    }),
    'status': RpcString('активен'),
  });

  print('\nКлиент: отправка структуры с вложенными данными');
  channel.send(complexData);
  await Future.delayed(Duration(milliseconds: 1000));

  // Закрываем канал
  await channel.close();
  await subscription.cancel();

  print('\n=== Демонстрация сложных структур данных завершена ===\n');
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

/// Контракт сервиса для примера
final class SimpleRpcServiceContract extends RpcServiceContract {
  @override
  final String serviceName;

  SimpleRpcServiceContract(this.serviceName);

  @override
  void setup() {
    // Методы регистрируются динамически
  }
}
