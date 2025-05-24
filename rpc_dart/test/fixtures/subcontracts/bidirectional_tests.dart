// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../test_contract.dart';

/// Сообщения для двунаправленного стриминга
class BidirectionalRequest extends TestMessage {
  BidirectionalRequest(super.data);

  factory BidirectionalRequest.fromJson(Map<String, dynamic> json) {
    return BidirectionalRequest(json['data'] as String? ?? '');
  }
}

class BidirectionalResponse extends TestMessage {
  BidirectionalResponse(super.data);

  factory BidirectionalResponse.fromJson(Map<String, dynamic> json) {
    return BidirectionalResponse(json['data'] as String? ?? '');
  }
}

/// Контракт для тестирования двунаправленного стриминга
abstract class BidirectionalTestsSubcontract extends OldRpcServiceContract {
  // Константы для имен методов
  static const methodEchoStream = 'echoStream';
  static const methodTransformStream = 'transformStream';
  static const methodErrorStream = 'errorStream';

  BidirectionalTestsSubcontract() : super('bidirectional_tests');

  @override
  void setup() {
    addBidirectionalStreamingMethod<BidirectionalRequest,
        BidirectionalResponse>(
      methodName: methodEchoStream,
      handler: echoStream,
      argumentParser: BidirectionalRequest.fromJson,
      responseParser: BidirectionalResponse.fromJson,
    );

    addBidirectionalStreamingMethod<BidirectionalRequest,
        BidirectionalResponse>(
      methodName: methodTransformStream,
      handler: transformStream,
      argumentParser: BidirectionalRequest.fromJson,
      responseParser: BidirectionalResponse.fromJson,
    );

    addBidirectionalStreamingMethod<BidirectionalRequest,
        BidirectionalResponse>(
      methodName: methodErrorStream,
      handler: errorStream,
      argumentParser: BidirectionalRequest.fromJson,
      responseParser: BidirectionalResponse.fromJson,
    );

    super.setup();
  }

  /// Просто возвращает то же сообщение с эхо-префиксом
  BidiStream<BidirectionalRequest, BidirectionalResponse> echoStream();

  /// Трансформирует сообщение (например, в верхний регистр)
  BidiStream<BidirectionalRequest, BidirectionalResponse> transformStream();

  /// Генерирует ошибку при получении определенного сообщения
  BidiStream<BidirectionalRequest, BidirectionalResponse> errorStream();
}

/// Серверная реализация контракта двунаправленного стриминга
class BidirectionalTestsServer extends BidirectionalTestsSubcontract {
  @override
  BidiStream<BidirectionalRequest, BidirectionalResponse> echoStream() {
    // Создаем контроллеры для запросов и ответов
    final requestController = StreamController<BidirectionalRequest>();
    final responseController = StreamController<BidirectionalResponse>();

    // Обрабатываем запросы
    requestController.stream.listen(
      (request) {
        responseController.add(BidirectionalResponse('echo:${request.data}'));
      },
      onDone: () {
        responseController.close();
      },
      onError: (error) {
        responseController.addError(error);
        responseController.close();
      },
    );

    // Создаем и возвращаем BidiStream
    return BidiStream<BidirectionalRequest, BidirectionalResponse>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      closeFunction: () async {
        await requestController.close();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );
  }

  @override
  BidiStream<BidirectionalRequest, BidirectionalResponse> transformStream() {
    // Создаем контроллеры для запросов и ответов
    final requestController = StreamController<BidirectionalRequest>();
    final responseController = StreamController<BidirectionalResponse>();

    // Обрабатываем запросы - трансформируем в верхний регистр
    requestController.stream.listen(
      (request) {
        responseController
            .add(BidirectionalResponse(request.data.toUpperCase()));
      },
      onDone: () {
        responseController.close();
      },
      onError: (error) {
        responseController.addError(error);
        responseController.close();
      },
    );

    // Создаем и возвращаем BidiStream
    return BidiStream<BidirectionalRequest, BidirectionalResponse>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      closeFunction: () async {
        await requestController.close();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );
  }

  @override
  BidiStream<BidirectionalRequest, BidirectionalResponse> errorStream() {
    // Создаем контроллеры для запросов и ответов
    final requestController = StreamController<BidirectionalRequest>();
    final responseController = StreamController<BidirectionalResponse>();

    // Обрабатываем запросы - генерируем ошибку для определенных сообщений
    requestController.stream.listen(
      (request) {
        if (request.data.toLowerCase() == 'error') {
          responseController.addError(Exception('Запрошена ошибка в стриме'));
        } else {
          responseController
              .add(BidirectionalResponse('processed:${request.data}'));
        }
      },
      onDone: () {
        responseController.close();
      },
      onError: (error) {
        responseController.addError(error);
        responseController.close();
      },
    );

    // Создаем и возвращаем BidiStream
    return BidiStream<BidirectionalRequest, BidirectionalResponse>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      closeFunction: () async {
        await requestController.close();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );
  }
}

/// Клиентская реализация контракта двунаправленного стриминга
class BidirectionalTestsClient extends BidirectionalTestsSubcontract {
  final RpcEndpoint _endpoint;

  BidirectionalTestsClient(this._endpoint);

  @override
  BidiStream<BidirectionalRequest, BidirectionalResponse> echoStream() {
    return _endpoint
        .bidirectionalStreaming(
          serviceName: serviceName,
          methodName: BidirectionalTestsSubcontract.methodEchoStream,
        )
        .call<BidirectionalRequest, BidirectionalResponse>(
          responseParser: BidirectionalResponse.fromJson,
        );
  }

  @override
  BidiStream<BidirectionalRequest, BidirectionalResponse> transformStream() {
    return _endpoint
        .bidirectionalStreaming(
          serviceName: serviceName,
          methodName: BidirectionalTestsSubcontract.methodTransformStream,
        )
        .call<BidirectionalRequest, BidirectionalResponse>(
          responseParser: BidirectionalResponse.fromJson,
        );
  }

  @override
  BidiStream<BidirectionalRequest, BidirectionalResponse> errorStream() {
    return _endpoint
        .bidirectionalStreaming(
          serviceName: serviceName,
          methodName: BidirectionalTestsSubcontract.methodErrorStream,
        )
        .call<BidirectionalRequest, BidirectionalResponse>(
          responseParser: BidirectionalResponse.fromJson,
        );
  }
}
