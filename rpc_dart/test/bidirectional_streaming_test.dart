import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

// Тестовые данные - простые числа вместо объектов
void main() {
  group('Bidirectional Streaming Tests', () {
    test('should successfully exchange messages in both directions', () async {
      // Настраиваем транспорты
      final clientTransport = MemoryTransport('client');
      final serverTransport = MemoryTransport('server');
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем эндпоинты
      final serializer = JsonSerializer();
      final clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: serializer,
      );
      final serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: serializer,
      );

      // Регистрируем обработчик для стрима на сервере
      serverEndpoint.registerMethod(
          serviceName: 'TestService',
          methodName: 'bidirectionalStream',
          handler: (context) async {
            // Получаем ID сообщения
            final messageId = context.messageId;

            // Слушаем входящие сообщения и отправляем ответы
            serverEndpoint
                .openStream(
              serviceName: 'TestService',
              methodName: 'bidirectionalStream',
              streamId: messageId,
            )
                .listen((data) {
              // Проверяем на маркер конца
              if (data is Map<String, dynamic> &&
                  data['_clientStreamEnd'] == true) {
                return;
              }

              // Отправляем ответное сообщение (число умноженное на 10)
              if (data is int) {
                serverEndpoint.sendStreamData(
                  streamId: messageId,
                  data: data * 10,
                  serviceName: 'TestService',
                  methodName: 'bidirectionalStream',
                );
              }
            });

            // Возвращаем статус для начала двунаправленного стрима
            return {'status': 'bidirectional_streaming_started'};
          });

      // Регистрируем такой же метод на клиенте, чтобы можно было открыть стрим
      clientEndpoint.registerMethod(
        serviceName: 'TestService',
        methodName: 'bidirectionalStream',
        handler: (context) async {
          return {'status': 'bidirectional_streaming_started'};
        },
      );

      // Создаем поток для входящих сообщений от сервера
      final receivedMessages = <int>[];
      final completer = Completer<void>();

      // Открываем двунаправленный стрим
      final clientStreamId =
          'test-stream-${DateTime.now().millisecondsSinceEpoch}';

      // Отправляем запрос на создание стрима
      await clientEndpoint.invoke(
        serviceName: 'TestService',
        methodName: 'bidirectionalStream',
        request: {},
        metadata: {'streamId': clientStreamId},
      );

      // Слушаем ответы от сервера
      clientEndpoint
          .openStream(
        serviceName: 'TestService',
        methodName: 'bidirectionalStream',
        streamId: clientStreamId,
      )
          .listen((data) {
        if (data is int) {
          receivedMessages.add(data);
          if (receivedMessages.length == 3) {
            completer.complete();
          }
        }
      });

      // Отправляем числа с небольшими паузами
      await Future.delayed(Duration(milliseconds: 50));
      clientEndpoint.sendStreamData(
        streamId: clientStreamId,
        data: 1,
        serviceName: 'TestService',
        methodName: 'bidirectionalStream',
      );

      await Future.delayed(Duration(milliseconds: 50));
      clientEndpoint.sendStreamData(
        streamId: clientStreamId,
        data: 2,
        serviceName: 'TestService',
        methodName: 'bidirectionalStream',
      );

      await Future.delayed(Duration(milliseconds: 50));
      clientEndpoint.sendStreamData(
        streamId: clientStreamId,
        data: 3,
        serviceName: 'TestService',
        methodName: 'bidirectionalStream',
      );

      // Ожидаем завершения
      await completer.future.timeout(Duration(seconds: 2),
          onTimeout: () => print('Таймаут ожидания ответов'));

      // Закрываем стрим
      clientEndpoint.sendStreamData(
        streamId: clientStreamId,
        data: {'_clientStreamEnd': true},
        serviceName: 'TestService',
        methodName: 'bidirectionalStream',
      );

      await Future.delayed(Duration(milliseconds: 100));

      // Закрываем ресурсы
      await clientEndpoint.close();
      await serverEndpoint.close();

      // Проверяем результаты
      expect(receivedMessages.length, equals(3));
      expect(receivedMessages[0], equals(10));
      expect(receivedMessages[1], equals(20));
      expect(receivedMessages[2], equals(30));
    });

    test('should handle errors in bidirectional streams', () async {
      // Настраиваем транспорты
      final clientTransport = MemoryTransport('client');
      final serverTransport = MemoryTransport('server');
      clientTransport.connect(serverTransport);
      serverTransport.connect(clientTransport);

      // Создаем эндпоинты
      final serializer = JsonSerializer();
      final clientEndpoint = RpcEndpoint(
        transport: clientTransport,
        serializer: serializer,
      );
      final serverEndpoint = RpcEndpoint(
        transport: serverTransport,
        serializer: serializer,
      );

      // Регистрируем обработчик на сервере, который будет выдавать ошибку для определенных значений
      serverEndpoint.registerMethod(
          serviceName: 'TestService',
          methodName: 'bidirectionalStreamWithError',
          handler: (context) async {
            // Получаем ID сообщения
            final messageId = context.messageId;

            // Слушаем входящие сообщения и отправляем ответы
            serverEndpoint
                .openStream(
              serviceName: 'TestService',
              methodName: 'bidirectionalStreamWithError',
              streamId: messageId,
            )
                .listen((data) {
              // Проверяем на маркер конца
              if (data is Map<String, dynamic> &&
                  data['_clientStreamEnd'] == true) {
                return;
              }

              // Генерируем ошибку для определенного значения
              if (data is int && data == 999) {
                serverEndpoint.sendStreamError(
                  streamId: messageId,
                  errorMessage: 'Тестовая ошибка для значения 999',
                );
              } else if (data is int) {
                // Обычный ответ для других значений
                serverEndpoint.sendStreamData(
                  streamId: messageId,
                  data: data * 10,
                  serviceName: 'TestService',
                  methodName: 'bidirectionalStreamWithError',
                );
              }
            });

            // Возвращаем статус для начала двунаправленного стрима
            return {'status': 'bidirectional_streaming_started'};
          });

      // Регистрируем такой же метод на клиенте, чтобы можно было открыть стрим
      clientEndpoint.registerMethod(
        serviceName: 'TestService',
        methodName: 'bidirectionalStreamWithError',
        handler: (context) async {
          return {'status': 'bidirectional_streaming_started'};
        },
      );

      // Переменные для теста
      var errorReceived = false;
      final completer = Completer<void>();

      // Открываем двунаправленный стрим
      final clientStreamId =
          'test-error-stream-${DateTime.now().millisecondsSinceEpoch}';

      // Отправляем запрос на создание стрима
      await clientEndpoint.invoke(
        serviceName: 'TestService',
        methodName: 'bidirectionalStreamWithError',
        request: {},
        metadata: {'streamId': clientStreamId},
      );

      // Слушаем ответы от сервера, ожидая ошибку
      clientEndpoint
          .openStream(
        serviceName: 'TestService',
        methodName: 'bidirectionalStreamWithError',
        streamId: clientStreamId,
      )
          .listen((data) {}, onError: (error) {
        errorReceived = true;
        completer.complete();
      });

      // Отправляем значение, которое вызовет ошибку
      await Future.delayed(Duration(milliseconds: 50));
      clientEndpoint.sendStreamData(
        streamId: clientStreamId,
        data: 999, // Это вызовет ошибку
        serviceName: 'TestService',
        methodName: 'bidirectionalStreamWithError',
      );

      // Ожидаем получения ошибки
      await completer.future.timeout(Duration(seconds: 2),
          onTimeout: () => print('Таймаут ожидания ошибки'));

      // Закрываем стрим
      clientEndpoint.sendStreamData(
        streamId: clientStreamId,
        data: {'_clientStreamEnd': true},
        serviceName: 'TestService',
        methodName: 'bidirectionalStreamWithError',
      );

      await Future.delayed(Duration(milliseconds: 100));

      // Закрываем ресурсы
      await clientEndpoint.close();
      await serverEndpoint.close();

      // Проверяем, что ошибка была получена
      expect(errorReceived, isTrue);
    });
  });
}
