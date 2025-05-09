import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'calculator/_index.dart';

/// Пример использования калькулятора с новым API
Future<void> main() async {
  print('Запуск примера калькулятора с новым API...');

  // Создаем транспорты для клиента и сервера
  final clientTransport = MemoryTransport('client');
  final serverTransport = MemoryTransport('server');

  // Соединяем транспорты
  clientTransport.connect(serverTransport);
  serverTransport.connect(clientTransport);
  print('Транспорты подключены');

  // Создаем сериализаторы
  final serializer = JsonSerializer();

  // Создаем эндпоинты
  final clientEndpoint = RpcEndpoint(
    transport: clientTransport,
    serializer: serializer,
  );
  final serverEndpoint = RpcEndpoint(
    transport: serverTransport,
    serializer: serializer,
  );
  print('Эндпоинты созданы');

  // Добавляем middleware для логирования
  clientEndpoint.addMiddleware(DebugMiddleware(id: 'client'));
  serverEndpoint.addMiddleware(DebugMiddleware(id: 'server'));

  // Создаем контракты
  final clientContract = ClientCalculatorContract(clientEndpoint);
  final serverContract = ServerCalculatorContract();

  // Регистрируем контракты
  serverEndpoint.registerServiceContract(serverContract);
  clientEndpoint.registerServiceContract(clientContract);
  print('Контракты зарегистрированы');

  try {
    // Унарные вызовы методов
    final addRequest = CalculatorRequest(5, 3);
    final addResponse = await clientContract.add(addRequest);
    print(
        'Результат сложения: ${addRequest.a} + ${addRequest.b} = ${addResponse.result}');

    final multiplyRequest = CalculatorRequest(4, 7);
    final multiplyResponse = await clientContract.multiply(multiplyRequest);
    print(
        'Результат умножения: ${multiplyRequest.a} * ${multiplyRequest.b} = ${multiplyResponse.result}');

    // Стриминговый вызов
    final sequenceRequest = SequenceRequest(5);
    print('Генерация последовательности из ${sequenceRequest.count} чисел:');

    final sequenceStream = clientContract.generateSequence(sequenceRequest);

    await for (final item in sequenceStream) {
      print('  Получено число: ${item.count}');
    }

    print('Последовательность завершена');
  } catch (e, stackTrace) {
    print('Ошибка при выполнении примера: $e');
    print('Трассировка стека: $stackTrace');
  } finally {
    // Закрываем эндпоинты
    await clientEndpoint.close();
    await serverEndpoint.close();
    print('Эндпоинты закрыты');
  }

  print('Пример завершен!');
}
