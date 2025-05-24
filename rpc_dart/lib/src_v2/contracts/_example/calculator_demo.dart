import 'dart:async';
import 'dart:math';

import 'package:rpc_dart/src_v2/logs/_logs.dart';

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
  RpcLoggerSettings.setDefaultMinLogLevel(RpcLoggerLevel.debug);

  // Создаем эндпоинты для клиента и сервера
  final serverEndpoint = RpcResponderEndpoint(transport: transport.$1);
  final clientEndpoint = RpcCallerEndpoint(transport: transport.$2);

  // Создаем сервер и регистрируем его
  final server = CalculatorServer(simulatedDelayMs: 50);
  serverEndpoint.registerServiceContract(server);

  // Создаем клиента
  final client = CalculatorClient(clientEndpoint);

  // Проверка типобезопасности: теперь клиентский контракт нельзя зарегистрировать
  // Раскомментируйте строку ниже, чтобы увидеть ошибку компиляции:
  // serverEndpoint.registerServiceContract(client); // ❌ Ошибка компиляции!

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
    print('DEBUG: Начало _demoUnaryCalculation');

    // Сложение
    print('DEBUG: Вызов client.add(5, 3)');
    final sum = await client.add(5, 3);
    print('5 + 3 = $sum');

    // Вычитание
    print('DEBUG: Вызов client.subtract(10, 4)');
    final diff = await client.subtract(10, 4);
    print('10 - 4 = $diff');

    // Умножение
    print('DEBUG: Вызов client.multiply(6, 7)');
    final product = await client.multiply(6, 7);
    print('6 * 7 = $product');

    // Деление
    print('DEBUG: Вызов client.divide(20, 4)');
    final quotient = await client.divide(20, 4);
    print('20 / 4 = $quotient');

    // Обработка ошибки
    try {
      print('DEBUG: Вызов client.divide(5, 0)');
      await client.divide(5, 0);
    } catch (e) {
      print('Ошибка деления на ноль: $e');
    }

    print('DEBUG: Завершение _demoUnaryCalculation');
  } catch (e) {
    print('Ошибка при выполнении унарных вычислений: $e');
    print('DEBUG: Stack trace: ${StackTrace.current}');
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
  try {
    await runCalculatorDemo();
  } catch (e) {
    print('Ошибка при запуске демонстрации: $e');
  }
}
