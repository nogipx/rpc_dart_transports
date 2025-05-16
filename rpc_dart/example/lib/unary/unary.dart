import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/diagnostics.dart';

import 'unary_contract.dart';
import 'unary_models.dart';

/// Константа с источником логов
const String _source = 'UnaryExample';

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
  RpcLog.info(message: 'Транспорты соединены', source: _source);

  // Создаем эндпоинты
  final client = RpcEndpoint(transport: clientTransport, debugLabel: 'client');
  final server = RpcEndpoint(transport: serverTransport, debugLabel: 'server');
  RpcLog.info(message: 'Эндпоинты созданы', source: _source);

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
    RpcLog.info(message: 'Контракты зарегистрированы', source: _source);

    // Демонстрация математических операций
    await demonstrateBasicOperations(clientContract);
  } catch (e, stack) {
    RpcLog.error(
      message: 'Произошла ошибка',
      source: _source,
      error: {'error': e.toString()},
      stackTrace: stack.toString(),
    );
  } finally {
    // Закрываем эндпоинты
    await client.close();
    await server.close();
    RpcLog.info(message: 'Эндпоинты закрыты', source: _source);
  }

  printHeader('Пример завершен');
}

/// Печатает заголовок раздела
void printHeader(String title) {
  RpcLog.info(message: '-------------------------', source: _source);
  RpcLog.info(message: ' $title', source: _source);
  RpcLog.info(message: '-------------------------', source: _source);
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
  RpcLog.info(
    message: 'Результат математических операций с $value1 и $value2:',
    source: _source,
  );

  RpcLog.info(message: '  • Сумма: ${result.sum}', source: _source);
  RpcLog.info(message: '  • Разность: ${result.difference}', source: _source);
  RpcLog.info(message: '  • Произведение: ${result.product}', source: _source);
  RpcLog.info(message: '  • Частное: ${result.quotient}', source: _source);
}
