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

  /// Логгер для этого инстанса
  final RpcLogger _logger;

  /// Обработчик унарного метода
  final RpcMethodUnaryHandler<Request, Response>? _unaryHandler;

  /// Обработчик серверного стрима
  final RpcMethodServerStreamHandler<Request, Response>? _serverStreamHandler;

  /// Обработчик клиентского стрима с ответом
  final RpcMethodClientStreamHandler<Request, Response>? _clientStreamHandler;

  /// Обработчик двунаправленного стрима
  final RpcMethodBidirectionalHandler<Request, Response>? _bidirectionalHandler;

  /// Completer для отслеживания инициализации обработчика клиентского стриминга
  final Completer<void> _handlerInitCompleter = Completer<void>();

  /// Создает реализацию унарного метода
  RpcMethodImplementation.unary(
    this.contract,
    RpcMethodUnaryHandler<Request, Response> handler,
  )   : type = RpcMethodType.unary,
        _unaryHandler = handler,
        _serverStreamHandler = null,
        _clientStreamHandler = null,
        _bidirectionalHandler = null,
        _logger = RpcLogger(
            '${contract.serviceName}.${contract.methodName}.unary.impl');

  /// Создает реализацию серверного стрима
  RpcMethodImplementation.serverStreaming(
    this.contract,
    RpcMethodServerStreamHandler<Request, Response> handler,
  )   : type = RpcMethodType.serverStreaming,
        _unaryHandler = null,
        _serverStreamHandler = handler,
        _clientStreamHandler = null,
        _bidirectionalHandler = null,
        _logger = RpcLogger(
            '${contract.serviceName}.${contract.methodName}.server_stream.impl');

  /// Создает реализацию клиентского стрима
  RpcMethodImplementation.clientStreaming(
    this.contract,
    RpcMethodClientStreamHandler<Request, Response> handler,
  )   : type = RpcMethodType.clientStreaming,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = handler,
        _bidirectionalHandler = null,
        _logger = RpcLogger(
            '${contract.serviceName}.${contract.methodName}.client_stream.impl') {
    // Сразу инициализируем Completer, так как обработчик уже предоставлен
    if (!_handlerInitCompleter.isCompleted) {
      _handlerInitCompleter.complete();
    }
  }

  /// Создает реализацию двунаправленного стрима
  RpcMethodImplementation.bidirectionalStreaming(
    this.contract,
    RpcMethodBidirectionalHandler<Request, Response> handler,
  )   : type = RpcMethodType.bidirectional,
        _unaryHandler = null,
        _serverStreamHandler = null,
        _clientStreamHandler = null,
        _bidirectionalHandler = handler,
        _logger = RpcLogger(
            '${contract.serviceName}.${contract.methodName}.bidi_stream.impl');

  /// Вызывает метод с указанным запросом
  Future<Response> makeUnaryRequest(Request request) async {
    if (type != RpcMethodType.unary) {
      throw _unsupportedOperationException('makeUnaryRequest');
    }
    if (_unaryHandler == null) {
      throw _missingHandlerException('makeUnaryRequest');
    }

    try {
      return await _unaryHandler!(request);
    } catch (e, stackTrace) {
      // Логируем ошибку
      _logger.error(
        'Ошибка при вызове унарного метода: $e',
        error: e,
        stackTrace: stackTrace,
      );
      throw RpcCustomException(
        customMessage: 'Ошибка при вызове унарного метода: $e',
        debugLabel: 'RpcMethodImplementation.makeUnaryRequest',
      );
    }
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
    } catch (e, stackTrace) {
      // Логируем ошибку
      _logger.error(
        'Ошибка при открытии стрима: $e',
        error: e,
        stackTrace: stackTrace,
      );
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

  /// Открывает обработку клиентского стриминга
  Future<BidiStream<Request, Response>> openClientStreaming({
    required Stream<Request> stream,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) async {
    // Ожидаем инициализации обработчика с таймаутом
    try {
      await _handlerInitCompleter.future.timeout(
        Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
          'Таймаут ожидания инициализации обработчика стриминга',
        ),
      );
    } catch (e) {
      if (e is TimeoutException) {
        _logger.error('Таймаут при ожидании инициализации обработчика стрима');
      }

      // Если обработчик все еще не инициализирован после ожидания
      if (_clientStreamHandler == null) {
        throw StateError(
          'Невозможно вызвать обработчик клиентского стрима с ответом: обработчик не установлен',
        );
      }
    }

    // Если streamId задан, логируем его для отладки
    _logger.debug(
      'Открытие клиентского стрима с ответом ${streamId != null ? '(ID: $streamId)' : ''}',
    );

    try {
      // Получаем стрим обработчик от контракта
      final clientStream = _clientStreamHandler!();

      // Перенаправляем все запросы из входящего потока в стрим обработчика
      await for (final request in stream) {
        _logger.debug(
          'Перенаправляем запрос в обработчик: ${request.runtimeType}',
        );

        // Отправляем запрос в обработчик
        clientStream.send(request);
      }

      // Завершаем отправку запросов
      await clientStream.finishSending();

      // Ожидаем ответ от обработчика
      final response = await clientStream.getResponse();

      _logger.debug(
        'Получен ответ от обработчика клиентского стрима: ${response?.runtimeType}',
      );

      // Создаем контроллеры для управления потоками
      final requestController = StreamController<Request>();
      final responseController = StreamController<Response>();

      // Закрываем контроллер запросов, так как отправка завершена
      requestController.close();

      // Если есть ответ, добавляем его в контроллер ответов
      if (response != null) {
        responseController.add(response);
      }
      responseController.close();

      // Создаем и возвращаем новый BidiStream
      return BidiStream<Request, Response>(
        responseStream: responseController.stream,
        sendFunction: (_) => throw StateError('Отправка запросов завершена'),
        closeFunction: () async {},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Ошибка при обработке клиентского стрима с ответом: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
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
            _logger.debug(
              'Обработчик отправил ответ: ${response.runtimeType}',
            );
            outputController.add(response);
          },
          onError: (error, stackTrace) {
            _logger.error(
              'Ошибка в потоке обработчика',
              error: {'error': error.toString()},
              stackTrace: stackTrace,
            );
            outputController.addError(error, stackTrace);
          },
          onDone: () {
            _logger.debug(
              'Поток обработчика завершен',
            );
            outputController.close();
          },
        );

        // Подписываемся на входящий поток запросов и передаем запросы в bidiStream
        requestStream.listen(
          (request) {
            _logger.debug(
              'Получен запрос, отправляем в обработчик: ${request.runtimeType}',
            );
            // Отправляем запрос в исходный bidiStream
            try {
              // Безопасно отправляем запрос в BidiStream
              final typedBidiStream = bidiStream;
              typedBidiStream.send(request);
            } catch (e, stackTrace) {
              _logger.error(
                'Ошибка при отправке запроса в обработчик',
                error: {'error': e.toString()},
                stackTrace: stackTrace,
              );
              outputController.addError(e, stackTrace);
            }
          },
          onError: (error, stackTrace) {
            _logger.error(
              'Ошибка во входящем потоке запросов',
              error: {'error': error.toString()},
              stackTrace: stackTrace,
            );
            outputController.addError(error, stackTrace);
          },
          onDone: () {
            // При закрытии входящего потока закрываем bidiStream
            _logger.debug(
              'Входящий поток запросов завершен, закрываем обработчик',
            );

            try {
              final typedBidiStream = bidiStream;
              typedBidiStream.close();
            } catch (e, stackTrace) {
              _logger.error(
                'Ошибка при закрытии потока обработчика: $e',
                error: e,
                stackTrace: stackTrace,
              );
              // Не закрываем outputController здесь, т.к. он закроется при завершении потока bidiStream
            }
          },
        );

        return outputController.stream;
      });

      // Создаем BidiStream с входящим потоком запросов
      return generator.create(incomingStream);
    } catch (e, stackTrace) {
      _logger.error(
        'Ошибка при обработке двунаправленного потока: $e',
        error: e,
        stackTrace: stackTrace,
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
