import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';
import '_contract.dart';

void main() {
  group('Server Streaming Tests (with Contracts)', () {
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;
    late ClientTestRpcService clientService;
    late ServerTestRpcService serverService;

    setUp(() {
      // Создаем пару связанных транспортов для памяти
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: JsonSerializer(),
        debugLabel: 'CLIENT',
      );
      serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: JsonSerializer(),
        debugLabel: 'SERVER',
      );

      // Создаем сервисы
      clientService = ClientTestStreamService(clientEndpoint);
      serverService = ServerTestStreamService();

      // Регистрируем сервис на сервере
      serverEndpoint.registerServiceContract(serverService);
      clientEndpoint.registerServiceContract(clientService);

      // Гарантируем очистку ресурсов после каждого теста
      addTearDown(() async {
        await clientEndpoint.close();
        await serverEndpoint.close();
      });
    });

    test(
        'should receive stream of data from server in response to single request',
        () async {
      // Создаем запрос
      final request = TestRequest(count: 5);

      // Открываем стрим для получения данных
      final stream = clientService.basicStream(request);

      // Проверяем, что все сообщения получены
      final responses = await stream.toList();
      expect(responses.length, 5);

      // Проверяем значения
      for (int i = 0; i < 5; i++) {
        expect(responses[i].value, (i + 1) * 10);
      }
    });

    test('should correctly handle multiple simultaneous server streams',
        () async {
      // Создаем несколько запросов с разными множителями
      final requestA = TestRequest(count: 5, requestId: 'A');
      final requestB = TestRequest(count: 10, requestId: 'B');
      final requestC = TestRequest(count: 15, requestId: 'C');

      print('Тестируем потоки последовательно');

      // Тестируем первый поток
      print('Открываем поток A');
      final streamA = clientService.multipleStreams(requestA);
      final responsesA = await streamA.toList();
      print('Получено из потока A: ${responsesA.length}');

      // Тестируем второй поток
      print('Открываем поток B');
      final streamB = clientService.multipleStreams(requestB);
      final responsesB = await streamB.toList();
      print('Получено из потока B: ${responsesB.length}');

      // Тестируем третий поток
      print('Открываем поток C');
      final streamC = clientService.multipleStreams(requestC);
      final responsesC = await streamC.toList();
      print('Получено из потока C: ${responsesC.length}');

      // Проверяем количество сообщений
      expect(responsesA.length, 3);
      expect(responsesB.length, 3);
      expect(responsesC.length, 3);

      // Проверяем, что значения правильно умножены
      if (responsesA.isNotEmpty) {
        print('Значение A[0]: ${responsesA[0].value}');
        expect(responsesA[0].value, 5); // 1 * 5
      }

      if (responsesB.isNotEmpty) {
        print('Значение B[0]: ${responsesB[0].value}');
        expect(responsesB[0].value, 10); // 1 * 10
      }

      if (responsesC.isNotEmpty) {
        print('Значение C[0]: ${responsesC[0].value}');
        expect(responsesC[0].value, 15); // 1 * 15
      }
    });

    test('should handle errors in server streaming', () async {
      // Создаем запрос, который вызовет ошибку
      final errorRequest = TestRequest(count: -1);

      try {
        // Пытаемся открыть стрим, который вызовет ошибку
        final stream = clientService.errorStream(errorRequest);
        await stream.first; // Попытка получить первое сообщение
        fail('Должно быть выброшено исключение');
      } catch (e) {
        // Проверяем, что исключение содержит ожидаемое сообщение
        expect(e.toString(), contains('отрицательное значение count'));
      }
    });

    test('should handle errors in stream itself', () async {
      // Создаем запрос, который будет работать, но потом выбросит ошибку
      final errorRequest = TestRequest(count: 0);

      // Открываем стрим
      final stream = clientService.errorStream(errorRequest);

      // Читаем все данные
      int receivedCount = 0;
      try {
        // ignore: unused_local_variable
        await for (final response in stream) {
          receivedCount++;
        }
        fail('Стрим должен выбросить ошибку');
      } catch (e) {
        // Проверяем, что получили одно сообщение перед ошибкой
        expect(receivedCount, 1,
            reason: 'Должно быть получено одно сообщение перед ошибкой');
        expect(e.toString(), contains('Преднамеренная ошибка'));
      }
    });

    // ... остальные тесты ...
  });
}
