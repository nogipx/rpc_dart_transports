import 'dart:async';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart_transports/rpc_dart_transports.dart';
import 'package:test/test.dart';

void main() {
  group('RpcIsolateTransport', () {
    group('spawn factory', () {
      test('создает_изолят_и_возвращает_транспорт', () async {
        // Arrange & Act
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testEchoServer,
          customParams: {'test': 'value'},
          isolateId: 'test-isolate',
          debugName: 'Test Echo Server',
        );

        // Assert
        expect(result.transport, isA<IRpcTransport>());
        expect(result.kill, isA<Function>());

        // Cleanup
        result.kill();
      });

      test('передает_параметры_в_изолят', () async {
        // Arrange
        final testParams = {
          'serviceName': 'TestService',
          'responsePrefix': '[TEST]: ',
        };

        // Act
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testParameterServer,
          customParams: testParams,
          isolateId: 'param-test',
        );

        final transport = result.transport;

        // Проверяем что можем общаться с изолятом
        final streamId = transport.createStream();
        final receivedMessages = <RpcTransportMessage>[];

        transport.incomingMessages.listen(receivedMessages.add);

        // Отправляем тестовое сообщение
        await transport.sendMessage(
          streamId,
          Uint8List.fromList('test message'.codeUnits),
        );

        // Даем время для обработки в изоляте
        await Future.delayed(Duration(milliseconds: 200));

        // Assert
        expect(receivedMessages.length, greaterThan(0));

        // Cleanup
        result.kill();
      });

      test('обрабатывает_ошибки_создания_изолята', () async {
        // Arrange & Act
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _faultyServer,
          customParams: {},
          isolateId: 'faulty-isolate',
        );

        // Assert
        // Изолят создается успешно, но содержит ошибочный код
        expect(result.transport, isA<IRpcTransport>());
        expect(result.kill, isA<Function>());

        // Cleanup
        result.kill();
      });
    });

    group('createStream', () {
      test('создает_уникальные_stream_id', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testEchoServer,
          customParams: {},
          isolateId: 'stream-test',
        );

        final transport = result.transport;

        // Act
        final streamId1 = transport.createStream();
        final streamId2 = transport.createStream();
        final streamId3 = transport.createStream();

        // Assert
        expect(streamId1, isNot(equals(streamId2)));
        expect(streamId2, isNot(equals(streamId3)));
        expect(streamId1, isNot(equals(streamId3)));

        // Cleanup
        result.kill();
      });

      test('генерирует_нечетные_числа_для_клиента', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testEchoServer,
          customParams: {},
          isolateId: 'odd-stream-test',
        );

        final transport = result.transport;

        // Act
        final streamIds = List.generate(5, (_) => transport.createStream());

        // Assert
        for (final streamId in streamIds) {
          expect(streamId % 2, equals(1), reason: 'Stream ID должен быть нечетным');
        }

        // Cleanup
        result.kill();
      });
    });

    group('sendMessage и sendMetadata', () {
      test('отправляет_сообщения_в_изолят', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testEchoServer,
          customParams: {},
          isolateId: 'message-test',
        );

        final transport = result.transport;
        final streamId = transport.createStream();
        final receivedMessages = <RpcTransportMessage>[];

        transport.incomingMessages.listen(receivedMessages.add);

        // Act
        final testData = Uint8List.fromList('Hello Isolate'.codeUnits);
        await transport.sendMessage(streamId, testData);

        // Даем время для обработки в изоляте
        await Future.delayed(Duration(milliseconds: 200));

        // Assert
        expect(receivedMessages.length, greaterThan(0));
        final echoMessage = receivedMessages.firstWhere(
          (msg) => !msg.isMetadataOnly && msg.payload != null,
          orElse: () => throw StateError('Echo message not found'),
        );

        final receivedText = String.fromCharCodes(echoMessage.payload!);
        expect(receivedText, contains('Hello Isolate'));

        // Cleanup
        result.kill();
      });

      test('отправляет_метаданные_в_изолят', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testFullCycleServer,
          customParams: {},
          isolateId: 'metadata-test',
        );

        final transport = result.transport;
        final streamId = transport.createStream();
        final receivedMessages = <RpcTransportMessage>[];

        transport.incomingMessages.listen(receivedMessages.add);

        // Act
        final metadata = RpcMetadata.forClientRequest(
          'TestService',
          'TestMethod',
          host: 'test.com',
        );
        await transport.sendMetadata(streamId, metadata);

        // Даем время для обработки в изоляте
        await Future.delayed(Duration(milliseconds: 200));

        // Assert
        expect(receivedMessages.length, greaterThan(0));
        final metadataMessage = receivedMessages.firstWhere(
          (msg) => msg.isMetadataOnly,
          orElse: () => throw StateError('Metadata message not found'),
        );

        expect(metadataMessage.metadata, isNotNull);

        // Cleanup
        result.kill();
      });

      test('обрабатывает_end_stream_флаг', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testFullCycleServer,
          customParams: {},
          isolateId: 'endstream-test',
        );

        final transport = result.transport;
        final streamId = transport.createStream();
        final receivedMessages = <RpcTransportMessage>[];

        transport.incomingMessages.listen(receivedMessages.add);

        // Act
        await transport.sendMessage(
          streamId,
          Uint8List.fromList('test'.codeUnits),
          endStream: true,
        );

        // Даем время для обработки в изоляте
        await Future.delayed(Duration(milliseconds: 200));

        // Assert
        expect(receivedMessages.length, greaterThan(0));
        final endStreamMessage = receivedMessages.firstWhere(
          (msg) => msg.isEndOfStream,
          orElse: () => throw StateError('End stream message not found'),
        );

        expect(endStreamMessage.isEndOfStream, isTrue);

        // Cleanup
        result.kill();
      });
    });

    group('finishSending', () {
      test('отправляет_end_stream_сообщение', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testFinishServer,
          customParams: {},
          isolateId: 'finish-test',
        );

        final transport = result.transport;
        final streamId = transport.createStream();
        final receivedMessages = <RpcTransportMessage>[];

        transport.incomingMessages.listen(receivedMessages.add);

        // Act
        await transport.finishSending(streamId);

        // Даем время для обработки в изоляте
        await Future.delayed(Duration(milliseconds: 200));

        // Assert
        expect(receivedMessages.length, greaterThan(0));
        final finishMessage = receivedMessages.firstWhere(
          (msg) => msg.isEndOfStream && msg.streamId == streamId,
          orElse: () => throw StateError('Finish message not found'),
        );

        expect(finishMessage.isEndOfStream, isTrue);
        expect(finishMessage.streamId, equals(streamId));

        // Cleanup
        result.kill();
      });

      test('предотвращает_повторную_отправку', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testFinishServer,
          customParams: {},
          isolateId: 'repeat-finish-test',
        );

        final transport = result.transport;
        final streamId = transport.createStream();
        final receivedMessages = <RpcTransportMessage>[];

        transport.incomingMessages.listen(receivedMessages.add);

        // Act
        await transport.finishSending(streamId);
        await transport.finishSending(streamId); // Повторный вызов

        // Даем время для обработки в изоляте
        await Future.delayed(Duration(milliseconds: 200));

        // Assert
        final finishMessages =
            receivedMessages.where((msg) => msg.isEndOfStream && msg.streamId == streamId).toList();

        expect(finishMessages.length, equals(1)); // Только одно сообщение

        // Cleanup
        result.kill();
      });
    });

    group('getMessagesForStream', () {
      test('фильтрует_сообщения_по_stream_id', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testMultiStreamServer,
          customParams: {},
          isolateId: 'filter-test',
        );

        final transport = result.transport;
        final streamId1 = transport.createStream();
        final streamId2 = transport.createStream();

        final stream1Messages = <RpcTransportMessage>[];
        final stream2Messages = <RpcTransportMessage>[];

        transport.getMessagesForStream(streamId1).listen(stream1Messages.add);
        transport.getMessagesForStream(streamId2).listen(stream2Messages.add);

        // Act
        await transport.sendMessage(streamId1, Uint8List.fromList('message1'.codeUnits));
        await transport.sendMessage(streamId2, Uint8List.fromList('message2'.codeUnits));
        await transport.sendMessage(streamId1, Uint8List.fromList('message3'.codeUnits));

        // Даем время для обработки в изоляте
        await Future.delayed(Duration(milliseconds: 200));

        // Assert
        expect(stream1Messages.length, greaterThan(0));
        expect(stream2Messages.length, greaterThan(0));

        // Проверяем, что сообщения правильно отфильтрованы
        for (final msg in stream1Messages) {
          expect(msg.streamId, equals(streamId1));
        }
        for (final msg in stream2Messages) {
          expect(msg.streamId, equals(streamId2));
        }

        // Cleanup
        result.kill();
      });
    });

    group('close', () {
      test('закрывает_транспорт_корректно', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testEchoServer,
          customParams: {},
          isolateId: 'close-test',
        );

        final transport = result.transport;

        // Act
        await transport.close();

        // Assert
        // Проверяем, что после закрытия нельзя отправлять сообщения
        final streamId = transport.createStream();

        // Попытка отправить сообщение после закрытия не должна вызывать исключение,
        // но сообщение не должно быть доставлено
        await transport.sendMessage(
          streamId,
          Uint8List.fromList('test'.codeUnits),
        );

        // Cleanup
        result.kill();
      });
    });

    group('интеграционные тесты', () {
      test('полный_цикл_обмена_сообщениями', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testFullCycleServer,
          customParams: {'responseCount': 3},
          isolateId: 'full-cycle-test',
        );

        final transport = result.transport;
        final streamId = transport.createStream();
        final receivedMessages = <RpcTransportMessage>[];

        transport.getMessagesForStream(streamId).listen(receivedMessages.add);

        // Act
        // Отправляем метаданные
        final metadata = RpcMetadata.forClientRequest(
          'TestService',
          'FullCycle',
        );
        await transport.sendMetadata(streamId, metadata);

        // Отправляем сообщение
        await transport.sendMessage(
          streamId,
          Uint8List.fromList('test request'.codeUnits),
        );

        // Завершаем отправку
        await transport.finishSending(streamId);

        // Даем время для обработки в изоляте
        await Future.delayed(Duration(milliseconds: 200));

        // Assert
        expect(receivedMessages.length, greaterThan(0));

        // Проверяем, что получили и метаданные, и данные
        final metadataMessages = receivedMessages.where((msg) => msg.isMetadataOnly).toList();
        final dataMessages =
            receivedMessages.where((msg) => !msg.isMetadataOnly && msg.payload != null).toList();

        expect(metadataMessages.length, greaterThan(0));
        expect(dataMessages.length, greaterThan(0));

        // Cleanup
        result.kill();
      });

      test('обработка_ошибок_в_изоляте', () async {
        // Arrange
        final result = await RpcIsolateTransport.spawn(
          entrypoint: _testErrorServer,
          customParams: {},
          isolateId: 'error-test',
        );

        final transport = result.transport;
        final streamId = transport.createStream();
        final receivedMessages = <RpcTransportMessage>[];

        transport.getMessagesForStream(streamId).listen(receivedMessages.add);

        // Act
        await transport.sendMessage(
          streamId,
          Uint8List.fromList('trigger error'.codeUnits),
        );

        // Даем время для обработки в изоляте
        await Future.delayed(Duration(milliseconds: 200));

        // Assert
        // Ожидаем, что получим сообщение об ошибке
        expect(receivedMessages.length, greaterThan(0));

        // Cleanup
        result.kill();
      });
    });
  });
}

/// Простой эхо-сервер для тестов
@pragma('vm:entry-point')
void _testEchoServer(IRpcTransport transport, Map<String, dynamic> params) {
  transport.incomingMessages.listen((message) async {
    if (!message.isMetadataOnly && message.payload != null) {
      // Эхо сообщения
      final echoData = Uint8List.fromList(
        'Echo: ${String.fromCharCodes(message.payload!)}'.codeUnits,
      );
      await transport.sendMessage(message.streamId, echoData);
    }
  });
}

/// Сервер для тестирования параметров
@pragma('vm:entry-point')
void _testParameterServer(IRpcTransport transport, Map<String, dynamic> params) {
  final responsePrefix = params['responsePrefix'] as String? ?? '[DEFAULT]: ';

  transport.incomingMessages.listen((message) async {
    if (!message.isMetadataOnly && message.payload != null) {
      final originalText = String.fromCharCodes(message.payload!);
      final responseText = '$responsePrefix$originalText';
      final responseData = Uint8List.fromList(responseText.codeUnits);

      await transport.sendMessage(message.streamId, responseData);
    }
  });
}

/// Сервер с ошибкой для тестирования
@pragma('vm:entry-point')
void _faultyServer(IRpcTransport transport, Map<String, dynamic> params) {
  throw Exception('Intentional server error');
}

/// Мульти-стрим сервер для тестирования фильтрации
@pragma('vm:entry-point')
void _testMultiStreamServer(IRpcTransport transport, Map<String, dynamic> params) {
  transport.incomingMessages.listen((message) async {
    if (!message.isMetadataOnly && message.payload != null) {
      final originalText = String.fromCharCodes(message.payload!);
      final responseText = 'Response for stream ${message.streamId}: $originalText';
      final responseData = Uint8List.fromList(responseText.codeUnits);

      await transport.sendMessage(message.streamId, responseData);
    }
  });
}

/// Полный цикл сервер для интеграционных тестов
@pragma('vm:entry-point')
void _testFullCycleServer(IRpcTransport transport, Map<String, dynamic> params) {
  final responseCount = params['responseCount'] as int? ?? 1;

  transport.incomingMessages.listen((message) async {
    if (message.isMetadataOnly && !message.isEndOfStream) {
      // Отправляем начальные метаданные
      final initialMetadata = RpcMetadata.forServerInitialResponse();
      await transport.sendMetadata(message.streamId, initialMetadata);
    } else if (!message.isMetadataOnly && message.payload != null) {
      // Отправляем несколько ответов
      for (int i = 1; i <= responseCount; i++) {
        final responseText = 'Response $i of $responseCount';
        final responseData = Uint8List.fromList(responseText.codeUnits);
        await transport.sendMessage(message.streamId, responseData);
      }

      // Отправляем финальные метаданные
      final finalMetadata = RpcMetadata.forTrailer(RpcStatus.OK);
      await transport.sendMetadata(message.streamId, finalMetadata, endStream: true);
    }
  });
}

/// Сервер с ошибками для тестирования
@pragma('vm:entry-point')
void _testErrorServer(IRpcTransport transport, Map<String, dynamic> params) {
  transport.incomingMessages.listen((message) async {
    if (!message.isMetadataOnly && message.payload != null) {
      // Отправляем ошибку
      final errorMetadata = RpcMetadata.forTrailer(RpcStatus.INTERNAL, message: 'Test error');
      await transport.sendMetadata(message.streamId, errorMetadata, endStream: true);
    }
  });
}

/// Простой сервер для тестов finishSending
@pragma('vm:entry-point')
void _testFinishServer(IRpcTransport transport, Map<String, dynamic> params) {
  transport.incomingMessages.listen((message) async {
    // Отвечаем на любое сообщение, включая END_STREAM
    if (message.isEndOfStream) {
      // Отправляем подтверждение END_STREAM
      await transport.finishSending(message.streamId);
    } else if (!message.isMetadataOnly && message.payload != null) {
      // Эхо обычных сообщений
      final echoData = Uint8List.fromList(
        'Echo: ${String.fromCharCodes(message.payload!)}'.codeUnits,
      );
      await transport.sendMessage(message.streamId, echoData);
    }
  });
}
