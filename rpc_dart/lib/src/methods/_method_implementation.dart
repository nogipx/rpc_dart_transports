// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс, представляющий реализацию RPC метода
final class RpcMethodImplementation<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  /// Контракт метода
  final RpcMethodContract<Request, Response> contract;

  /// Тип метода
  final RpcMethodType type;

  /// Обработчик унарного метода
  final RpcMethodUnaryHandler<Request, Response>? _unaryHandler;

  /// Обработчик серверного стрима
  final RpcMethodServerStreamHandler<Request, Response>? _serverStreamHandler;

  /// Обработчик клиентского стрима
  final RpcMethodClientStreamHandler<Request, Response>? _clientStreamHandler;

  /// Обработчик двунаправленного стрима
  final RpcMethodBidirectionalHandler<Request, Response>? _bidirectionalHandler;

  /// Создает реализацию унарного метода
  RpcMethodImplementation.unary(
    this.contract,
    RpcMethodUnaryHandler<Request, Response> handler,
  )   : type = RpcMethodType.unary,
        _unaryHandler = handler,
        _serverStreamHandler = null,
        _clientStreamHandler = null,
        _bidirectionalHandler = null;

  /// Создает реализацию серверного стрима
  RpcMethodImplementation.serverStream(
    this.contract,
    RpcMethodServerStreamHandler<Request, Response> handler,
  )   : type = RpcMethodType.serverStreaming,
        _unaryHandler = null,
        _serverStreamHandler = handler,
        _clientStreamHandler = null,
        _bidirectionalHandler = null;

  /// Создает реализацию клиентского стрима
  RpcMethodImplementation.clientStream(
    this.contract,
    RpcMethodClientStreamHandler<Request, Response> handler,
  )   : type = RpcMethodType.clientStreaming,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = handler,
        _bidirectionalHandler = null;

  /// Создает реализацию двунаправленного стрима
  RpcMethodImplementation.bidirectional(
    this.contract,
    RpcMethodBidirectionalHandler<Request, Response> handler,
  )   : type = RpcMethodType.bidirectional,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = null,
        _bidirectionalHandler = handler;

  /// Вызывает метод с указанным запросом
  Future<Response> invoke(Request request) async {
    if (type == RpcMethodType.unary && _unaryHandler != null) {
      return await _unaryHandler!(request);
    }

    throw RpcUnsupportedOperationException(
      operation: 'invoke',
      type: type.name,
      details: {
        'contract': contract,
        'message': 'Method type $type does not support unary invocation',
      },
    );
  }

  /// Открывает стрим ответов для указанного запроса
  Stream<Response> openStream(Request request) {
    if (type == RpcMethodType.serverStreaming && _serverStreamHandler != null) {
      return _serverStreamHandler!(request);
    }

    throw RpcUnsupportedOperationException(
      operation: 'openStream',
      type: type.name,
      details: {
        'contract': contract,
        'message': 'Method type $type does not support server streaming',
      },
    );
  }

  /// Обрабатывает поток запросов и возвращает один ответ
  Future<Response> handleClientStream(
    RpcClientStreamParams<Request, Response> params,
  ) async {
    if (type == RpcMethodType.clientStreaming && _clientStreamHandler != null) {
      final response = await _clientStreamHandler!(params);
      if (response.response != null) {
        return response.response!;
      }

      throw RpcInternalException(
        'Failed to get response from client',
        details: {
          'type': type,
          'contract': contract,
        },
      );
    }

    throw RpcUnsupportedOperationException(
      operation: 'handleClientStream',
      type: type.name,
      details: {
        'contract': contract,
        'message': 'Method type $type does not support client streaming',
      },
    );
  }

  /// Открывает двунаправленный стрим
  Stream<Response> openBidirectionalStream(
    Stream<Request> requestsStream,
    String messageId,
  ) {
    if (type == RpcMethodType.bidirectional && _bidirectionalHandler != null) {
      return _bidirectionalHandler!(requestsStream, messageId);
    }

    throw RpcUnsupportedOperationException(
      operation: 'openBidirectionalStream',
      type: type.name,
      details: {
        'contract': contract,
        'message': 'Method type $type does not support bidirectional streaming',
      },
    );
  }
}
