// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../test_contract.dart';

/// Сообщения для серверного стриминга
class ServerStreamRequest extends TestMessage {
  ServerStreamRequest(super.data);

  factory ServerStreamRequest.fromJson(Map<String, dynamic> json) {
    return ServerStreamRequest(json['data'] as String? ?? '');
  }
}

class ServerStreamResponse extends TestMessage {
  ServerStreamResponse(super.data);

  factory ServerStreamResponse.fromJson(Map<String, dynamic> json) {
    return ServerStreamResponse(json['data'] as String? ?? '');
  }
}

/// Контракт для тестирования серверного стриминга
abstract class ServerStreamingTestsSubcontract extends RpcServiceContract {
  // Константы для имен методов
  static const methodGenerateItems = 'generateItems';
  static const methodEchoStream = 'echoStream';
  static const methodErrorStream = 'errorStream';

  ServerStreamingTestsSubcontract() : super('server_streaming_tests');

  @override
  void setup() {
    addServerStreamingMethod<ServerStreamRequest, ServerStreamResponse>(
      methodName: methodGenerateItems,
      handler: generateItems,
      argumentParser: ServerStreamRequest.fromJson,
      responseParser: ServerStreamResponse.fromJson,
    );

    addServerStreamingMethod<ServerStreamRequest, ServerStreamResponse>(
      methodName: methodEchoStream,
      handler: echoStream,
      argumentParser: ServerStreamRequest.fromJson,
      responseParser: ServerStreamResponse.fromJson,
    );

    addServerStreamingMethod<ServerStreamRequest, ServerStreamResponse>(
      methodName: methodErrorStream,
      handler: errorStream,
      argumentParser: ServerStreamRequest.fromJson,
      responseParser: ServerStreamResponse.fromJson,
    );

    super.setup();
  }

  /// Генерирует указанное число элементов
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      generateItems(ServerStreamRequest request);

  /// Просто возвращает одно сообщение с тем же содержимым
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      echoStream(ServerStreamRequest request);

  /// Генерирует ошибку, если получен определенный запрос
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      errorStream(ServerStreamRequest request);
}

/// Серверная реализация контракта серверного стриминга
class ServerStreamingTestsServer extends ServerStreamingTestsSubcontract {
  @override
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      generateItems(ServerStreamRequest request) {
    // Создаем контроллеры для запросов и ответов
    final requestController = StreamController<ServerStreamRequest>();
    final responseController = StreamController<ServerStreamResponse>();

    // Обрабатываем запрос
    requestController.stream.listen((req) async {
      try {
        final count = int.tryParse(req.data) ?? 5;

        // Генерируем указанное количество элементов
        for (var i = 0; i < count; i++) {
          if (!responseController.isClosed) {
            responseController.add(ServerStreamResponse('item-$i'));
            await Future.delayed(Duration(milliseconds: 50));
          }
        }
      } finally {
        // Закрываем контроллер ответов
        if (!responseController.isClosed) {
          await responseController.close();
        }
      }
    });

    // Создаем BidiStream
    final bidiStream = BidiStream<ServerStreamRequest, ServerStreamResponse>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      closeFunction: () async {
        await requestController.close();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );

    // Оборачиваем в ServerStreamingBidiStream и возвращаем
    return ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );
  }

  @override
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      echoStream(ServerStreamRequest request) {
    // Создаем контроллеры для запросов и ответов
    final requestController = StreamController<ServerStreamRequest>();
    final responseController = StreamController<ServerStreamResponse>();

    // Обрабатываем запрос
    requestController.stream.listen((req) {
      // Просто эхо для одного сообщения
      responseController.add(ServerStreamResponse(req.data));
      responseController.close();
    });

    // Создаем BidiStream
    final bidiStream = BidiStream<ServerStreamRequest, ServerStreamResponse>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      closeFunction: () async {
        await requestController.close();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );

    // Оборачиваем в ServerStreamingBidiStream и возвращаем
    return ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );
  }

  @override
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      errorStream(ServerStreamRequest request) {
    // Создаем контроллеры для запросов и ответов
    final requestController = StreamController<ServerStreamRequest>();
    final responseController = StreamController<ServerStreamResponse>();

    // Обрабатываем запрос
    requestController.stream.listen((req) {
      // Если получили 'error', бросаем исключение
      if (req.data.toLowerCase() == 'error') {
        responseController.addError(Exception('Запрошена ошибка'));
        responseController.close();
      } else {
        // Отправляем несколько сообщений, а затем ошибку
        responseController.add(ServerStreamResponse('message 1'));
        responseController.add(ServerStreamResponse('message 2'));
        responseController.addError(Exception('Запланированная ошибка стрима'));
        responseController.close();
      }
    });

    // Создаем BidiStream
    final bidiStream = BidiStream<ServerStreamRequest, ServerStreamResponse>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      closeFunction: () async {
        await requestController.close();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );

    // Оборачиваем в ServerStreamingBidiStream и возвращаем
    return ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );
  }
}

/// Клиентская реализация контракта серверного стриминга
class ServerStreamingTestsClient extends ServerStreamingTestsSubcontract {
  final RpcEndpoint _endpoint;

  ServerStreamingTestsClient(this._endpoint);

  @override
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      generateItems(ServerStreamRequest request) {
    return _endpoint
        .serverStreaming(
          serviceName: serviceName,
          methodName: ServerStreamingTestsSubcontract.methodGenerateItems,
        )
        .call(
          request: request,
          responseParser: ServerStreamResponse.fromJson,
        );
  }

  @override
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      echoStream(ServerStreamRequest request) {
    return _endpoint
        .serverStreaming(
          serviceName: serviceName,
          methodName: ServerStreamingTestsSubcontract.methodEchoStream,
        )
        .call(
          request: request,
          responseParser: ServerStreamResponse.fromJson,
        );
  }

  @override
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      errorStream(ServerStreamRequest request) {
    return _endpoint
        .serverStreaming(
          serviceName: serviceName,
          methodName: ServerStreamingTestsSubcontract.methodErrorStream,
        )
        .call(
          request: request,
          responseParser: ServerStreamResponse.fromJson,
        );
  }
}
