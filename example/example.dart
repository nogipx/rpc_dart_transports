import 'package:rpc_dart/rpc_dart.dart';

import 'calculator/_index.dart';
import 'debug_transport.dart';

/// Пример использования декларативного подхода
Future<void> main() async {
  print('🚀 Демонстрация работы c декларативным подходом\n');

  // Создаем и настраиваем инфраструктуру
  final transport1 = DebugTransport('client');
  final transport2 = DebugTransport('server');

  // Соединяем транспорты
  transport1.connect(transport2);
  transport2.connect(transport1);

  final serializer = JsonSerializer();
  final client = TypedRpcEndpoint(transport1, serializer);
  final server = TypedRpcEndpoint(transport2, serializer);

  // Создаем реализацию сервиса
  final serverContract = ServerCalculatorContract();

  // Регистрируем контракт на клиенте
  client.registerContract(serverContract);
  server.registerContract(serverContract);

  await testCalculatorService(client, serverContract.serviceName);

  // Закрываем ресурсы
  print('\n🧹 Закрытие соединений и освобождение ресурсов...');
  await client.close();
  await server.close();

  print('\n🎉 Демонстрация успешно завершена!');
}

/// Тестирует калькулятор
Future<void> testCalculatorService(
  TypedRpcEndpoint endpoint,
  String serviceName,
) async {
  final calculator = ClientCalculatorContract(endpoint);
  print('\n');

  try {
    print('\n✅ Тест 1: Унарный метод - сложение');
    final addRequest = CalculatorRequest(10, 5);
    final addResponse = await calculator.add(addRequest);
    print(
        '  Результат: ${addRequest.a} + ${addRequest.b} = ${addResponse.result}');
  } catch (e) {
    print('  ❌ Ошибка при вызове унарных методов: $e');
  }

  print('\n');

  try {
    // Дополняем тест умножением для полноты примера
    print('\n✅ Тест 2: Унарный метод - умножение');
    final multiplyRequest = CalculatorRequest(7, 8);
    final multiplyResponse = await calculator.multiply(multiplyRequest);
    print(
        '  Результат: ${multiplyRequest.a} × ${multiplyRequest.b} = ${multiplyResponse.result}');
  } catch (e) {
    print('  ❌ Ошибка при вызове унарных методов: $e');
  }

  print('\n');

  // Тест 3: Стриминг данных
  try {
    print('\n✅ Тест 3: Стриминг данных');
    final sequenceRequest = SequenceRequest(20);
    final numbers = <int>[];

    print('  Открываем стрим для получения последовательности...');
    final stream = calculator.generateSequence(sequenceRequest);

    await for (final number in stream) {
      print('  📦 Получено число: $number');
      numbers.add(number.count);
    }

    print('  ✓ Стрим завершен, получена последовательность: $numbers');
  } catch (e) {
    print('  ❌ Ошибка при стриминге: $e');
  }
}
