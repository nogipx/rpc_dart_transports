import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Endpoint Communication Integration Tests', () {
    late MemoryTransport transport1;
    late MemoryTransport transport2;
    late JsonSerializer serializer;
    late RpcEndpoint endpoint1;
    late RpcEndpoint endpoint2;

    setUp(() {
      // Создаем транспорты
      transport1 = MemoryTransport('transport1');
      transport2 = MemoryTransport('transport2');

      // Соединяем транспорты
      transport1.connect(transport2);
      transport2.connect(transport1);

      // Сериализатор
      serializer = JsonSerializer();

      // Создаем конечные точки
      endpoint1 = RpcEndpoint(
        transport: transport1,
        serializer: serializer,
      );
      endpoint2 = RpcEndpoint(
        transport: transport2,
        serializer: serializer,
      );
    });

    tearDown(() async {
      // Освобождаем ресурсы
      await endpoint1.close();
      await endpoint2.close();
    });

    test('should successfully invoke remote method', () async {
      // Arrange
      const serviceName = 'CalculatorService';
      const methodName = 'add';
      final request = {'a': 5, 'b': 3};
      final expectedResponse = {'result': 8};

      // Регистрируем обработчик метода на второй конечной точке
      endpoint2.registerMethod(
        serviceName: serviceName,
        methodName: methodName,
        handler: (context) async {
          final payload = context.payload as Map<String, dynamic>;
          final a = payload['a'] as int;
          final b = payload['b'] as int;
          return {'result': a + b};
        },
      );

      // Act
      final result = await endpoint1.invoke(
        serviceName: serviceName,
        methodName: methodName,
        request: request,
      );

      // Assert
      expect(result, equals(expectedResponse));
    });

    test('should handle errors from remote method', () async {
      // Arrange
      const serviceName = 'ErrorService';
      const methodName = 'failingMethod';

      // Регистрируем обработчик, который всегда бросает ошибку
      endpoint2.registerMethod(
        serviceName: serviceName,
        methodName: methodName,
        handler: (context) async {
          throw 'Simulated error';
        },
      );

      // Act & Assert
      expect(
        endpoint1.invoke(
          serviceName: serviceName,
          methodName: methodName,
          request: {},
        ),
        throwsA(contains('Simulated error')),
      );
    });

    test('should handle bidirectional communication', () async {
      // Arrange
      // Регистрируем метод на endpoint1
      endpoint1.registerMethod(
        serviceName: 'Service1',
        methodName: 'method1',
        handler: (context) async {
          return {'response': 'from endpoint1'};
        },
      );

      // Регистрируем метод на endpoint2
      endpoint2.registerMethod(
        serviceName: 'Service2',
        methodName: 'method2',
        handler: (context) async {
          return {'response': 'from endpoint2'};
        },
      );

      // Act
      // Вызываем метод с endpoint1 на endpoint2
      final result1 = await endpoint1.invoke(
        serviceName: 'Service2',
        methodName: 'method2',
        request: {},
      );

      // Вызываем метод с endpoint2 на endpoint1
      final result2 = await endpoint2.invoke(
        serviceName: 'Service1',
        methodName: 'method1',
        request: {},
      );

      // Assert
      expect(result1, equals({'response': 'from endpoint2'}));
      expect(result2, equals({'response': 'from endpoint1'}));
    });

    test('should correctly work with explicit streamId', () async {
      // Arrange
      const serviceName = 'StreamService';
      const methodName = 'streamNumbers';
      const customStreamId = 'test-stream-123'; // Фиксированный ID потока

      final receivedNumbers = <int>[];
      final completer = Completer<void>();

      // Регистрируем обработчик, который не будет отправлять данные
      endpoint2.registerMethod(
        serviceName: serviceName,
        methodName: methodName,
        handler: (context) async {
          final payload = context.payload as Map<String, dynamic>;
          final streamId = payload['streamId'] as String;
          expect(streamId, equals(customStreamId),
              reason: 'StreamID в запросе должен совпадать с кастомным ID');

          // Просто возвращаем статус
          return {'status': 'ok'};
        },
      );

      // Act
      // Открываем поток с явным указанием ID
      final stream = endpoint1.openStream(
        serviceName: serviceName,
        methodName: methodName,
        request: {'streamId': customStreamId},
        streamId: customStreamId, // Важно - указываем явный streamId
      );

      // Подписываемся на поток
      stream.listen(
        (data) {
          receivedNumbers.add(data as int);
        },
        onDone: () {
          completer.complete();
        },
      );

      // Ждем обработки запроса
      await Future.delayed(Duration(milliseconds: 100));

      // Отправляем данные через поток, используя указанный streamId
      for (var i = 1; i <= 3; i++) {
        final message = RpcMessage(
          type: RpcMessageType.streamData,
          id: customStreamId, // Используем тот же ID, что указали при открытии потока
          payload: i,
        );

        final data = serializer.serialize(message.toJson());
        await transport2.send(data);
      }

      // Закрываем поток
      final endMessage = RpcMessage(
        type: RpcMessageType.streamEnd,
        id: customStreamId,
      );

      final endData = serializer.serialize(endMessage.toJson());
      await transport2.send(endData);

      // Ждем завершения потока
      await completer.future.timeout(Duration(seconds: 1));

      // Assert
      expect(receivedNumbers, equals([1, 2, 3]),
          reason: 'Должны получить все отправленные числа');
    });
  });
}
