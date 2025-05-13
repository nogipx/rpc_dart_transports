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
  ServerStreamingBidiStream<Request, Response> openStream(Request request) {
    if (type == RpcMethodType.serverStreaming && _serverStreamHandler != null) {
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
  ///
  /// [stream] - поток входящих запросов
  /// [metadata] - метаданные запроса
  /// [streamId] - идентификатор потока
  Future<Response> handleClientStream({
    required Stream<Request> stream,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) async {
    if (type == RpcMethodType.clientStreaming && _clientStreamHandler != null) {
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
  Stream<Response> openBidirectionalStream() {
    if (type == RpcMethodType.bidirectional && _bidirectionalHandler != null) {
      return _bidirectionalHandler!();
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

  /// Обрабатывает двунаправленный стрим с предоставленным входящим потоком запросов
  ///
  /// [incomingStream] - поток входящих запросов от клиента
  BidiStream<Request, Response> handleBidirectionalStream(
      Stream<Request> incomingStream) {
    if (type == RpcMethodType.bidirectional && _bidirectionalHandler != null) {
      try {
        // Создаем поток и получаем его от обработчика
        final bidiStream = _bidirectionalHandler!();

        // Создаем BidiStreamGenerator для связи входящего потока с обработчиком
        final generator =
            BidiStreamGenerator<Request, Response>((requestStream) {
          // Создаем контроллер для выходного потока
          final outputController = StreamController<Response>();

          // Перенаправляем ответы из потока обработчика в выходной контроллер
          bidiStream.listen(
            (response) {
              rpcMethodLogger
                  .debug('Обработчик отправил ответ: ${response.runtimeType}');
              outputController.add(response);
            },
            onError: (error, stackTrace) {
              rpcMethodLogger.error(
                  'Ошибка в потоке обработчика', error, stackTrace);
              outputController.addError(error, stackTrace);
            },
            onDone: () {
              rpcMethodLogger.debug('Поток обработчика завершен');
              outputController.close();
            },
          );

          // Подписываемся на входящий поток запросов и передаем запросы в bidiStream
          requestStream.listen(
            (request) {
              rpcMethodLogger.debug(
                  'Получен запрос, отправляем в обработчик: ${request.runtimeType}');
              // Отправляем запрос в исходный bidiStream
              try {
                // Безопасно отправляем запрос в BidiStream
                final typedBidiStream = bidiStream;
                typedBidiStream.send(request);
              } catch (e, stackTrace) {
                rpcMethodLogger.error(
                    'Ошибка при отправке запроса в обработчик', e, stackTrace);
                outputController.addError(e, stackTrace);
              }
            },
            onError: (error, stackTrace) {
              rpcMethodLogger.error(
                  'Ошибка во входящем потоке запросов', error, stackTrace);
              outputController.addError(error, stackTrace);
            },
            onDone: () {
              // При закрытии входящего потока закрываем bidiStream
              rpcMethodLogger.debug(
                  'Входящий поток запросов завершен, закрываем обработчик');

              try {
                // Аналогично, используем приведение типов
                final typedBidiStream = bidiStream;
                typedBidiStream.close();
              } catch (e) {
                print('Ошибка при закрытии потока обработчика: $e');
                // Не закрываем outputController здесь, т.к. он закроется при завершении потока bidiStream
              }
            },
          );

          return outputController.stream;
        });

        // Создаем BidiStream с входящим потоком запросов
        return generator.create(incomingStream);
      } catch (e) {
        print('Ошибка при обработке двунаправленного потока: $e');
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

    throw RpcUnsupportedOperationException(
      operation: 'handleBidirectionalStream',
      type: type.name,
      details: {
        'contract': contract,
        'message': 'Method type $type does not support bidirectional streaming',
      },
    );
  }
}
