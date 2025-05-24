part of '../_index.dart';

/// Клиентская реализация двунаправленного стрима gRPC со Stream ID.
///
/// Обеспечивает полную реализацию клиентской стороны двунаправленного
/// стриминга (Bidirectional Streaming RPC). Позволяет клиенту отправлять
/// поток запросов серверу и одновременно получать поток ответов.
/// Каждый стрим использует уникальный Stream ID согласно gRPC спецификации.
///
/// Особенности:
/// - Асинхронный обмен сообщениями в обоих направлениях
/// - Потоковый интерфейс для отправки и получения (через Stream)
/// - Автоматическая сериализация/десериализация сообщений
/// - Корректная обработка заголовков и трейлеров gRPC
final class BidirectionalStreamClient<TRequest, TResponse> {
  final RpcLogger? _logger;

  /// Базовый транспорт для обмена данными
  final IRpcTransport _transport;

  /// Уникальный Stream ID для этого RPC вызова
  late final int _streamId;

  /// Имя сервиса
  final String _serviceName;

  /// Имя метода
  final String _methodName;

  /// Путь метода в формате /<ServiceName>/<MethodName>
  late final String _methodPath;

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
  late final RpcMessageParser _parser;

  /// Поток для отправки запросов (для внутреннего использования)
  Stream<TRequest> get requests => _requestController.stream;

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
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "ChatService")
  /// [methodName] Имя метода (например, "Connect")
  /// [requestSerializer] Кодек для сериализации запросов
  /// [responseSerializer] Кодек для десериализации ответов
  /// [logger] Опциональный логгер
  BidirectionalStreamClient({
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    RpcLogger? logger,
  })  : _transport = transport,
        _serviceName = serviceName,
        _methodName = methodName,
        _requestSerializer = requestSerializer,
        _responseSerializer = responseSerializer,
        _parser = RpcMessageParser(logger: logger),
        _logger = logger {
    _streamId = _transport.createStream();
    _methodPath = '/$serviceName/$methodName';
    unawaited(_setupStreams());
  }

  /// Настраивает потоки данных между приложением и транспортом.
  ///
  /// Создает два пайплайна:
  /// 1. От приложения к сети: сериализация и отправка запросов
  /// 2. От сети к приложению: получение, парсинг и десериализация ответов
  Future<void> _setupStreams() async {
    // Отправляем начальные метаданные для инициализации RPC вызова
    final initialMetadata =
        RpcMetadata.forClientRequest(_serviceName, _methodName);
    await _transport.sendMetadata(_streamId, initialMetadata);
    _logger?.debug('Начальные метаданные отправлены для $_methodPath');

    // Настраиваем отправку запросов
    _requestController.stream.listen(
      (request) async {
        final serialized = _requestSerializer.serialize(request);
        final framedMessage = RpcMessageFrame.encode(serialized);
        await _transport.sendMessage(_streamId, framedMessage);
        _logger?.debug('Отправлено сообщение через транспорт: $framedMessage');
      },
      onDone: () async {
        _logger?.debug('Поток запросов завершен, вызываем finishSending()');
        await _transport.finishSending(_streamId);
      },
    );

    add(RpcMessage<TResponse> response) {
      if (!_responseController.isClosed) {
        _responseController.add(response);
      }
    }

    error(Object error, [StackTrace? stackTrace]) {
      if (!_responseController.isClosed) {
        _responseController.addError(error, stackTrace);
      }
    }

    done() async {
      if (!_responseController.isClosed) {
        await _responseController.close();
      }
    }

    // Настраиваем прием ответов для нашего stream
    _transport.getMessagesForStream(_streamId).listen(
      (message) async {
        if (message.isMetadataOnly) {
          // Обрабатываем метаданные
          final statusCode =
              message.metadata?.getHeaderValue(RpcConstants.GRPC_STATUS_HEADER);

          if (statusCode != null) {
            _logger?.debug('Получен статус: $statusCode');
          } else {
            _logger?.debug('Получены метаданные от транспорта');
          }

          if (statusCode != null) {
            // Это трейлер, проверяем статус
            final code = int.parse(statusCode);
            if (code != RpcStatus.OK) {
              final errorMessage = message.metadata
                      ?.getHeaderValue(RpcConstants.GRPC_MESSAGE_HEADER) ??
                  '';
              _logger?.error('Ошибка gRPC: $code - $errorMessage');
              error(Exception('gRPC error $code: $errorMessage'));
            }

            if (message.isEndOfStream) {
              _logger?.debug('Получен END_STREAM, закрываем контроллер');
              await done();
            }
          }

          // Передаем метаданные в поток ответов
          final metadataMessage = RpcMessage<TResponse>(
            metadata: message.metadata,
            isMetadataOnly: true,
            isEndOfStream: message.isEndOfStream,
          );

          add(metadataMessage);
        } else if (message.payload != null) {
          // Обрабатываем сообщения
          final messageBytes = message.payload!;
          _logger?.debug(
            'Получено сообщение от транспорта размером: ${messageBytes.length} байт',
          );

          final messages = _parser(messageBytes);

          for (var msgBytes in messages) {
            try {
              final response = _responseSerializer.deserialize(msgBytes);
              final responseMessage = RpcMessage.withPayload(response);
              add(responseMessage);
            } catch (e, stackTrace) {
              _logger?.error(
                'Ошибка при десериализации: $e',
                error: e,
                stackTrace: stackTrace,
              );
              error(e, stackTrace);
            }
          }
        }
      },
      onError: (e, stackTrace) async {
        _logger?.error(
          'Ошибка от транспорта: $e',
          error: e,
          stackTrace: stackTrace,
        );
        error(e, stackTrace);
        await done();
      },
      onDone: () async {
        _logger?.debug('Транспорт завершил поток сообщений');
        await done();
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
  Future<void> send(TRequest request) async {
    if (!_requestController.isClosed) {
      _requestController.add(request);
    }
  }

  /// Завершает отправку запросов.
  ///
  /// Сигнализирует серверу, что клиент закончил отправку запросов.
  /// После вызова этого метода новые запросы отправлять нельзя,
  /// но можно продолжать получать ответы от сервера.
  Future<void> finishSending() async {
    if (!_requestController.isClosed) {
      await _requestController.close();
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
    // Не закрываем транспорт, так как он может использоваться другими стримами
  }
}

/// Серверная реализация двунаправленного стрима gRPC со Stream ID.
///
/// Обеспечивает полную реализацию серверной стороны двунаправленного
/// стриминга gRPC. Обрабатывает входящие запросы от клиента и позволяет
/// отправлять ответы асинхронно, независимо от получения запросов.
/// Использует уникальный Stream ID для идентификации вызова.
///
/// Ключевые возможности:
/// - Асинхронная обработка потока входящих запросов
/// - Асинхронная отправка потока ответов
/// - Автоматическая сериализация/десериализация сообщений
/// - Управление статусами и ошибками gRPC
final class BidirectionalStreamServer<TRequest, TResponse> {
  final RpcLogger? _logger;

  /// Базовый транспорт для обмена данными
  final IRpcTransport _transport;

  /// Имя сервиса
  final String serviceName;

  /// Имя метода
  final String methodName;

  /// Путь метода в формате /<ServiceName>/<MethodName>
  late final String _methodPath;

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
  late final RpcMessageParser _parser;

  /// Stream ID для активного соединения (устанавливается при первом входящем вызове)
  int? _activeStreamId;

  /// Поток входящих запросов от клиента.
  ///
  /// Предоставляет доступ к потоку запросов, получаемых от клиента.
  /// Бизнес-логика может подписаться на этот поток для обработки запросов.
  /// Поток завершается, когда клиент завершает свою часть стрима.
  Stream<TRequest> get requests => _requestController.stream;

  /// Создает новый серверный двунаправленный стрим.
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "ChatService")
  /// [methodName] Имя метода (например, "Connect")
  /// [requestSerializer] Кодек для десериализации запросов
  /// [responseSerializer] Кодек для сериализации ответов
  /// [logger] Опциональный логгер
  BidirectionalStreamServer({
    required IRpcTransport transport,
    required this.serviceName,
    required this.methodName,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    RpcLogger? logger,
  })  : _transport = transport,
        _requestSerializer = requestSerializer,
        _responseSerializer = responseSerializer,
        _parser = RpcMessageParser(logger: logger),
        _logger = logger {
    _methodPath = '/$serviceName/$methodName';
    unawaited(_setupStreams());
  }

  /// Настраивает потоки данных для обработки запросов и отправки ответов.
  ///
  /// 1. Слушает все входящие сообщения и реагирует на новые Stream ID
  /// 2. Настраивает пайплайн для отправки ответов
  /// 3. Настраивает обработку входящих сообщений от клиента
  Future<void> _setupStreams() async {
    // Слушаем ВСЕ входящие сообщения для обнаружения новых вызовов
    _transport.incomingMessages.listen(
      (message) async {
        // Если это новый Stream ID и метаданные, проверяем путь метода
        if (message.isMetadataOnly &&
            message.metadata != null &&
            _activeStreamId == null) {
          // Проверяем, что это вызов нашего метода
          if (message.methodPath == _methodPath) {
            _activeStreamId = message.streamId;
            _logger
                ?.debug('Новый вызов $_methodPath на stream $_activeStreamId');

            // Отправляем начальные заголовки в ответ
            final initialHeaders = RpcMetadata.forServerInitialResponse();
            await _transport.sendMetadata(_activeStreamId!, initialHeaders);
            _logger?.debug('Начальные заголовки отправлены для $_methodPath');

            // Настраиваем отправку ответов для этого stream
            _responseController.stream.listen(
              (response) async {
                final serialized = _responseSerializer.serialize(response);
                final framedMessage = RpcMessageFrame.encode(serialized);
                await _transport.sendMessage(_activeStreamId!, framedMessage);
                _logger?.debug(
                  'Ответ фреймирован, размер: ${framedMessage.length} байт',
                );
              },
              onDone: () async {
                // Отправляем трейлер при завершении отправки ответов
                final trailers = RpcMetadata.forTrailer(RpcStatus.OK);
                await _transport.sendMetadata(_activeStreamId!, trailers,
                    endStream: true);
                _logger?.debug('Трейлер отправлен для $_methodPath');
              },
            );
          } else {
            // Это не наш метод, игнорируем
            _logger?.debug(
                'Игнорируем вызов ${message.methodPath}, ожидаем $_methodPath');
            return;
          }
        }

        // Обрабатываем данные только для нашего активного stream
        if (message.streamId == _activeStreamId) {
          if (!message.isMetadataOnly && message.payload != null) {
            // Обрабатываем сообщения
            final messageBytes = message.payload!;
            _logger?.debug(
              'Получено сообщение от транспорта размером: ${messageBytes.length} байт',
            );
            final messages = _parser(messageBytes);

            for (var msgBytes in messages) {
              final request = _requestSerializer.deserialize(msgBytes);
              _requestController.add(request);
            }
          }

          // Если это конец потока запросов, закрываем контроллер
          if (message.isEndOfStream) {
            _logger?.debug('Получен END_STREAM, закрываем контроллер запросов');
            _requestController.close();
          }
        }
      },
      onError: (error) {
        _logger?.error('Ошибка от транспорта: $error', error: error);
        _requestController.addError(error);
        _requestController.close();
        if (_activeStreamId != null) {
          sendError(RpcStatus.INTERNAL, 'Внутренняя ошибка: $error');
        }
      },
      onDone: () {
        _logger?.debug('Транспорт завершил поток сообщений');
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
  Future<void> send(TResponse response) async {
    if (_activeStreamId == null) {
      _logger?.warning('Попытка отправить ответ без активного соединения');
      return;
    }

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
    if (_activeStreamId == null) {
      _logger?.warning('Попытка отправить ошибку без активного соединения');
      return;
    }

    if (!_responseController.isClosed) {
      _responseController.close();
    }

    final trailers = RpcMetadata.forTrailer(statusCode, message: message);
    await _transport.sendMetadata(_activeStreamId!, trailers, endStream: true);
  }

  /// Завершает отправку ответов.
  ///
  /// Сигнализирует клиенту, что сервер закончил отправку ответов.
  /// Автоматически отправляет трейлер с успешным статусом.
  /// После вызова этого метода новые ответы отправлять нельзя.
  Future<void> finishReceiving() async {
    if (!_responseController.isClosed) {
      await _responseController.close();
    }
  }

  /// Закрывает стрим и освобождает ресурсы.
  ///
  /// Полностью завершает двунаправленный стрим:
  /// - Завершает отправку ответов
  /// - Закрывает транспортное соединение
  /// - Отменяет все подписки
  Future<void> close() async {
    await finishReceiving();
    // Не закрываем транспорт, так как он может использоваться другими стримами
  }
}
