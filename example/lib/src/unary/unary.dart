import 'package:rpc_dart/rpc_dart.dart';

import 'unary_contract.dart';
import 'unary_models.dart';

/// Пример использования унарных вызовов (одиночный запрос -> одиночный ответ)
/// Самый базовый тип RPC взаимодействия
Future<void> main() async {
  print('=== Пример унарных вызовов RPC ===\n');

  // Создаем транспорты в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты между собой
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  print('Транспорты соединены');

  // Создаем эндпоинты с метками для отладки
  final client = RpcEndpoint(
    transport: clientTransport,
    serializer: JsonSerializer(),
    debugLabel: 'client',
  );
  final server = RpcEndpoint(
    transport: serverTransport,
    serializer: JsonSerializer(),
    debugLabel: 'server',
  );
  print('Эндпоинты созданы');

  // Добавляем middleware для логирования
  server.addMiddleware(DebugMiddleware(id: 'server'));
  client.addMiddleware(DebugMiddleware(id: 'client'));

  try {
    // Создаем и регистрируем серверные и клиентские контракты
    final serverBasicService = ServerBasicServiceContract();
    final serverTypedService = ServerTypedServiceContract();

    final clientBasicService = ClientBasicServiceContract(client);
    final clientTypedService = ClientTypedServiceContract(client);

    // Регистрируем контракты на сервере и клиенте
    server.registerServiceContract(serverBasicService);
    server.registerServiceContract(serverTypedService);

    client.registerServiceContract(clientBasicService);
    client.registerServiceContract(clientTypedService);

    print('Контракты зарегистрированы');

    // Демонстрация унарных вызовов с разными типами данных
    await demonstrateBasicUnary(clientBasicService);

    // Демонстрация типизированных унарных вызовов с пользовательскими классами
    await demonstrateTypedUnary(clientTypedService);

    // Демонстрация обработки ошибок
    await demonstrateErrorHandling(clientBasicService);
  } catch (e) {
    print('Произошла ошибка: $e');
  } finally {
    // Закрываем эндпоинты
    await client.close();
    await server.close();
    print('\nЭндпоинты закрыты');
  }

  print('\n=== Пример завершен ===');
}

/// Демонстрация базовых унарных вызовов с примитивными типами
Future<void> demonstrateBasicUnary(ClientBasicServiceContract client) async {
  print('\n--- Базовые унарные вызовы ---');

  // Вызов метода compute с числовыми параметрами
  final computeResult = await client.compute(ComputeRequest(value1: 10, value2: 5));
  print('Для значений 10 и 5:');
  print('  Сумма: ${computeResult.sum}');
  print('  Разность: ${computeResult.difference}');
  print('  Произведение: ${computeResult.product}');
  print('  Частное: ${computeResult.quotient}');

  // Вызов метода transformText для работы со строками
  final transformResult = await client.transformText(
    TextTransformRequest(text: 'Hello RPC World', operation: 'uppercase'),
  );
  print('\nПреобразование текста в верхний регистр:');
  print('  Результат: ${transformResult.result}');
  print('  Длина: ${transformResult.length} символов');
}

/// Демонстрация типизированных унарных вызовов с пользовательскими классами
Future<void> demonstrateTypedUnary(ClientTypedServiceContract client) async {
  print('\n--- Типизированные унарные вызовы ---');

  // Создаем типизированный запрос
  final request = DataRequest(value: 42, label: 'test_data');

  // Вызываем метод из контракта
  final response = await client.processData(request);

  print('Отправлено значение: ${request.value}');
  print('Получено обработанное значение: ${response.processedValue}');
  print('Статус успеха: ${response.isSuccess}');
  print('Временная метка: ${response.timestamp}');
}

/// Демонстрация обработки ошибок
Future<void> demonstrateErrorHandling(ClientBasicServiceContract client) async {
  print('\n--- Обработка ошибок ---');

  // Вызываем метод с ошибкой (деление на ноль)
  try {
    await client.divide(DivideRequest(numerator: 10, denominator: 0));
    print('Этот код не должен выполниться');
  } catch (e) {
    print('Перехвачена ошибка: $e');
  }

  // Успешное деление
  final divideResult = await client.divide(DivideRequest(numerator: 10, denominator: 2));
  print('10 / 2 = ${divideResult.result}');
}
