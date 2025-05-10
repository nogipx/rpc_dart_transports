import 'package:rpc_dart/rpc_dart.dart';

/// Пример использования унарных вызовов (одиночный запрос -> одиночный ответ)
/// Самый базовый тип RPC взаимодействия
void main() async {
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

  // Регистрируем контракты сервисов
  final basicService = SimpleRpcServiceContract('BasicService');
  final typedService = SimpleRpcServiceContract('TypedService');

  server.registerServiceContract(basicService);
  server.registerServiceContract(typedService);

  client.registerServiceContract(basicService);
  client.registerServiceContract(typedService);

  // Добавляем middleware для логирования
  server.addMiddleware(DebugMiddleware(id: 'server'));
  client.addMiddleware(DebugMiddleware(id: 'client'));

  try {
    // Регистрируем методы на сервере
    registerServerMethods(server);
    print('Методы зарегистрированы');

    // Демонстрация унарных вызовов с разными типами данных
    await demonstrateBasicUnary(client);

    // Демонстрация типизированных унарных вызовов с пользовательскими классами
    await demonstrateTypedUnary(client);

    // Демонстрация обработки ошибок
    await demonstrateErrorHandling(client);
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

/// Регистрация методов на сервере
void registerServerMethods(RpcEndpoint server) {
  // 1. Метод работы с примитивными числовыми значениями
  server.unary('BasicService', 'compute').register<RpcMap, RpcMap>(
        handler: (request) async {
          final value1 = request['value1'] as int;
          final value2 = request['value2'] as int;

          return RpcMap({
            'sum': RpcInt(value1 + value2),
            'difference': RpcInt(value1 - value2),
            'product': RpcInt(value1 * value2),
            'quotient':
                value2 != 0 ? RpcDouble(value1 / value2) : const RpcNull(),
          });
        },
        requestParser: RpcMap.fromJson,
        responseParser: RpcMap.fromJson,
      );

  // 2. Метод работы со строками
  server.unary('BasicService', 'transformText').register<RpcMap, RpcMap>(
        handler: (request) async {
          final text = request['text'] as String;
          final operation = request['operation'] as String;

          String result;
          switch (operation) {
            case 'uppercase':
              result = text.toUpperCase();
              break;
            case 'lowercase':
              result = text.toLowerCase();
              break;
            case 'reverse':
              result = text.split('').reversed.join();
              break;
            default:
              result = text;
          }

          return RpcMap({
            'result': RpcString(result),
            'length': RpcInt(result.length),
          });
        },
        requestParser: RpcMap.fromJson,
        responseParser: RpcMap.fromJson,
      );

  // 3. Метод с пользовательскими типами данных
  server
      .unary('TypedService', 'processData')
      .register<DataRequest, DataResponse>(
        handler: (request) async {
          // Создаем ответ на основе данных запроса
          return DataResponse(
            processedValue: request.value * 2,
            isSuccess: true,
            timestamp: DateTime.now().toIso8601String(),
          );
        },
        requestParser: DataRequest.fromJson,
        responseParser: DataResponse.fromJson,
      );

  // 4. Метод с возможностью ошибки
  server.unary('BasicService', 'divide').register<RpcMap, RpcMap>(
        handler: (request) async {
          final numerator = request['numerator'] as int;
          final denominator = request['denominator'] as int;

          if (denominator == 0) {
            throw Exception('Деление на ноль недопустимо');
          }

          return RpcMap({
            'result': RpcDouble(numerator / denominator),
          });
        },
        requestParser: RpcMap.fromJson,
        responseParser: RpcMap.fromJson,
      );
}

/// Демонстрация базовых унарных вызовов с примитивными типами
Future<void> demonstrateBasicUnary(RpcEndpoint client) async {
  print('\n--- Базовые унарные вызовы ---');

  // Вызов метода compute с числовыми параметрами
  final computeResult = await client.invoke(
    'BasicService',
    'compute',
    {'value1': 10, 'value2': 5},
  );
  print('Для значений 10 и 5:');
  print('  Сумма: ${computeResult['sum']}');
  print('  Разность: ${computeResult['difference']}');
  print('  Произведение: ${computeResult['product']}');
  print('  Частное: ${computeResult['quotient']}');

  // Вызов метода transformText для работы со строками
  final transformResult = await client.invoke(
    'BasicService',
    'transformText',
    {
      'text': 'Hello RPC World',
      'operation': 'uppercase',
    },
  );
  print('\nПреобразование текста в верхний регистр:');
  print('  Результат: ${transformResult['result']}');
  print('  Длина: ${transformResult['length']} символов');
}

/// Демонстрация типизированных унарных вызовов с пользовательскими классами
Future<void> demonstrateTypedUnary(RpcEndpoint client) async {
  print('\n--- Типизированные унарные вызовы ---');

  // Создаем типизированный запрос
  final request = DataRequest(value: 42, label: 'test_data');

  // Используем типизированный API для вызова
  final response = await client
      .unary('TypedService', 'processData')
      .call<DataRequest, DataResponse>(
        request: request,
        responseParser: DataResponse.fromJson,
      );

  print('Отправлено значение: ${request.value}');
  print('Получено обработанное значение: ${response.processedValue}');
  print('Статус успеха: ${response.isSuccess}');
  print('Временная метка: ${response.timestamp}');
}

/// Демонстрация обработки ошибок
Future<void> demonstrateErrorHandling(RpcEndpoint client) async {
  print('\n--- Обработка ошибок ---');

  // Вызываем метод с ошибкой (деление на ноль)
  try {
    await client.invoke(
      'BasicService',
      'divide',
      {'numerator': 10, 'denominator': 0},
    );
    print('Этот код не должен выполниться');
  } catch (e) {
    print('Перехвачена ошибка: $e');
  }

  // Успешное деление
  final divideResult = await client.invoke(
    'BasicService',
    'divide',
    {'numerator': 10, 'denominator': 2},
  );
  print('10 / 2 = ${divideResult['result']}');
}

/// Класс запроса с данными
class DataRequest implements IRpcSerializableMessage {
  final int value;
  final String label;

  DataRequest({
    required this.value,
    required this.label,
  });

  @override
  Map<String, dynamic> toJson() => {
        'value': value,
        'label': label,
      };

  static DataRequest fromJson(Map<String, dynamic> json) {
    return DataRequest(
      value: json['value'] as int,
      label: json['label'] as String,
    );
  }
}

/// Класс ответа с данными
class DataResponse implements IRpcSerializableMessage {
  final int processedValue;
  final bool isSuccess;
  final String timestamp;

  DataResponse({
    required this.processedValue,
    required this.isSuccess,
    required this.timestamp,
  });

  @override
  Map<String, dynamic> toJson() => {
        'processedValue': processedValue,
        'isSuccess': isSuccess,
        'timestamp': timestamp,
      };

  static DataResponse fromJson(Map<String, dynamic> json) {
    return DataResponse(
      processedValue: json['processedValue'] as int,
      isSuccess: json['isSuccess'] as bool,
      timestamp: json['timestamp'] as String,
    );
  }
}

/// Контракт сервиса для примера
final class SimpleRpcServiceContract extends RpcServiceContract {
  @override
  final String serviceName;

  SimpleRpcServiceContract(this.serviceName);

  @override
  void setup() {
    // Методы регистрируются программно
  }
}
