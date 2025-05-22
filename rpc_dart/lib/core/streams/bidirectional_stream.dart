part of '../_index.dart';

/// Клиентская реализация двунаправленного стрима gRPC.
///
/// Обеспечивает полную реализацию клиентской стороны двунаправленного
/// стриминга (Bidirectional Streaming RPC). Позволяет клиенту отправлять
/// поток запросов серверу и одновременно получать поток ответов.
///
/// Особенности:
/// - Асинхронный обмен сообщениями в обоих направлениях
/// - Потоковый интерфейс для отправки и получения (через Stream)
/// - Автоматическая сериализация/десериализация сообщений
/// - Корректная обработка заголовков и трейлеров gRPC
final class BidirectionalStreamClient<TRequest, TResponse> {
  /// Базовый транспорт для обмена данными
  final IRpcTransport _transport;

  /// Кодек для сериализации исходящих запросов
  final IRpcSerializer<TRequest> _requestSerializer;

  /// Кодек для десериализации входящих ответов
  final IRpcSerializer<TResponse> _responseSerializer;

  /// Контроллер потока исходящих запросов
  final StreamController<TRequest> _requestController =
      StreamController<TRequest>();

  /// Контроллер потока входящих ответов
  final StreamController<RpcMessage<TResponse>> _responseController =
      StreamController<RpcMessage<TResponse>>();

  /// Парсер для обработки фрагментированных сообщений
  final RpcMessageParser _parser = RpcMessageParser();

  /// Поток для отправки запросов (для внутреннего использования)
  Stream<TRequest> get requestStream => _requestController.stream;

  /// Поток входящих ответов от сервера.
  ///
  /// Предоставляет доступ к потоку ответов, получаемых от сервера.
  /// Каждый элемент может быть:
  /// - Сообщение с полезной нагрузкой (payload)
  /// - Сообщение с метаданными (metadata)
  ///
  /// Поток завершается при получении трейлера с END_STREAM
  /// или при возникновении ошибки.
  Stream<RpcMessage<TResponse>> get responses => _responseController.stream;

  /// Создает новый клиентский двунаправленный стрим.
  ///
  /// [_transport] Транспортный уровень
  /// [_requestCodec] Кодек для сериализации запросов
  /// [_responseCodec] Кодек для десериализации ответов
  BidirectionalStreamClient({
    required IRpcTransport transport,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
  })  : _transport = transport,
        _requestSerializer = requestSerializer,
        _responseSerializer = responseSerializer {
    _setupStreams();
  }

  /// Настраивает потоки данных между приложением и транспортом.
  ///
  /// Создает два пайплайна:
  /// 1. От приложения к сети: сериализация и отправка запросов
  /// 2. От сети к приложению: получение, парсинг и десериализация ответов
  void _setupStreams() {
    // Настраиваем отправку запросов
    _requestController.stream.listen(
      (request) async {
        final serialized = _requestSerializer.serialize(request);
        final framedMessage = GrpcMessageFrame.encode(serialized);
        await _transport.sendMessage(framedMessage);
      },
      onDone: () async {
        await _transport.finishSending();
      },
    );

    // Настраиваем прием ответов
    _transport.incomingMessages.listen(
      (message) {
        if (message.isMetadataOnly) {
          // Обрабатываем метаданные
          final statusCode = message.metadata
              ?.getHeaderValue(GrpcConstants.GRPC_STATUS_HEADER);

          if (statusCode != null) {
            // Это трейлер, проверяем статус
            final code = int.parse(statusCode);
            if (code != GrpcStatus.OK) {
              final errorMessage = message.metadata
                      ?.getHeaderValue(GrpcConstants.GRPC_MESSAGE_HEADER) ??
                  '';
              _responseController
                  .addError(Exception('gRPC error $code: $errorMessage'));
            }

            if (message.isEndOfStream) {
              _responseController.close();
            }
          }

          // Передаем метаданные в поток ответов
          _responseController.add(RpcMessage<TResponse>(
            metadata: message.metadata,
            isMetadataOnly: true,
            isEndOfStream: message.isEndOfStream,
          ));
        } else if (message.payload != null) {
          // Обрабатываем сообщения
          final messageBytes = message.payload!;
          final messages = _parser(messageBytes);

          for (var msgBytes in messages) {
            final response = _responseSerializer.deserialize(msgBytes);
            _responseController.add(RpcMessage.withPayload(response));
          }
        }
      },
      onError: (error) {
        _responseController.addError(error);
        _responseController.close();
      },
      onDone: () {
        if (!_responseController.isClosed) {
          _responseController.close();
        }
      },
    );
  }

  /// Отправляет запрос серверу.
  ///
  /// Сериализует объект запроса и отправляет его серверу через транспорт.
  /// Запросы можно отправлять в любом порядке и в любое время,
  /// пока не вызван метод finishSending().
  ///
  /// [request] Объект запроса для отправки
  void send(TRequest request) {
    if (!_requestController.isClosed) {
      _requestController.add(request);
    }
  }

  /// Завершает отправку запросов.
  ///
  /// Сигнализирует серверу, что клиент закончил отправку запросов.
  /// После вызова этого метода новые запросы отправлять нельзя,
  /// но можно продолжать получать ответы от сервера.
  void finishSending() {
    if (!_requestController.isClosed) {
      _requestController.close();
    }
  }

  /// Закрывает стрим.
  ///
  /// Полностью завершает двунаправленный стрим, освобождая все ресурсы.
  /// - Завершает отправку запросов
  /// - Закрывает транспортное соединение
  /// - Отменяет все подписки на события
  Future<void> close() async {
    finishSending();
    await _transport.close();
  }
}

/// Серверная реализация двунаправленного стрима gRPC.
///
/// Обеспечивает полную реализацию серверной стороны двунаправленного
/// стриминга gRPC. Обрабатывает входящие запросы от клиента и позволяет
/// отправлять ответы асинхронно, независимо от получения запросов.
///
/// Ключевые возможности:
/// - Асинхронная обработка потока входящих запросов
/// - Асинхронная отправка потока ответов
/// - Автоматическая сериализация/десериализация сообщений
/// - Управление статусами и ошибками gRPC
final class BidirectionalStreamServer<TRequest, TResponse> {
  /// Базовый транспорт для обмена данными
  final IRpcTransport _transport;

  /// Кодек для десериализации входящих запросов
  final IRpcSerializer<TRequest> _requestSerializer;

  /// Кодек для сериализации исходящих ответов
  final IRpcSerializer<TResponse> _responseSerializer;

  /// Контроллер потока входящих запросов
  final StreamController<TRequest> _requestController =
      StreamController<TRequest>();

  /// Контроллер потока исходящих ответов
  final StreamController<TResponse> _responseController =
      StreamController<TResponse>();

  /// Парсер для обработки фрагментированных сообщений
  final RpcMessageParser _parser = RpcMessageParser();

  /// Флаг, указывающий, были ли отправлены начальные заголовки
  bool _headersSent = false;

  /// Поток входящих запросов от клиента.
  ///
  /// Предоставляет доступ к потоку запросов, получаемых от клиента.
  /// Бизнес-логика может подписаться на этот поток для обработки запросов.
  /// Поток завершается, когда клиент завершает свою часть стрима.
  Stream<TRequest> get requests => _requestController.stream;

  /// Создает новый серверный двунаправленный стрим.
  ///
  /// [_transport] Транспортный уровень
  /// [_requestSerializer] Кодек для десериализации запросов
  /// [_responseSerializer] Кодек для сериализации ответов
  BidirectionalStreamServer({
    required IRpcTransport transport,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
  })  : _transport = transport,
        _requestSerializer = requestSerializer,
        _responseSerializer = responseSerializer {
    _setupStreams();
  }

  /// Настраивает потоки данных для обработки запросов и отправки ответов.
  ///
  /// 1. Инициализирует отправку начальных заголовков клиенту
  /// 2. Настраивает пайплайн для отправки ответов
  /// 3. Настраивает обработку входящих сообщений от клиента
  void _setupStreams() async {
    // Отправляем начальные заголовки
    final initialHeaders = RpcMetadata.forServerInitialResponse();
    await _transport.sendMetadata(initialHeaders);
    _headersSent = true;

    // Настраиваем отправку ответов
    _responseController.stream.listen(
      (response) async {
        final serialized = _responseSerializer.serialize(response);
        final framedMessage = GrpcMessageFrame.encode(serialized);
        await _transport.sendMessage(framedMessage);
      },
      onDone: () async {
        // Отправляем трейлер при завершении отправки ответов
        final trailers = RpcMetadata.forTrailer(GrpcStatus.OK);
        await _transport.sendMetadata(trailers, endStream: true);
      },
    );

    // Настраиваем прием запросов
    _transport.incomingMessages.listen(
      (message) {
        if (!message.isMetadataOnly && message.payload != null) {
          // Обрабатываем сообщения
          final messageBytes = message.payload!;
          final messages = _parser(messageBytes);

          for (var msgBytes in messages) {
            final request = _requestSerializer.deserialize(msgBytes);
            _requestController.add(request);
          }
        }

        // Если это конец потока запросов, закрываем контроллер
        if (message.isEndOfStream) {
          _requestController.close();
        }
      },
      onError: (error) {
        _requestController.addError(error);
        _requestController.close();
        sendError(GrpcStatus.INTERNAL, 'Внутренняя ошибка: $error');
      },
      onDone: () {
        if (!_requestController.isClosed) {
          _requestController.close();
        }
      },
    );
  }

  /// Отправляет ответ клиенту.
  ///
  /// Сериализует объект ответа и отправляет его клиенту.
  /// Ответы можно отправлять в любом порядке и в любое время,
  /// пока не вызван метод finishSending().
  ///
  /// [response] Объект ответа для отправки
  void send(TResponse response) {
    if (!_responseController.isClosed) {
      _responseController.add(response);
    }
  }

  /// Отправляет сообщение об ошибке клиенту.
  ///
  /// Завершает поток с указанным кодом ошибки gRPC и текстовым сообщением.
  /// После вызова этого метода стрим завершается и новые ответы
  /// отправлять невозможно.
  ///
  /// [statusCode] Код ошибки gRPC (см. GrpcStatus)
  /// [message] Текстовое сообщение с описанием ошибки
  Future<void> sendError(int statusCode, String message) async {
    if (!_responseController.isClosed) {
      _responseController.close();
    }

    final trailers = RpcMetadata.forTrailer(statusCode, message: message);
    await _transport.sendMetadata(trailers, endStream: true);
  }

  /// Завершает отправку ответов.
  ///
  /// Сигнализирует клиенту, что сервер закончил отправку ответов.
  /// Автоматически отправляет трейлер с успешным статусом.
  /// После вызова этого метода новые ответы отправлять нельзя.
  void finishSending() {
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }

  /// Закрывает стрим и освобождает ресурсы.
  ///
  /// Полностью завершает двунаправленный стрим:
  /// - Завершает отправку ответов
  /// - Закрывает транспортное соединение
  /// - Отменяет все подписки
  Future<void> close() async {
    finishSending();
    await _transport.close();
  }
}
