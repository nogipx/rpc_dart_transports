// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';
import 'fixtures/test_contract.dart';
import 'fixtures/test_factory.dart';

/// Специализированные сообщения для тестов калькулятора
class CalculationRequest implements IRpcSerializableMessage {
  final int a;
  final int b;
  final String operation;

  CalculationRequest(this.a, this.b, this.operation);

  @override
  Map<String, dynamic> toJson() => {
        'a': a,
        'b': b,
        'operation': operation,
      };

  static CalculationRequest fromJson(Map<String, dynamic> json) {
    return CalculationRequest(
      json['a'] as int,
      json['b'] as int,
      json['operation'] as String,
    );
  }
}

class CalculationResponse implements IRpcSerializableMessage {
  final int result;
  final String error;

  CalculationResponse(this.result, {this.error = ''});

  @override
  Map<String, dynamic> toJson() => {
        'result': result,
        'error': error,
      };

  static CalculationResponse fromJson(Map<String, dynamic> json) {
    return CalculationResponse(
      json['result'] as int,
      error: json['error'] as String? ?? '',
    );
  }
}

/// Контракт для тестов калькулятора, реализующий интерфейс расширения
abstract class CalculatorTestsContract extends RpcServiceContract {
  static const String calculateMethod = 'calculate';

  CalculatorTestsContract() : super('calculator_tests');

  @override
  void setup() {
    addUnaryRequestMethod<CalculationRequest, CalculationResponse>(
      methodName: calculateMethod,
      handler: calculate,
      argumentParser: CalculationRequest.fromJson,
      responseParser: CalculationResponse.fromJson,
    );

    super.setup();
  }

  Future<CalculationResponse> calculate(CalculationRequest request);
}

/// Серверная реализация калькулятора
class CalculatorTestsServer extends CalculatorTestsContract {
  // История запросов для тестирования
  final List<CalculationRequest> requestHistory = [];

  @override
  Future<CalculationResponse> calculate(CalculationRequest request) async {
    requestHistory.add(request);

    switch (request.operation) {
      case 'add':
        return CalculationResponse(request.a + request.b);
      case 'subtract':
        return CalculationResponse(request.a - request.b);
      case 'multiply':
        return CalculationResponse(request.a * request.b);
      case 'divide':
        if (request.b == 0) {
          return CalculationResponse(0, error: 'Деление на ноль');
        }
        return CalculationResponse(request.a ~/ request.b);
      default:
        return CalculationResponse(0, error: 'Неизвестная операция');
    }
  }
}

/// Клиентская реализация калькулятора
class CalculatorTestsClient extends CalculatorTestsContract {
  final RpcEndpoint _endpoint;

  CalculatorTestsClient(this._endpoint);

  @override
  Future<CalculationResponse> calculate(CalculationRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: CalculatorTestsContract.calculateMethod,
        )
        .call(
          request: request,
          responseParser: CalculationResponse.fromJson,
        );
  }
}

void main() {
  group('Тестирование унарного метода калькулятора', () {
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late CalculatorTestsClient calculatorClient;
    late CalculatorTestsServer calculatorServer;

    setUp(() {
      // Используем фабрику для создания тестового окружения
      final testEnv = TestFactory.setupTestContract(
        clientFactory: (endpoint) => CalculatorTestsClient(endpoint),
        serverFactory: () => CalculatorTestsServer(),
      );

      clientEndpoint = testEnv.clientEndpoint;
      serverEndpoint = testEnv.serverEndpoint;

      // Получаем конкретные реализации из мапы расширений
      calculatorClient = testEnv.clientContract;
      calculatorServer = testEnv.serverContract;
    });

    tearDown(() async {
      await TestFixtureUtils.tearDown(clientEndpoint, serverEndpoint);
    });

    test('успешный_вызов_унарного_метода_сложения', () async {
      // Вызываем метод сложения чисел
      final request = CalculationRequest(5, 3, 'add');
      final response = await calculatorClient.calculate(request);

      // Проверяем результат
      expect(response.result, equals(8));
      expect(response.error, isEmpty);

      // Проверяем, что запрос был получен сервером
      expect(calculatorServer.requestHistory.length, equals(1));
      expect(calculatorServer.requestHistory[0].a, equals(5));
      expect(calculatorServer.requestHistory[0].b, equals(3));
      expect(calculatorServer.requestHistory[0].operation, equals('add'));
    });

    test('успешный_вызов_унарного_метода_вычитания', () async {
      // Вызываем метод вычитания чисел
      final request = CalculationRequest(10, 4, 'subtract');
      final response = await calculatorClient.calculate(request);

      // Проверяем результат
      expect(response.result, equals(6));
      expect(response.error, isEmpty);
    });

    test('успешный_вызов_унарного_метода_умножения', () async {
      // Вызываем метод умножения чисел
      final request = CalculationRequest(7, 8, 'multiply');
      final response = await calculatorClient.calculate(request);

      // Проверяем результат
      expect(response.result, equals(56));
      expect(response.error, isEmpty);
    });

    test('обработка_ошибки_деления_на_ноль', () async {
      // Вызываем метод деления на ноль
      final request = CalculationRequest(42, 0, 'divide');
      final response = await calculatorClient.calculate(request);

      // Проверяем результат
      expect(response.result, equals(0));
      expect(response.error, equals('Деление на ноль'));
    });

    test('обработка_неизвестной_операции', () async {
      // Вызываем метод с неизвестной операцией
      final request = CalculationRequest(5, 5, 'unknown');
      final response = await calculatorClient.calculate(request);

      // Проверяем результат
      expect(response.result, equals(0));
      expect(response.error, equals('Неизвестная операция'));
    });

    test('множественные_вызовы_метода', () async {
      // Выполняем серию вызовов
      final operations = ['add', 'subtract', 'multiply', 'divide'];
      final expected = [15, 5, 50, 2];

      for (var i = 0; i < operations.length; i++) {
        final request = CalculationRequest(10, 5, operations[i]);
        final response = await calculatorClient.calculate(request);

        expect(response.result, equals(expected[i]));
      }

      // Проверяем, что все запросы были получены сервером
      expect(calculatorServer.requestHistory.length, equals(operations.length));
    });
  });
}
