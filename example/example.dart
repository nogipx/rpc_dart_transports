import 'package:rpc_dart/rpc_dart.dart';

import 'calculator/_index.dart';

/// Пример использования декларативного подхода
Future<void> main() async {
  // Создаем и настраиваем инфраструктуру
  final transport1 = MemoryTransport('client');
  final transport2 = MemoryTransport('server');

  // Соединяем транспорты
  transport1.connect(transport2);
  transport2.connect(transport1);

  final serializer = JsonSerializer();
  final client = RpcEndpoint(transport1, serializer);
  final server = RpcEndpoint(transport2, serializer);

  // // Добавляем middleware для измерения времени на стороне сервера
  // client.addMiddleware(DebugMiddleware(id: 'client'));
  // server.addMiddleware(DebugMiddleware(id: 'server'));

  // Создаем реализацию сервиса
  final serverContract = ServerCalculatorContract();

  // Регистрируем контракт на клиенте
  client.registerContract(serverContract);
  server.registerContract(serverContract);

  // Добавляем middleware для логирования на стороне клиента
  client.addMiddleware(LoggingMiddleware(
    logger: (message) => print(message),
  ));
  server.addMiddleware(LoggingMiddleware(
    logger: (message) => print(message),
  ));
  server.addMiddleware(
    TimingMiddleware(
      onTiming: (message, duration) => print(
        '🕒 Время выполнения: $message - ${duration.inMilliseconds}ms',
      ),
    ),
  );

  await testCalculatorService(client, serverContract.serviceName);

  // Закрываем ресурсы
  await client.close();
  await server.close();
}

/// Тестирует калькулятор
Future<void> testCalculatorService(
  RpcEndpoint endpoint,
  String serviceName,
) async {
  final calculator = ClientCalculatorContract(endpoint);

  try {
    print('Тест 1: Унарный метод - сложение');
    final addRequest = CalculatorRequest(10, 5);
    final addResponse = await calculator.add(addRequest);
    print(
      'Результат: ${addRequest.a} + ${addRequest.b} = ${addResponse.result}',
    );
  } catch (e) {
    print('  ❌ Ошибка при вызове унарных методов: $e');
  }

  print('\n');

  try {
    // Дополняем тест умножением для полноты примера
    print('Тест 2: Унарный метод - умножение');
    final multiplyRequest = CalculatorRequest(7, 8);
    final multiplyResponse = await calculator.multiply(multiplyRequest);
    print(
      'Результат: ${multiplyRequest.a} × ${multiplyRequest.b} = ${multiplyResponse.result}',
    );
  } catch (e) {
    print('❌ Ошибка при вызове унарных методов: $e');
  }

  print('\n');

  // Тест 3: Стриминг данных
  try {
    print('Тест 3: Стриминг данных');
    final sequenceRequest = SequenceRequest(4);
    final numbers = <int>[];

    final stream = calculator.generateSequence(sequenceRequest);

    await for (final number in stream) {
      numbers.add(number.count);
    }

    print('Стрим завершен, получена последовательность: $numbers');
  } catch (e) {
    print('Ошибка при стриминге: $e');
  }
}
