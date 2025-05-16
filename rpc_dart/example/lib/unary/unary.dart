import 'package:rpc_dart/rpc_dart.dart';
import '../utils/logger.dart';

import 'unary_contract.dart';
import 'unary_models.dart';

/// Логгер для примера
final logger = ExampleLogger('UnaryExample');

/// Пример унарных вызовов RPC (один запрос -> один ответ)
/// Демонстрирует выполнение базовых математических операций с числами
Future<void> main({bool debug = false}) async {
  logger.section('Пример унарных вызовов RPC');

  // Создаем транспорты в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  logger.info('Транспорты соединены');

  // Создаем эндпоинты
  final client = RpcEndpoint(transport: clientTransport, debugLabel: 'client');
  final server = RpcEndpoint(transport: serverTransport, debugLabel: 'server');
  logger.info('Эндпоинты созданы');

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
    logger.info('Контракты зарегистрированы');

    // Демонстрация математических операций
    await demonstrateBasicOperations(clientContract);
  } catch (e, stack) {
    logger.error('Произошла ошибка', e, stack);
  } finally {
    // Закрываем эндпоинты
    await client.close();
    await server.close();
    logger.info('Эндпоинты закрыты');
  }

  logger.section('Пример завершен');
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
  logger.info('Результат математических операций с $value1 и $value2:');
  logger.bulletList([
    'Сумма: ${result.sum}',
    'Разность: ${result.difference}',
    'Произведение: ${result.product}',
    'Частное: ${result.quotient}',
  ]);
}
