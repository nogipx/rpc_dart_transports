import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Нетипизированные эндпоинты', () {
    // Создаем реальные компоненты для тестов
    late MemoryTransport clientTransport;
    late MemoryTransport serverTransport;
    late JsonSerializer serializer;
    late RpcEndpoint clientEndpoint;
    late RpcEndpoint serverEndpoint;

    setUp(() {
      // Arrange - подготовка
      clientTransport = MemoryTransport('client');
      serverTransport = MemoryTransport('server');

      // Соединяем транспорты
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем сериализатор
      serializer = JsonSerializer();

      // Создаем эндпоинты
      clientEndpoint = RpcEndpoint(clientTransport, serializer);
      serverEndpoint = RpcEndpoint(serverTransport, serializer);
    });

    tearDown(() async {
      // Освобождение ресурсов
      await clientEndpoint.close();
      await serverEndpoint.close();
    });

    test('унарный_метод_корректно_вычисляет_и_возвращает_результат', () async {
      // Arrange - подготовка
      final methodName = 'add';
      final serviceName = 'CalculatorService';

      // Регистрируем метод на сервере
      serverEndpoint.registerMethod(
        serviceName,
        methodName,
        (context) async {
          final payload = context.payload as Map<String, dynamic>;
          final a = payload['a'] as int;
          final b = payload['b'] as int;
          return {'result': a + b};
        },
      );

      // Act - действие
      final response = await clientEndpoint.invoke(
        serviceName,
        methodName,
        {'a': 5, 'b': 3},
      );

      // Assert - проверка
      expect(response['result'], equals(8));
    });

    test('стриминговый_метод_корректно_возвращает_поток_значений', () async {
      // Arrange - подготовка
      final methodName = 'generateNumbers';
      final serviceName = 'StreamService';
      final expectedValues = [1, 2, 3, 4, 5];
      final actualValues = <int>[];

      // Регистрируем метод на сервере
      serverEndpoint.registerMethod(
        serviceName,
        methodName,
        (context) async {
          final payload = context.payload as Map<String, dynamic>;
          final count = payload['count'] as int;

          // Получаем ID сообщения из контекста для потока
          final messageId = context.messageId;

          // Запускаем генерацию чисел в отдельном потоке
          Future.microtask(() async {
            for (var i = 1; i <= count; i++) {
              // Отправляем данные в поток
              await serverEndpoint.sendStreamData(messageId, i);
              await Future.delayed(Duration(milliseconds: 10));
            }

            // Сигнализируем о завершении потока
            await serverEndpoint.closeStream(messageId);
          });

          // Возвращаем подтверждение активации стрима
          return {'status': 'streaming'};
        },
      );

      // Act - действие
      final stream = clientEndpoint.openStream(
        serviceName,
        methodName,
        request: {'count': 5},
      );

      // Assert - проверка
      await for (var value in stream) {
        actualValues.add(value as int);
      }

      expect(actualValues, equals(expectedValues));
    });

    test('вызов_с_невалидными_параметрами_вызывает_ошибку_на_сервере',
        () async {
      // Arrange - подготовка
      final methodName = 'divide';
      final serviceName = 'CalculatorService';

      // Регистрируем метод на сервере
      serverEndpoint.registerMethod(
        serviceName,
        methodName,
        (context) async {
          final payload = context.payload as Map<String, dynamic>;
          final a = payload['a'] as int;
          final b = payload['b'] as int;

          if (b == 0) {
            throw ArgumentError('Деление на ноль');
          }

          return {'result': a ~/ b};
        },
      );

      // Act & Assert - действие и проверка
      expect(
        () => clientEndpoint.invoke(
          serviceName,
          methodName,
          {'a': 10, 'b': 0},
        ),
        throwsA(anything),
      );
    });

    test('вызов_несуществующего_метода_вызывает_исключение', () async {
      // Act & Assert - действие и проверка
      expect(
        () => clientEndpoint.invoke(
          'NonexistentService',
          'nonexistentMethod',
          {'data': 123},
        ),
        throwsA(anything),
      );
    });

    test('метод_возвращает_переданные_metadata_обратно', () async {
      // Arrange - подготовка
      final methodName = 'echoMetadata';
      final serviceName = 'MetadataService';
      final metadata = {
        'userId': 'user123',
        'timestamp': 1637236582,
        'version': '1.0',
      };

      // Регистрируем метод на сервере
      serverEndpoint.registerMethod(
        serviceName,
        methodName,
        (context) async {
          // Возвращаем те же метаданные
          return context.metadata;
        },
      );

      // Act - действие
      final response = await clientEndpoint.invoke(
        serviceName,
        methodName,
        {'dummy': 'data'},
        metadata: metadata,
      );

      // Assert - проверка
      expect(response['userId'], equals(metadata['userId']));
      expect(response['timestamp'], equals(metadata['timestamp']));
      expect(response['version'], equals(metadata['version']));
    });
  });
}
