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
abstract class ClientStreamingTestsSubcontract extends OldRpcServiceContract {
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
  final _logger = RpcLogger('ClientStreamingTests');

  @override
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      collectData() {
    _logger.info('Вызван метод collectData');

    return BidiStreamGenerator<ClientStreamRequest, ClientStreamResponse>(
        (requestStream) async* {
      // Собираем все данные из потока
      final collected = <String>[];

      await for (final request in requestStream) {
        _logger.debug('collectData: получен запрос ${request.data}');
        collected.add(request.data);
      }

      // После получения всех запросов возвращаем ответ
      final result = collected.join(', ');
      _logger.debug('collectData: отправляем ответ $result');
      yield ClientStreamResponse(result);
    }).createClientStreaming();
  }

  @override
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      countItems() {
    _logger.info('Вызван метод countItems');

    return BidiStreamGenerator<ClientStreamRequest, ClientStreamResponse>(
        (requestStream) async* {
      var count = 0;

      await for (final request in requestStream) {
        _logger.debug('countItems: получен запрос ${request.data}');
        count++;
      }

      // Отправляем ответ с количеством элементов
      _logger.debug('countItems: отправляем ответ count:$count');
      yield ClientStreamResponse('count:$count');
    }).createClientStreaming();
  }

  @override
  ClientStreamingBidiStream<ClientStreamRequest, ClientStreamResponse>
      errorStream() {
    _logger.info('Вызван метод errorStream');

    return BidiStreamGenerator<ClientStreamRequest, ClientStreamResponse>(
        (requestStream) async* {
      await for (final request in requestStream) {
        _logger.debug('errorStream: получен запрос ${request.data}');

        // Если получили 'error', генерируем ошибку
        if (request.data.toLowerCase() == 'error') {
          _logger.debug('errorStream: генерируем ошибку');
          throw Exception('Ошибка при обработке стрима');
        }
      }

      // Если не было ошибок, отправляем успешный ответ
      _logger.debug('errorStream: отправляем успешный ответ');
      yield ClientStreamResponse('success');
    }).createClientStreaming();
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
