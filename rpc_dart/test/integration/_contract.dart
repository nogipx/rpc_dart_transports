import 'dart:async';

import 'package:rpc_dart/rpc_dart.dart';

// Универсальный контракт для тестирования всех типов методов
abstract base class TestRpcContract extends RpcServiceContract {
  TestRpcContract() : super('TestRpcService');

  // Имена методов
  static const String unaryMethod = 'unaryMethod';
  static const String clientStreamMethod = 'clientStreamMethod';
  static const String serverStreamMethod = 'serverStreamMethod';
  static const String bidirectionalMethod = 'bidirectionalMethod';

  @override
  void setup() {
    // Унарный метод
    addUnaryRequestMethod<TestRequest, TestResponse>(
      methodName: unaryMethod,
      handler: unaryRequestOperation,
      argumentParser: TestRequest.fromJson,
      responseParser: TestResponse.fromJson,
    );

    // Серверный стриминг
    addServerStreamingMethod<TestRequest, TestStreamResponse>(
      methodName: serverStreamMethod,
      handler: serverStreamOperation,
      argumentParser: TestRequest.fromJson,
      responseParser: TestStreamResponse.fromJson,
    );

    // Клиентский стриминг
    addClientStreamingMethod<TestRequest, TestResponse>(
      methodName: clientStreamMethod,
      handler: clientStreamOperation,
      argumentParser: TestRequest.fromJson,
      responseParser: TestResponse.fromJson,
    );

    // Двунаправленный стриминг
    addBidirectionalStreamingMethod<TestRequest, TestStreamResponse>(
      methodName: bidirectionalMethod,
      handler: bidirectionalStreamOperation,
      argumentParser: TestRequest.fromJson,
      responseParser: TestStreamResponse.fromJson,
    );
    super.setup();
  }

  // Абстрактные методы для реализации
  Future<TestResponse> unaryRequestOperation(TestRequest request);

  ClientStreamingBidiStream<TestRequest, TestResponse> clientStreamOperation();

  ServerStreamingBidiStream<TestRequest, TestStreamResponse>
      serverStreamOperation(TestRequest request);

  // Изменяем тип возвращаемого значения на BidiStream
  BidiStream<TestRequest, TestStreamResponse> bidirectionalStreamOperation();
}

// Серверная реализация
final class ServerTestRpcService extends TestRpcContract {
  @override
  Future<TestResponse> unaryRequestOperation(TestRequest request) async {
    await Future.delayed(Duration(milliseconds: 20));
    return TestResponse(
      result: request.count * 10,
      info: 'Унарный ответ: ${request.requestId}',
    );
  }

  @override
  ClientStreamingBidiStream<TestRequest, TestResponse> clientStreamOperation() {
    final bidiStream =
        BidiStreamGenerator<TestRequest, TestResponse>((requestStream) async* {
      List<String> ids = [];

      // Получаем поток запросов
      await for (final request in requestStream) {
        if (request.requestId.isNotEmpty) {
          ids.add(request.requestId);
        }
        await Future.delayed(Duration(milliseconds: 10));
      }

      yield TestResponse(
        result: ids.length * 10,
        info: 'Клиентский стрим: ${ids.join(', ')}',
      );
    }).create();

    return ClientStreamingBidiStream<TestRequest, TestResponse>(bidiStream);
  }

  @override
  ServerStreamingBidiStream<TestRequest, TestStreamResponse>
      serverStreamOperation(TestRequest request) {
    final bidiStream =
        BidiStreamGenerator<TestRequest, TestStreamResponse>((requests) async* {
      for (int i = 1; i <= request.count; i++) {
        yield TestStreamResponse(
          value: i * 10,
          info: 'Серверный стрим: ${request.requestId}',
        );
        await Future.delayed(Duration(milliseconds: 10));
      }
    }).create();

    final serverStreamBidi =
        ServerStreamingBidiStream<TestRequest, TestStreamResponse>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );
    serverStreamBidi.sendRequest(request);
    return serverStreamBidi;
  }

  @override
  BidiStream<TestRequest, TestStreamResponse> bidirectionalStreamOperation() =>
      BidiStreamGenerator<TestRequest, TestStreamResponse>(
          (incomingRequests) async* {
        int requestCount = 0;

        await for (final request in incomingRequests) {
          requestCount++;

          for (int i = 1; i <= request.count; i++) {
            yield TestStreamResponse(
              value: i * requestCount * 5,
              info: 'Bidi стрим, запрос #$requestCount: ${request.requestId}',
            );
            await Future.delayed(Duration(milliseconds: 10));
          }
        }
      }).create();
}

// Клиентская реализация
final class ClientTestRpcService extends TestRpcContract {
  final RpcEndpoint _endpoint;

  ClientTestRpcService(this._endpoint);

  @override
  Future<TestResponse> unaryRequestOperation(TestRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: TestRpcContract.unaryMethod,
        )
        .call<TestRequest, TestResponse>(
          request: request,
          responseParser: TestResponse.fromJson,
        );
  }

  @override
  ServerStreamingBidiStream<TestRequest, TestStreamResponse>
      serverStreamOperation(
    TestRequest request,
  ) {
    return _endpoint
        .serverStreaming(
          serviceName: serviceName,
          methodName: TestRpcContract.serverStreamMethod,
        )
        .call<TestRequest, TestStreamResponse>(
          request: request,
          responseParser: TestStreamResponse.fromJson,
        );
  }

  @override
  ClientStreamingBidiStream<TestRequest, TestResponse> clientStreamOperation() {
    return _endpoint
        .clientStreaming(
          serviceName: serviceName,
          methodName: TestRpcContract.clientStreamMethod,
        )
        .call<TestRequest, TestResponse>(
          responseParser: TestResponse.fromJson,
        );
  }

  @override
  BidiStream<TestRequest, TestStreamResponse> bidirectionalStreamOperation() {
    return _endpoint
        .bidirectionalStreaming(
          serviceName: serviceName,
          methodName: TestRpcContract.bidirectionalMethod,
        )
        .call<TestRequest, TestStreamResponse>(
          responseParser: TestStreamResponse.fromJson,
        );
  }
}

// ------- MODELS -------

// Модели данных для тестов
class TestRequest implements IRpcSerializableMessage {
  final int count;
  final String requestId;

  TestRequest({required this.count, this.requestId = ''});

  factory TestRequest.fromJson(Map<String, dynamic> json) {
    return TestRequest(
      count: json['count'] as int? ?? 5,
      requestId: json['requestId'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'requestId': requestId,
    };
  }
}

class TestResponse implements IRpcSerializableMessage {
  final int result;
  final String info;

  TestResponse({required this.result, this.info = ''});

  factory TestResponse.fromJson(Map<String, dynamic> json) {
    return TestResponse(
      result: json['result'] as int,
      info: json['info'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'result': result,
      'info': info,
    };
  }
}

class TestStreamResponse implements IRpcSerializableMessage {
  final int value;
  final String info;

  TestStreamResponse({required this.value, this.info = ''});

  factory TestStreamResponse.fromJson(Map<String, dynamic> json) {
    return TestStreamResponse(
      value: json['value'] as int,
      info: json['info'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'info': info,
    };
  }
}

// Результат выполнения серверного стриминга
class ServerStreamResult<T> {
  final Stream<T> stream;
  final Map<String, dynamic> response;

  ServerStreamResult({required this.stream, required this.response});
}
