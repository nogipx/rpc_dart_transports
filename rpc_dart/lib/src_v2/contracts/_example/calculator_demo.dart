import 'dart:async';
import 'dart:math';
import '../_index.dart';
import '../../rpc/_index.dart';
import 'calculator_client.dart';
import 'calculator_server.dart';
import 'calculator_contract.dart';

/// Демонстрация использования калькулятора
Future<void> runCalculatorDemo() async {
  print('===== Запуск демонстрации калькулятора =====');

  // Создаем транспорт в памяти для демонстрации
  final transport = RpcInMemoryTransport.pair();

  // Создаем эндпоинты для клиента и сервера
  final serverEndpoint = RpcEndpoint(transport: transport.$1);
  final clientEndpoint = RpcEndpoint(transport: transport.$2);

  // Создаем сервер и регистрируем его
  final server = CalculatorServer(simulatedDelayMs: 50);
  serverEndpoint.registerServiceContract(server);

  // Создаем клиента
  final client = CalculatorClient(clientEndpoint);

  // Проверка типобезопасности: попытка регистрации клиентского контракта не должна компилироваться
  // Раскомментируйте строку ниже, чтобы увидеть ошибку компиляции:
  // clientEndpoint.registerServiceContract(client); // ❌ Ошибка компиляции!

  // 1. Демонстрация унарного метода
  print('\n--- Унарный метод: calculate ---');
  await _demoUnaryCalculation(client);

  // 2. Демонстрация бинарной сериализации
  print('\n--- Бинарная сериализация ---');
  await _demoBinarySerialization(client);

  // 3. Демонстрация двунаправленного стрима
  print('\n--- Двунаправленный стрим: streamCalculate ---');
  await _demoBidirectionalStream(client);

  // Закрываем эндпоинты
  await serverEndpoint.close();
  await clientEndpoint.close();

  print('\n===== Демонстрация калькулятора завершена =====');
}

/// Демонстрация унарных вычислений
Future<void> _demoUnaryCalculation(CalculatorClient client) async {
  try {
    // Сложение
    final sum = await client.add(5, 3);
    print('5 + 3 = $sum');

    // Вычитание
    final diff = await client.subtract(10, 4);
    print('10 - 4 = $diff');

    // Умножение
    final product = await client.multiply(6, 7);
    print('6 * 7 = $product');

    // Деление
    final quotient = await client.divide(20, 4);
    print('20 / 4 = $quotient');

    // Обработка ошибки
    try {
      await client.divide(5, 0);
    } catch (e) {
      print('Ошибка деления на ноль: $e');
    }
  } catch (e) {
    print('Ошибка при выполнении унарных вычислений: $e');
  }
}

/// Демонстрация бинарной сериализации
Future<void> _demoBinarySerialization(CalculatorClient client) async {
  try {
    // Используем бинарную сериализацию
    final response = await client.calculateBinary(
      a: 100,
      b: 25,
      operation: 'subtract',
    );

    print('Бинарная сериализация: 100 - 25 = ${response.result}');
    print('Формат: ${RpcSerializationFormat.binary.name}');
  } catch (e) {
    print('Ошибка при бинарной сериализации: $e');
  }
}

/// Демонстрация двунаправленного стрима
Future<void> _demoBidirectionalStream(CalculatorClient client) async {
  final random = Random();

  // Создаем контроллер для отправки запросов
  final requestController = StreamController<CalculationRequest>();

  // Подписываемся на стрим ответов
  final responseSubscription =
      client.streamCalculate(requestController.stream).listen(
    (response) {
      if (response.success) {
        print('Результат: ${response.result}');
      } else {
        print('Ошибка: ${response.errorMessage}');
      }
    },
    onError: (e) => print('Ошибка стрима: $e'),
    onDone: () => print('Стрим завершен'),
  );

  // Отправляем серию случайных операций
  final operations = ['add', 'subtract', 'multiply', 'divide'];

  for (int i = 0; i < 5; i++) {
    final a = random.nextDouble() * 10;
    final b = random.nextDouble() * 5;
    final operation = operations[random.nextInt(operations.length)];

    print('Отправка: $a $operation $b');

    requestController.add(CalculationRequest(
      a: a,
      b: b,
      operation: operation,
    ));

    // Небольшая пауза между запросами
    await Future.delayed(Duration(milliseconds: 100));
  }

  // Завершаем стрим запросов
  await requestController.close();

  // Ждем завершения всех ответов
  await responseSubscription.asFuture();
  await responseSubscription.cancel();
}

/// Точка входа для демонстрации
void main() async {
  await runCalculatorDemo();
}
