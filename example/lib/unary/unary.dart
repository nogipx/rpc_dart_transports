import 'package:rpc_dart/rpc_dart.dart';

import 'unary_contract.dart';
import 'unary_models.dart';

/// Пример унарных вызовов RPC (один запрос -> один ответ)
/// Демонстрирует выполнение базовых математических операций с числами
Future<void> main({bool debug = false}) async {
  print('=== Пример унарных вызовов RPC ===\n');

  // Создаем транспорты в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  print('Транспорты соединены');

  // Создаем эндпоинты
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

  // Добавляем middleware
  if (debug) {
    server.addMiddleware(DebugMiddleware(id: 'server'));
    client.addMiddleware(DebugMiddleware(id: 'client'));
  } else {
    server.addMiddleware(LoggingMiddleware(id: 'server'));
    client.addMiddleware(LoggingMiddleware(id: 'client'));
  }

  try {
    // Создаем и регистрируем контракты
    final serverContract = ServerBasicServiceContract();
    final clientContract = ClientBasicServiceContract(client);

    server.registerServiceContract(serverContract);
    client.registerServiceContract(clientContract);
    print('Контракты зарегистрированы');

    // Демонстрация математических операций
    await demonstrateBasicOperations(clientContract);
  } catch (e, stack) {
    print('Произошла ошибка: $e');
    print('Стек вызовов: $stack');
  } finally {
    // Закрываем эндпоинты
    await client.close();
    await server.close();
    print('\nЭндпоинты закрыты');
  }

  print('\n=== Пример завершен ===');
}

/// Демонстрирует базовые математические операции
Future<void> demonstrateBasicOperations(
  ClientBasicServiceContract service,
) async {
  final value1 = 10;
  final value2 = 5;

  // Создаем запрос
  final request = ComputeRequest(value1: value1, value2: value2);

  // Отправляем запрос
  final result = await service.compute(request);

  // Выводим результат
  print('Результат математических операций с $value1 и $value2:');
  print('  Сумма: ${result.sum}');
  print('  Разность: ${result.difference}');
  print('  Произведение: ${result.product}');
  print('  Частное: ${result.quotient}');
}
