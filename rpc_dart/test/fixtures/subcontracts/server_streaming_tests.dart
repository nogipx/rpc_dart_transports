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
abstract class ServerStreamingTestsSubcontract extends OldRpcServiceContract {
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
  final _logger = RpcLogger('ServerStreamingTests');

  @override
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      generateItems(ServerStreamRequest request) {
    _logger.info('Вызван метод generateItems с запросом: ${request.data}');

    // Используем генератор для создания стрима
    return BidiStreamGenerator<ServerStreamRequest, ServerStreamResponse>(
        (requestStream) async* {
      try {
        // Получаем количество элементов из запроса
        final count = int.tryParse(request.data) ?? 5;
        _logger.debug('generateItems: генерируем $count элементов');

        // Генерируем элементы
        for (var i = 0; i < count; i++) {
          _logger.debug('generateItems: отправляем элемент item-$i');
          yield ServerStreamResponse('item-$i');
          await Future.delayed(Duration(milliseconds: 50));
        }
      } catch (e) {
        _logger.error('Ошибка в generateItems: $e');
        rethrow;
      }
    }).createServerStreaming(initialRequest: request);
  }

  @override
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      echoStream(ServerStreamRequest request) {
    _logger.info('Вызван метод echoStream с запросом: ${request.data}');

    // Используем генератор для создания стрима
    return BidiStreamGenerator<ServerStreamRequest, ServerStreamResponse>(
        (requestStream) async* {
      // Просто возвращаем эхо-ответ
      _logger.debug('echoStream: отправляем эхо ${request.data}');
      yield ServerStreamResponse(request.data);
    }).createServerStreaming(initialRequest: request);
  }

  @override
  ServerStreamingBidiStream<ServerStreamRequest, ServerStreamResponse>
      errorStream(ServerStreamRequest request) {
    _logger.info('Вызван метод errorStream с запросом: ${request.data}');

    // Используем генератор для создания стрима
    return BidiStreamGenerator<ServerStreamRequest, ServerStreamResponse>(
        (requestStream) async* {
      // Если запрос содержит "error", бросаем исключение
      if (request.data.toLowerCase() == 'error') {
        _logger.debug('errorStream: генерируем ошибку');
        throw Exception('Запрошена ошибка');
      } else {
        // Иначе отправляем пару сообщений и затем ошибку
        _logger.debug('errorStream: отправляем первое сообщение');
        yield ServerStreamResponse('message 1');

        _logger.debug('errorStream: отправляем второе сообщение');
        yield ServerStreamResponse('message 2');

        _logger.debug('errorStream: генерируем запланированную ошибку');
        throw Exception('Запланированная ошибка стрима');
      }
    }).createServerStreaming(initialRequest: request);
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
