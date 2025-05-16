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
  RpcMethodImplementation.serverStreaming(
    this.contract,
    RpcMethodServerStreamHandler<Request, Response> handler,
  )   : type = RpcMethodType.serverStreaming,
        _unaryHandler = null,
        _serverStreamHandler = handler,
        _clientStreamHandler = null,
        _bidirectionalHandler = null;

  /// Создает реализацию клиентского стрима
  RpcMethodImplementation.clientStreaming(
    this.contract,
    RpcMethodClientStreamHandler<Request, Response> handler,
  )   : type = RpcMethodType.clientStreaming,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = handler,
        _bidirectionalHandler = null;

  /// Создает реализацию двунаправленного стрима
  RpcMethodImplementation.bidirectionalStreaming(
    this.contract,
    RpcMethodBidirectionalHandler<Request, Response> handler,
  )   : type = RpcMethodType.bidirectional,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = null,
        _bidirectionalHandler = handler;

  /// Вызывает метод с указанным запросом
  Future<Response> makeUnaryRequest(Request request) async {
    if (type != RpcMethodType.unary) {
      throw _unsupportedOperationException('makeUnaryRequest');
    }
    if (_unaryHandler == null) {
      throw _missingHandlerException('makeUnaryRequest');
    }

    return await _unaryHandler!(request);
  }

  /// Открывает стрим ответов для указанного запроса
  ServerStreamingBidiStream<Request, Response> openServerStreaming(
    Request request,
  ) {
    if (type != RpcMethodType.serverStreaming) {
      throw _unsupportedOperationException('openServerStreaming');
    }
    if (_serverStreamHandler == null) {
      throw _missingHandlerException('openServerStreaming');
    }

    try {
      return _serverStreamHandler!(request);
    } catch (e) {
      // В случае ошибки при получении стрима создаем пустой стрим с ошибкой
      final errorStream = BidiStreamGenerator<Request, Response>((_) async* {
        throw RpcCustomException(
          customMessage: 'Ошибка при открытии стрима: $e',
          debugLabel: 'RpcMethodImplementation.openStream',
        );
      }).createServerStreaming(initialRequest: request);

      return errorStream;
    }
  }

  /// Обрабатывает поток запросов и возвращает один ответ
  ///
  /// [stream] - поток входящих запросов
  /// [metadata] - метаданные запроса
  /// [streamId] - идентификатор потока
  Future<Response> openClientStreaming({
    required Stream<Request> stream,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) async {
    if (type != RpcMethodType.clientStreaming) {
      throw _unsupportedOperationException('openClientStreaming');
    }
    if (_clientStreamHandler == null) {
      throw _missingHandlerException('openClientStreaming');
    }

    // Получаем ClientStreamingBidiStream от обработчика
    final clientStreamBidi = _clientStreamHandler!();

    // Подписываемся на поток запросов и перенаправляем их в BidiStream
    stream.listen(
      (request) => clientStreamBidi.send(request),
      onDone: () => clientStreamBidi.close(),
      onError: (error) => clientStreamBidi.close(),
    );

    // Возвращаем результат
    return await clientStreamBidi.getResponse();
  }

  /// Обрабатывает двунаправленный стрим с предоставленным входящим потоком запросов
  ///
  /// [incomingStream] - поток входящих запросов от клиента
  BidiStream<Request, Response> openBidirectionalStreaming(
    Stream<Request> incomingStream,
  ) {
    if (type != RpcMethodType.bidirectional) {
      throw _unsupportedOperationException('openBidirectionalStreaming');
    }
    if (_bidirectionalHandler == null) {
      throw _missingHandlerException('openBidirectionalStreaming');
    }

    try {
      // Создаем поток и получаем его от обработчика
      final bidiStream = _bidirectionalHandler!();

      // Создаем BidiStreamGenerator для связи входящего потока с обработчиком
      final generator = BidiStreamGenerator<Request, Response>((requestStream) {
        // Создаем контроллер для выходного потока
        final outputController = StreamController<Response>();

        // Перенаправляем ответы из потока обработчика в выходной контроллер
        bidiStream.listen(
          (response) {
            RpcLog.debug(
              message: 'Обработчик отправил ответ: ${response.runtimeType}',
              source: 'RpcMethodImplementation',
            );
            outputController.add(response);
          },
          onError: (error, stackTrace) {
            RpcLog.error(
              message: 'Ошибка в потоке обработчика',
              source: 'RpcMethodImplementation',
              error: {'error': error.toString()},
              stackTrace: stackTrace.toString(),
            );
            outputController.addError(error, stackTrace);
          },
          onDone: () {
            RpcLog.debug(
              message: 'Поток обработчика завершен',
              source: 'RpcMethodImplementation',
            );
            outputController.close();
          },
        );

        // Подписываемся на входящий поток запросов и передаем запросы в bidiStream
        requestStream.listen(
          (request) {
            RpcLog.debug(
              message:
                  'Получен запрос, отправляем в обработчик: ${request.runtimeType}',
              source: 'RpcMethodImplementation',
            );
            // Отправляем запрос в исходный bidiStream
            try {
              // Безопасно отправляем запрос в BidiStream
              final typedBidiStream = bidiStream;
              typedBidiStream.send(request);
            } catch (e, stackTrace) {
              RpcLog.error(
                message: 'Ошибка при отправке запроса в обработчик',
                source: 'RpcMethodImplementation',
                error: {'error': e.toString()},
                stackTrace: stackTrace.toString(),
              );
              outputController.addError(e, stackTrace);
            }
          },
          onError: (error, stackTrace) {
            RpcLog.error(
              message: 'Ошибка во входящем потоке запросов',
              source: 'RpcMethodImplementation',
              error: {'error': error.toString()},
              stackTrace: stackTrace.toString(),
            );
            outputController.addError(error, stackTrace);
          },
          onDone: () {
            // При закрытии входящего потока закрываем bidiStream
            RpcLog.debug(
              message: 'Входящий поток запросов завершен, закрываем обработчик',
              source: 'RpcMethodImplementation',
            );

            try {
              // Аналогично, используем приведение типов
              final typedBidiStream = bidiStream;
              typedBidiStream.close();
            } catch (e) {
              RpcLog.error(
                message: 'Ошибка при закрытии потока обработчика: $e',
                source: 'RpcMethodImplementation',
              );
              // Не закрываем outputController здесь, т.к. он закроется при завершении потока bidiStream
            }
          },
        );

        return outputController.stream;
      });

      // Создаем BidiStream с входящим потоком запросов
      return generator.create(incomingStream);
    } catch (e) {
      RpcLog.error(
        message: 'Ошибка при обработке двунаправленного потока: $e',
        source: 'RpcMethodImplementation',
      );
      // В случае ошибки создаем поток с ошибкой
      final errorGenerator =
          BidiStreamGenerator<Request, Response>((requestStream) async* {
        yield* Stream.error(RpcCustomException(
          customMessage: 'Ошибка при создании двунаправленного потока: $e',
          debugLabel: 'RpcMethodImplementation.handleBidirectionalStream',
        ));
      });

      return errorGenerator.create(incomingStream);
    }
  }

  RpcUnsupportedOperationException _unsupportedOperationException(
    String operation,
  ) {
    return RpcUnsupportedOperationException(
      operation: operation,
      type: type.name,
      details: {
        'contract': contract,
        'message': 'Method type $type does not support $operation',
      },
    );
  }

  RpcUnsupportedOperationException _missingHandlerException(
    String operation,
  ) {
    return RpcUnsupportedOperationException(
      operation: operation,
      type: type.name,
      details: {
        'contract': contract,
        'message': 'Method type $type has no $operation handler',
      },
    );
  }
}
