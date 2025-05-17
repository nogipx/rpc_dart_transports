import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

import 'unary_contract.dart';
import 'unary_models.dart';

final _logger = RpcLogger('UnaryExample');

/// Пример унарных вызовов RPC (один запрос -> один ответ)
/// Демонстрирует выполнение базовых математических операций с числами
Future<void> main({bool debug = false}) async {
  printHeader('Пример унарных вызовов RPC');

  // Создаем транспорты в памяти
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  _logger.info('Транспорты соединены');

  // Создаем эндпоинты
  final client = RpcEndpoint(transport: clientTransport, debugLabel: 'client');
  final server = RpcEndpoint(transport: serverTransport, debugLabel: 'server');
  _logger.info('Эндпоинты созданы');

  // Добавляем middleware
  if (debug) {
    server.addMiddleware(DebugMiddleware(_logger));
    client.addMiddleware(DebugMiddleware(_logger));
  } else {
    server.addMiddleware(LoggingMiddleware(_logger));
    client.addMiddleware(LoggingMiddleware(_logger));
  }

  try {
    // Создаем и регистрируем контракты
    final serverContract = ServerBasicServiceContract();
    final clientContract = ClientBasicServiceContract(client);

    server.registerServiceContract(serverContract);
    client.registerServiceContract(clientContract);
    _logger.info('Контракты зарегистрированы');

    // Демонстрация математических операций
    await demonstrateBasicOperations(clientContract);
  } catch (e, stack) {
    _logger.error(
      'Произошла ошибка',
      error: {'error': e.toString()},
      stackTrace: stack,
    );
  } finally {
    // Закрываем эндпоинты
    await client.close();
    await server.close();
    _logger.info('Эндпоинты закрыты');
  }

  printHeader('Пример завершен');
}

/// Печатает заголовок раздела
void printHeader(String title) {
  _logger.info('-------------------------');
  _logger.info(' $title');
  _logger.info('-------------------------');
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
  _logger.info('Результат математических операций с $value1 и $value2:');

  _logger.info('  • Сумма: ${result.sum}');
  _logger.info('  • Разность: ${result.difference}');
  _logger.info('  • Произведение: ${result.product}');
  _logger.info('  • Частное: ${result.quotient}');
}
