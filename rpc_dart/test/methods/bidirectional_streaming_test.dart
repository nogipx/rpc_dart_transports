import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Импортируем тестовый контракт
import '_contract.dart';

// Тестовые данные - простые числа вместо объектов
void main() {
  group('BidiStream тесты', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late TestRpcContract clientService;
    late TestRpcContract serverService;

    setUp(() {
      // Создаем пару транспортов для памяти
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');

      // Соединяем транспорты
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        debugLabel: 'CLIENT',
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        debugLabel: 'SERVER',
      );

      // Регистрируем сервисы
      serverService = ServerTestRpcService();
      serverEndpoint.registerServiceContract(serverService);

      // Создаем клиентский сервис
      clientService = ClientTestRpcService(clientEndpoint);

      // Добавляем очистку ресурсов
      addTearDown(() async {
        await clientEndpoint.close();
        await serverEndpoint.close();
      });
    });

    test('Базовый двунаправленный стриминг', () async {
      // Создаем контроллер для запросов
      final requestController = StreamController<TestRequest>();

      // Получаем двунаправленный стрим
      final bidiStream = clientService.bidirectionalStreamOperation(
        requestController.stream,
      );

      // Список для сбора ответов
      final receivedResponses = <TestStreamResponse>[];

      // Подписываемся на ответы
      bidiStream.listen(
        receivedResponses.add,
        onDone: () {
          print('Стрим ответов завершен');
        },
      );

      // Отправляем первый запрос через контроллер
      requestController.add(TestRequest(count: 2, requestId: 'запрос-1'));

      // Ждем немного, чтобы получить ответы на первый запрос
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем, что получили ответы на первый запрос
      expect(receivedResponses.length, equals(2));
      expect(receivedResponses[0].value, equals(5)); // 1 * 1 * 5
      expect(receivedResponses[1].value, equals(10)); // 2 * 1 * 5

      // Отправляем второй запрос через BidiStream
      bidiStream.send(TestRequest(count: 3, requestId: 'запрос-2'));

      // Ждем немного, чтобы получить ответы на второй запрос
      await Future.delayed(Duration(milliseconds: 70));

      // Проверяем, что получили все ответы (2 от первого запроса + 3 от второго)
      expect(receivedResponses.length, equals(5));
      expect(receivedResponses[2].value,
          equals(5)); // 1 * 2 * 5 (второй запрос, счетчик = 2)
      expect(receivedResponses[3].value, equals(10)); // 2 * 2 * 5
      expect(receivedResponses[4].value, equals(15)); // 3 * 2 * 5

      // Закрываем стрим
      await bidiStream.close();
      await requestController.close();
    });

    test('Использование BidiStreamGenerator для создания стрима', () async {
      // Создаем BidiStream напрямую с генератором
      final bidiStream = BidiStreamGenerator<TestRequest, TestStreamResponse>(
          (requests) async* {
        int count = 0;

        await for (final request in requests) {
          count++;
          yield TestStreamResponse(
            value: request.count * count,
            info: 'Ответ на запрос: ${request.requestId}',
          );
        }
      }).create(null); // Начинаем без начальных запросов

      // Список для сбора ответов
      final responses = <TestStreamResponse>[];

      // Подписываемся на ответы
      bidiStream.listen(responses.add);

      // Отправляем запросы
      bidiStream.send(TestRequest(count: 10, requestId: 'запрос-1'));
      bidiStream.send(TestRequest(count: 20, requestId: 'запрос-2'));

      // Ждем немного
      await Future.delayed(Duration(milliseconds: 50));

      // Проверяем ответы
      expect(responses.length, equals(2));
      expect(responses[0].value, equals(10)); // 10 * 1
      expect(responses[1].value, equals(40)); // 20 * 2

      // Закрываем стрим
      await bidiStream.close();
    });
  });
}
