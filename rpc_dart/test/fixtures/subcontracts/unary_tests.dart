// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../test_contract.dart';

/// Сообщения для унарных тестов
class UnaryRequest extends TestMessage {
  UnaryRequest(super.data);

  factory UnaryRequest.fromJson(Map<String, dynamic> json) {
    return UnaryRequest(json['data'] as String? ?? '');
  }
}

class UnaryResponse extends TestMessage {
  UnaryResponse(super.data);

  factory UnaryResponse.fromJson(Map<String, dynamic> json) {
    return UnaryResponse(json['data'] as String? ?? '');
  }
}

/// Контракт для тестирования унарных методов
abstract class UnaryTestsSubcontract extends OldRpcServiceContract {
  // Константы для имен методов
  static const methodSimpleUnary = 'simpleUnary';
  static const methodEchoUnary = 'echoUnary';
  static const methodDelayedUnary = 'delayedUnary';
  static const methodErrorUnary = 'errorUnary';

  UnaryTestsSubcontract() : super('unary_tests');

  @override
  void setup() {
    addUnaryRequestMethod<UnaryRequest, UnaryResponse>(
      methodName: methodSimpleUnary,
      handler: simpleUnary,
      argumentParser: UnaryRequest.fromJson,
      responseParser: UnaryResponse.fromJson,
    );

    addUnaryRequestMethod<UnaryRequest, UnaryResponse>(
      methodName: methodEchoUnary,
      handler: echoUnary,
      argumentParser: UnaryRequest.fromJson,
      responseParser: UnaryResponse.fromJson,
    );

    addUnaryRequestMethod<UnaryRequest, UnaryResponse>(
      methodName: methodDelayedUnary,
      handler: delayedUnary,
      argumentParser: UnaryRequest.fromJson,
      responseParser: UnaryResponse.fromJson,
    );

    addUnaryRequestMethod<UnaryRequest, UnaryResponse>(
      methodName: methodErrorUnary,
      handler: errorUnary,
      argumentParser: UnaryRequest.fromJson,
      responseParser: UnaryResponse.fromJson,
    );

    super.setup();
  }

  /// Метод возвращает ответ с префиксом
  Future<UnaryResponse> simpleUnary(UnaryRequest request);

  /// Метод просто возвращает тот же текст, что был в запросе
  Future<UnaryResponse> echoUnary(UnaryRequest request);

  /// Метод с искусственной задержкой
  Future<UnaryResponse> delayedUnary(UnaryRequest request);

  /// Метод, бросающий исключение
  Future<UnaryResponse> errorUnary(UnaryRequest request);
}

/// Серверная реализация контракта унарных тестов
class UnaryTestsServer extends UnaryTestsSubcontract {
  @override
  Future<UnaryResponse> simpleUnary(UnaryRequest request) async {
    return UnaryResponse('unary:${request.data}');
  }

  @override
  Future<UnaryResponse> echoUnary(UnaryRequest request) async {
    return UnaryResponse(request.data);
  }

  @override
  Future<UnaryResponse> delayedUnary(UnaryRequest request) async {
    final delayMs = int.tryParse(request.data) ?? 500;
    await Future.delayed(Duration(milliseconds: delayMs));
    return UnaryResponse('delayed:${request.data}');
  }

  @override
  Future<UnaryResponse> errorUnary(UnaryRequest request) async {
    throw Exception('Искусственная ошибка: ${request.data}');
  }
}

/// Клиентская реализация контракта унарных тестов
class UnaryTestsClient extends UnaryTestsSubcontract {
  final RpcEndpoint _endpoint;

  UnaryTestsClient(this._endpoint);

  @override
  Future<UnaryResponse> simpleUnary(UnaryRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: UnaryTestsSubcontract.methodSimpleUnary,
        )
        .call(
          request: request,
          responseParser: UnaryResponse.fromJson,
        );
  }

  @override
  Future<UnaryResponse> echoUnary(UnaryRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: UnaryTestsSubcontract.methodEchoUnary,
        )
        .call(
          request: request,
          responseParser: UnaryResponse.fromJson,
        );
  }

  @override
  Future<UnaryResponse> delayedUnary(UnaryRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: UnaryTestsSubcontract.methodDelayedUnary,
        )
        .call(
          request: request,
          responseParser: UnaryResponse.fromJson,
        );
  }

  @override
  Future<UnaryResponse> errorUnary(UnaryRequest request) {
    return _endpoint
        .unaryRequest(
          serviceName: serviceName,
          methodName: UnaryTestsSubcontract.methodErrorUnary,
        )
        .call(
          request: request,
          responseParser: UnaryResponse.fromJson,
        );
  }
}
