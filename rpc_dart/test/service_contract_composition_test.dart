// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';
import 'fixtures/test_contract.dart';

// Определение сообщений для тестов
class TestMessage implements IRpcSerializableMessage {
  final String data;
  const TestMessage(this.data);

  @override
  Map<String, dynamic> toJson() => {'data': data};

  factory TestMessage.fromJson(Map<String, dynamic> json) {
    return TestMessage(json['data'] as String? ?? '');
  }

  @override
  String toString() => 'TestMessage(data: $data)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestMessage && other.data == data;
  }

  @override
  int get hashCode => data.hashCode;
}

class RootRequest extends TestMessage {
  RootRequest(super.data);

  factory RootRequest.fromJson(Map<String, dynamic> json) {
    return RootRequest(json['data'] as String? ?? '');
  }
}

class RootResponse extends TestMessage {
  RootResponse(super.data);

  factory RootResponse.fromJson(Map<String, dynamic> json) {
    return RootResponse(json['data'] as String? ?? '');
  }
}

class ChildRequest extends TestMessage {
  ChildRequest(super.data);

  factory ChildRequest.fromJson(Map<String, dynamic> json) {
    return ChildRequest(json['data'] as String? ?? '');
  }
}

class ChildResponse extends TestMessage {
  ChildResponse(super.data);

  factory ChildResponse.fromJson(Map<String, dynamic> json) {
    return ChildResponse(json['data'] as String? ?? '');
  }
}

// Определение контрактов для тестов
class RootContract extends RpcServiceContract {
  RootContract() : super('RootService');

  @override
  void setup() {
    // Собственный метод корневого контракта
    addUnaryRequestMethod<RootRequest, RootResponse>(
      methodName: 'rootMethod',
      handler: _rootMethodHandler,
      argumentParser: RootRequest.fromJson,
      responseParser: RootResponse.fromJson,
    );

    // Добавление дочерних контрактов
    addSubContract(ChildContract('ChildService1'));
    addSubContract(ChildContract('ChildService2'));

    // Важно вызвать super.setup() после добавления всех подконтрактов!
    super.setup();
  }

  Future<RootResponse> _rootMethodHandler(dynamic context) async {
    final RootRequest req;

    if (context is Map<String, dynamic>) {
      req = RootRequest.fromJson(context);
    } else if (context is RootRequest) {
      req = context;
    } else {
      final payload = (context as dynamic).payload;
      if (payload is RootRequest) {
        req = payload;
      } else if (payload is Map<String, dynamic>) {
        req = RootRequest.fromJson(payload);
      } else {
        throw Exception('Неожиданный тип запроса: ${context.runtimeType}');
      }
    }

    return RootResponse('root:${req.data}');
  }
}

class ChildContract extends RpcServiceContract {
  ChildContract(String serviceName) : super(serviceName);

  @override
  void setup() {
    // Метод дочернего контракта
    addUnaryRequestMethod<ChildRequest, ChildResponse>(
      methodName: 'childMethod',
      handler: _childMethodHandler,
      argumentParser: ChildRequest.fromJson,
      responseParser: ChildResponse.fromJson,
    );

    super.setup();
  }

  Future<ChildResponse> _childMethodHandler(dynamic context) async {
    final ChildRequest req;

    if (context is Map<String, dynamic>) {
      req = ChildRequest.fromJson(context);
    } else if (context is ChildRequest) {
      req = context;
    } else {
      final payload = (context as dynamic).payload;
      if (payload is ChildRequest) {
        req = payload;
      } else if (payload is Map<String, dynamic>) {
        req = ChildRequest.fromJson(payload);
      } else {
        throw Exception('Неожиданный тип запроса: ${context.runtimeType}');
      }
    }

    return ChildResponse('$serviceName:${req.data}');
  }
}

// Многоуровневая композиция
class GrandchildContract extends RpcServiceContract {
  GrandchildContract() : super('GrandchildService');

  @override
  void setup() {
    addUnaryRequestMethod<ChildRequest, ChildResponse>(
      methodName: 'grandchildMethod',
      handler: _grandchildMethodHandler,
      argumentParser: ChildRequest.fromJson,
      responseParser: ChildResponse.fromJson,
    );

    super.setup();
  }

  Future<ChildResponse> _grandchildMethodHandler(dynamic context) async {
    final ChildRequest req;

    if (context is Map<String, dynamic>) {
      req = ChildRequest.fromJson(context);
    } else if (context is ChildRequest) {
      req = context;
    } else {
      final payload = (context as dynamic).payload;
      if (payload is ChildRequest) {
        req = payload;
      } else if (payload is Map<String, dynamic>) {
        req = ChildRequest.fromJson(payload);
      } else {
        throw Exception('Неожиданный тип запроса: ${context.runtimeType}');
      }
    }

    return ChildResponse('grandchild:${req.data}');
  }
}

class NestedCompositionContract extends RpcServiceContract {
  NestedCompositionContract() : super('NestedService');

  @override
  void setup() {
    // Добавляем многоуровневую композицию
    final childWithGrandchild = ChildContract('ChildWithGrandchild');
    childWithGrandchild.addSubContract(GrandchildContract());

    addSubContract(childWithGrandchild);
    super.setup();
  }
}

void main() {
  group('Композиция сервисных контрактов', () {
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;

    setUp(() {
      // Используем TestFixtureUtils для создания пары эндпоинтов
      final endpoints = TestFixtureUtils.createEndpointPair();
      clientEndpoint = endpoints.client;
      serverEndpoint = endpoints.server;
    });

    tearDown(() async {
      await TestFixtureUtils.tearDown(clientEndpoint, serverEndpoint);
    });

    test(
        'Методы из составного контракта должны быть доступны после регистрации',
        () async {
      // Регистрируем корневой контракт на сервере
      final rootContract = RootContract();

      // Регистрируем только основной контракт (дочерние зарегистрируются автоматически)
      serverEndpoint.registerServiceContract(rootContract);

      // На стороне клиента создаем методы для вызова
      final rootMethod = clientEndpoint.unaryRequest(
        serviceName: 'RootService',
        methodName: 'rootMethod',
      );

      final childMethod1 = clientEndpoint.unaryRequest(
        serviceName: 'ChildService1',
        methodName: 'childMethod',
      );

      final childMethod2 = clientEndpoint.unaryRequest(
        serviceName: 'ChildService2',
        methodName: 'childMethod',
      );

      // Проверяем вызовы методов
      final rootResponse = await rootMethod.call(
        request: RootRequest('test'),
        responseParser: RootResponse.fromJson,
      );

      final childResponse1 = await childMethod1.call(
        request: ChildRequest('test1'),
        responseParser: ChildResponse.fromJson,
      );

      final childResponse2 = await childMethod2.call(
        request: ChildRequest('test2'),
        responseParser: ChildResponse.fromJson,
      );

      // Проверяем результаты
      expect(rootResponse.data, equals('root:test'));
      expect(childResponse1.data, equals('ChildService1:test1'));
      expect(childResponse2.data, equals('ChildService2:test2'));
    });

    test(
        'При многоуровневой композиции необходимо регистрировать все контракты',
        () async {
      // Регистрируем контракт с многоуровневой композицией
      final nestedContract = NestedCompositionContract();
      serverEndpoint.registerServiceContract(nestedContract);

      // Создаем метод для вызова на сервере второго уровня
      final childMethod = clientEndpoint.unaryRequest(
        serviceName: 'ChildWithGrandchild',
        methodName: 'childMethod',
      );

      // Создаем метод для вызова на сервере третьего уровня
      final grandchildMethod = clientEndpoint.unaryRequest(
        serviceName: 'GrandchildService',
        methodName: 'grandchildMethod',
      );

      // Проверяем вызовы
      final childResponse = await childMethod.call(
        request: ChildRequest('nested-test'),
        responseParser: ChildResponse.fromJson,
      );

      final grandchildResponse = await grandchildMethod.call(
        request: ChildRequest('deep-test'),
        responseParser: ChildResponse.fromJson,
      );

      // Проверяем результаты
      expect(childResponse.data, equals('ChildWithGrandchild:nested-test'));
      expect(grandchildResponse.data, equals('grandchild:deep-test'));
    });

    test(
        'Композиция добавляет методы подконтрактов в метаданные родительского контракта',
        () {
      // Регистрируем корневой контракт
      final rootContract = RootContract();

      // Запускаем настройку контракта (это обычно делает endppoint.registerServiceContract)
      rootContract.setup();

      // Проверяем что в методах родительского контракта есть методы дочерних
      final methods = rootContract.methods;

      // Должно быть как минимум 3 метода:
      // 1 метод родителя + 2 метода от дочерних контрактов
      expect(methods.length, greaterThanOrEqualTo(3));

      // Проверяем имена методов
      final methodNames = methods.map((m) => m.methodName).toList();
      expect(methodNames, contains('rootMethod'));
      expect(methodNames, contains('childMethod'));

      // Проверяем доступность методов через API контракта
      final rootMethodContract = rootContract.findMethod('rootMethod');
      final childMethodContract = rootContract.findMethod('childMethod');

      expect(rootMethodContract, isNotNull);
      expect(childMethodContract, isNotNull);

      // Проверяем типы методов
      expect(rootMethodContract?.methodType, equals(RpcMethodType.unary));
      expect(childMethodContract?.methodType, equals(RpcMethodType.unary));

      // Проверяем извлечение обработчиков
      final rootHandler = rootContract.getMethodHandler('rootMethod');
      final childHandler = rootContract.getMethodHandler('childMethod');

      expect(rootHandler, isNotNull);
      expect(childHandler, isNotNull);
    });

    test('Подконтракты должны автоматически регистрироваться в эндпоинте', () {
      // Регистрируем только корневой контракт
      final rootContract = RootContract();
      serverEndpoint.registerServiceContract(rootContract);

      // Проверяем, что дочерние контракты тоже автоматически зарегистрировались
      final rootServiceContract =
          serverEndpoint.getServiceContract('RootService');
      final childService1Contract =
          serverEndpoint.getServiceContract('ChildService1');
      final childService2Contract =
          serverEndpoint.getServiceContract('ChildService2');

      // Все контракты должны быть найдены
      expect(rootServiceContract, isNotNull);
      expect(childService1Contract, isNotNull);
      expect(childService2Contract, isNotNull);

      // Проверяем возможность вызова методов из дочерних контрактов
      // без необходимости их отдельной регистрации
      final rootMethod = clientEndpoint.unaryRequest(
        serviceName: 'RootService',
        methodName: 'rootMethod',
      );

      final childMethod1 = clientEndpoint.unaryRequest(
        serviceName: 'ChildService1',
        methodName: 'childMethod',
      );

      final childMethod2 = clientEndpoint.unaryRequest(
        serviceName: 'ChildService2',
        methodName: 'childMethod',
      );

      expect(rootMethod, isNotNull);
      expect(childMethod1, isNotNull);
      expect(childMethod2, isNotNull);
    });

    test(
        'Многоуровневая композиция должна автоматически регистрировать все уровни',
        () async {
      // Регистрируем контракт с многоуровневой композицией
      final nestedContract = NestedCompositionContract();
      serverEndpoint.registerServiceContract(nestedContract);

      // Проверяем, что контракты всех уровней автоматически зарегистрировались
      final nestedServiceContract =
          serverEndpoint.getServiceContract('NestedService');
      final childWithGrandchildContract =
          serverEndpoint.getServiceContract('ChildWithGrandchild');
      final grandchildServiceContract =
          serverEndpoint.getServiceContract('GrandchildService');

      // Все контракты должны быть найдены
      expect(nestedServiceContract, isNotNull);
      expect(childWithGrandchildContract, isNotNull);
      expect(grandchildServiceContract, isNotNull);

      // Проверяем возможность вызова методов из вложенных контрактов
      // без необходимости их отдельной регистрации
      final childMethod = clientEndpoint.unaryRequest(
        serviceName: 'ChildWithGrandchild',
        methodName: 'childMethod',
      );

      final grandchildMethod = clientEndpoint.unaryRequest(
        serviceName: 'GrandchildService',
        methodName: 'grandchildMethod',
      );

      // Вызываем методы и проверяем результаты
      final childResponse = await childMethod.call(
        request: ChildRequest('auto-test'),
        responseParser: ChildResponse.fromJson,
      );

      final grandchildResponse = await grandchildMethod.call(
        request: ChildRequest('auto-nested'),
        responseParser: ChildResponse.fromJson,
      );

      expect(childResponse.data, equals('ChildWithGrandchild:auto-test'));
      expect(grandchildResponse.data, equals('grandchild:auto-nested'));
    });

    test('Отладка регистрации контрактов', () {
      // Регистрируем только корневой контракт
      final rootContract = RootContract();
      serverEndpoint.registerServiceContract(rootContract);

      // Получаем список всех зарегистрированных контрактов
      final allContracts = serverEndpoint.getAllContracts();
      print('Зарегистрированные контракты:');
      for (final entry in allContracts.entries) {
        print('  - ${entry.key}: ${entry.value.runtimeType}');
      }

      // Проверяем, есть ли в списке подконтракты
      expect(allContracts.containsKey('RootService'), isTrue);
      expect(allContracts.containsKey('ChildService1'), isTrue);
      expect(allContracts.containsKey('ChildService2'), isTrue);
    });
  });
}
