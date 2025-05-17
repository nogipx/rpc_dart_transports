// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../test_contract.dart';

/// Сообщения для клиентского стриминга
class ClientStreamRequest extends TestMessage {
  ClientStreamRequest(super.data);

  factory ClientStreamRequest.fromJson(Map<String, dynamic> json) {
    return ClientStreamRequest(json['data'] as String? ?? '');
  }
}

class ClientStreamResponse extends TestMessage {
  ClientStreamResponse(super.data);

  factory ClientStreamResponse.fromJson(Map<String, dynamic> json) {
    return ClientStreamResponse(json['data'] as String? ?? '');
  }
}

/// Контракт для тестирования клиентского стриминга
abstract class ClientStreamingTestsSubcontract extends RpcServiceContract {
  // Константы для имен методов
  static const methodCollectData = 'collectData';
  static const methodCountItems = 'countItems';
  static const methodErrorStream = 'errorStream';

  ClientStreamingTestsSubcontract() : super('client_streaming_tests');

  @override
  void setup() {
    addClientStreamingMethod<ClientStreamRequest, ClientStreamResponse>(
      methodName: methodCollectData,
      handler: collectData,
      argumentParser: ClientStreamRequest.fromJson,
      responseParser: ClientStreamResponse.fromJson,
    );

    addClientStreamingMethod<ClientStreamRequest, ClientStreamResponse>(
      methodName: methodCountItems,
      handler: countItems,
      argumentParser: ClientStreamRequest.fromJson,
      responseParser: ClientStreamResponse.fromJson,
    );

    addClientStreamingMethod<ClientStreamRequest, ClientStreamResponse>(
      methodName: methodErrorStream,
      handler: errorStream,
      argumentParser: ClientStreamRequest.fromJson,
      responseParser: ClientStreamResponse.fromJson,
    );

    super.setup();
  }

  /// Собирает все полученные сообщения в строку через запятую
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      collectData();

  /// Подсчитывает количество полученных элементов
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      countItems();

  /// Генерирует ошибку при получении определенного сообщения
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      errorStream();
}

/// Серверная реализация контракта клиентского стриминга
class ClientStreamingTestsServer extends ClientStreamingTestsSubcontract {
  @override
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      collectData() {
    // Создаем контроллеры для запросов и ответов
    final requestController = StreamController<ClientStreamRequest>();
    final responseController = StreamController<ClientStreamResponse>();

    // Собираем все сообщения
    final collected = <String>[];

    // Обрабатываем запросы
    requestController.stream.listen(
      (request) {
        collected.add(request.data);
      },
      onDone: () {
        // Формируем ответ
        responseController.add(ClientStreamResponse(collected.join(', ')));
        responseController.close();
      },
      onError: (error) {
        responseController.addError(error);
        responseController.close();
      },
    );

    // Создаем BidiStream
    final bidiStream = BidiStream<ClientStreamRequest, ClientStreamResponse>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      closeFunction: () async {
        await requestController.close();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );

    // Оборачиваем в ClientStreamingBidiStream и возвращаем
    return ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>(
      bidiStream,
    );
  }

  @override
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      countItems() {
    // Создаем контроллеры для запросов и ответов
    final requestController = StreamController<ClientStreamRequest>();
    final responseController = StreamController<ClientStreamResponse>();

    var count = 0;

    // Подсчитываем количество элементов
    requestController.stream.listen(
      (request) {
        count++;
      },
      onDone: () {
        // Отправляем ответ с количеством
        responseController.add(ClientStreamResponse('count:$count'));
        responseController.close();
      },
      onError: (error) {
        responseController.addError(error);
        responseController.close();
      },
    );

    // Создаем BidiStream
    final bidiStream = BidiStream<ClientStreamRequest, ClientStreamResponse>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      closeFunction: () async {
        await requestController.close();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );

    // Оборачиваем в ClientStreamingBidiStream и возвращаем
    return ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>(
      bidiStream,
    );
  }

  @override
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      errorStream() {
    // Создаем контроллеры для запросов и ответов
    final requestController = StreamController<ClientStreamRequest>();
    final responseController = StreamController<ClientStreamResponse>();

    // Слушаем запросы
    requestController.stream.listen(
      (request) {
        // Если получили 'error', бросаем исключение
        if (request.data.toLowerCase() == 'error') {
          responseController.addError(
            Exception('Ошибка при обработке стрима'),
          );
          responseController.close();
        }
      },
      onDone: () {
        // Отправляем успешный ответ, если не было ошибок
        if (!responseController.isClosed) {
          responseController.add(ClientStreamResponse('success'));
          responseController.close();
        }
      },
      onError: (error) {
        if (!responseController.isClosed) {
          responseController.addError(error);
          responseController.close();
        }
      },
    );

    // Создаем BidiStream
    final bidiStream = BidiStream<ClientStreamRequest, ClientStreamResponse>(
      responseStream: responseController.stream,
      sendFunction: (request) => requestController.add(request),
      closeFunction: () async {
        await requestController.close();
        if (!responseController.isClosed) {
          await responseController.close();
        }
      },
    );

    // Оборачиваем в ClientStreamingBidiStream и возвращаем
    return ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>(
      bidiStream,
    );
  }
}

/// Клиентская реализация контракта клиентского стриминга
class ClientStreamingTestsClient extends ClientStreamingTestsSubcontract {
  final RpcEndpoint _endpoint;

  ClientStreamingTestsClient(this._endpoint);

  @override
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      collectData() {
    return _endpoint
        .clientStreaming(
          serviceName: serviceName,
          methodName: ClientStreamingTestsSubcontract.methodCollectData,
        )
        .call<ClientStreamRequest, ClientStreamResponse>(
          responseParser: ClientStreamResponse.fromJson,
        );
  }

  @override
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      countItems() {
    return _endpoint
        .clientStreaming(
          serviceName: serviceName,
          methodName: ClientStreamingTestsSubcontract.methodCountItems,
        )
        .call<ClientStreamRequest, ClientStreamResponse>(
          responseParser: ClientStreamResponse.fromJson,
        );
  }

  @override
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      errorStream() {
    return _endpoint
        .clientStreaming(
          serviceName: serviceName,
          methodName: ClientStreamingTestsSubcontract.methodErrorStream,
        )
        .call<ClientStreamRequest, ClientStreamResponse>(
          responseParser: ClientStreamResponse.fromJson,
        );
  }
}
