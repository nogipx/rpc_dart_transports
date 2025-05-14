// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Модель сообщения-запроса
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

// Модель сообщения-ответа
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

// Контракт сервиса калькулятора
abstract base class CalculatorServiceContract
    extends RpcServiceContract<IRpcSerializableMessage> {
  CalculatorServiceContract() : super('CalculatorService');

  RpcEndpoint? get client;

  // Константы для имен методов
  static const String calculateMethod = 'calculate';

  @override
  void setup() {
    // Унарный метод для расчетов
    addUnaryRequestMethod<CalculationRequest, CalculationResponse>(
      methodName: calculateMethod,
      handler: calculate,
      argumentParser: CalculationRequest.fromJson,
      responseParser: CalculationResponse.fromJson,
    );
    super.setup();
  }

  // Унарный метод
  Future<CalculationResponse> calculate(CalculationRequest request);
}

// Серверная реализация
base class ServerCalculatorService extends CalculatorServiceContract {
  final List<CalculationRequest> requestHistory = [];

  @override
  RpcEndpoint? get client => null;

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

// Клиентская реализация
base class ClientCalculatorService extends CalculatorServiceContract {
  @override
  final RpcEndpoint client;

  ClientCalculatorService(this.client);

  @override
  Future<CalculationResponse> calculate(CalculationRequest request) {
    return client
        .unaryRequest(
          serviceName: serviceName,
          methodName: CalculatorServiceContract.calculateMethod,
        )
        .call<CalculationRequest, CalculationResponse>(
          request: request,
          responseParser: CalculationResponse.fromJson,
        );
  }
}

void main() {
  group('Тестирование унарного метода', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late JsonSerializer serializer;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientCalculatorService clientService;
    late ServerCalculatorService serverService;

    setUp(() {
      // Создаем пару связанных транспортов
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Сериализатор
      serializer = JsonSerializer();

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: serializer,
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: serializer,
      );

      // Создаем сервисы
      serverService = ServerCalculatorService();
      clientService = ClientCalculatorService(clientEndpoint);

      // Регистрируем контракт сервера
      serverEndpoint.registerServiceContract(serverService);
    });

    tearDown(() async {
      await clientEndpoint.close();
      await serverEndpoint.close();
    });

    test('успешный_вызов_унарного_метода_сложения', () async {
      // Вызываем метод сложения чисел
      final request = CalculationRequest(5, 3, 'add');
      final response = await clientService.calculate(request);

      // Проверяем результат
      expect(response.result, equals(8));
      expect(response.error, isEmpty);

      // Проверяем, что запрос был получен сервером
      expect(serverService.requestHistory.length, equals(1));
      expect(serverService.requestHistory[0].a, equals(5));
      expect(serverService.requestHistory[0].b, equals(3));
      expect(serverService.requestHistory[0].operation, equals('add'));
    });

    test('успешный_вызов_унарного_метода_вычитания', () async {
      // Вызываем метод вычитания чисел
      final request = CalculationRequest(10, 4, 'subtract');
      final response = await clientService.calculate(request);

      // Проверяем результат
      expect(response.result, equals(6));
      expect(response.error, isEmpty);
    });

    test('успешный_вызов_унарного_метода_умножения', () async {
      // Вызываем метод умножения чисел
      final request = CalculationRequest(7, 8, 'multiply');
      final response = await clientService.calculate(request);

      // Проверяем результат
      expect(response.result, equals(56));
      expect(response.error, isEmpty);
    });

    test('обработка_ошибки_деления_на_ноль', () async {
      // Вызываем метод деления на ноль
      final request = CalculationRequest(42, 0, 'divide');
      final response = await clientService.calculate(request);

      // Проверяем результат
      expect(response.result, equals(0));
      expect(response.error, equals('Деление на ноль'));
    });

    test('обработка_неизвестной_операции', () async {
      // Вызываем метод с неизвестной операцией
      final request = CalculationRequest(5, 5, 'unknown');
      final response = await clientService.calculate(request);

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
        final response = await clientService.calculate(request);

        expect(response.result, equals(expected[i]));
      }

      // Проверяем, что все запросы были получены сервером
      expect(serverService.requestHistory.length, equals(operations.length));
    });
  });
}
