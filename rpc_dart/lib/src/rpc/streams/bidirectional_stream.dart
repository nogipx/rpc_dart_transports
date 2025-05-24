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
final class BidirectionalStreamCaller<TRequest, TResponse> {
  late final RpcLogger? _logger;

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
  BidirectionalStreamCaller({
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
        _responseSerializer = responseSerializer {
    _logger = logger?.child('BidirectionalCaller');
    _parser = RpcMessageParser(logger: _logger);
    _streamId = _transport.createStream();
    _methodPath = '/$serviceName/$methodName';
    _logger?.info(
        'Создан двунаправленный стрим клиент для $_methodPath [streamId: $_streamId]');
    unawaited(_setupStreams());
  }

  /// Настраивает потоки данных между приложением и транспортом.
  ///
  /// Создает два пайплайна:
  /// 1. От приложения к сети: сериализация и отправка запросов
  /// 2. От сети к приложению: получение, парсинг и десериализация ответов
  Future<void> _setupStreams() async {
    _logger?.debug(
        'Настройка потоков для стрима $_methodPath [streamId: $_streamId]');

    // Отправляем начальные метаданные для инициализации RPC вызова
    final initialMetadata =
        RpcMetadata.forClientRequest(_serviceName, _methodName);
    await _transport.sendMetadata(_streamId, initialMetadata);
    _logger?.debug(
        'Начальные метаданные отправлены для $_methodPath [streamId: $_streamId]');

    // Настраиваем отправку запросов
    _requestController.stream.listen(
      (request) async {
        _logger?.debug(
            'Получен запрос для отправки в стрим $_methodPath [streamId: $_streamId]');
        final serialized = _requestSerializer.serialize(request);
        _logger?.debug(
            'Запрос сериализован, размер: ${serialized.length} байт [streamId: $_streamId]');
        final framedMessage = RpcMessageFrame.encode(serialized);
        await _transport.sendMessage(_streamId, framedMessage);
        _logger?.debug(
            'Отправлено сообщение через транспорт: размер ${framedMessage.length} байт [streamId: $_streamId]');
      },
      onDone: () async {
        _logger?.debug(
            'Поток запросов завершен, вызываем finishSending() [streamId: $_streamId]');
        await _transport.finishSending(_streamId);
        _logger?.info(
            'Отправка запросов завершена для $_methodPath [streamId: $_streamId]');
      },
      onError: (Object e, StackTrace stackTrace) {
        _logger?.error(
            'Ошибка в потоке запросов для $_methodPath [streamId: $_streamId]',
            error: e,
            stackTrace: stackTrace);
      },
    );

    add(RpcMessage<TResponse> response) {
      if (!_responseController.isClosed) {
        _logger?.debug(
            'Добавление ответа в поток $_methodPath [streamId: $_streamId]');
        _responseController.add(response);
      } else {
        _logger?.warning(
            'Попытка добавить ответ в закрытый контроллер $_methodPath [streamId: $_streamId]');
      }
    }

    error(Object error, [StackTrace? stackTrace]) {
      if (!_responseController.isClosed) {
        _logger?.error(
            'Добавление ошибки в поток ответов $_methodPath [streamId: $_streamId]',
            error: error,
            stackTrace: stackTrace);
        _responseController.addError(error, stackTrace);
      } else {
        _logger?.warning(
            'Попытка добавить ошибку в закрытый контроллер $_methodPath [streamId: $_streamId]');
      }
    }

    done() async {
      if (!_responseController.isClosed) {
        _logger?.info(
            'Закрытие потока ответов $_methodPath [streamId: $_streamId]');
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
            _logger?.debug(
                'Получен статус: $statusCode для $_methodPath [streamId: $_streamId]');
          } else {
            _logger?.debug(
                'Получены метаданные от транспорта для $_methodPath [streamId: $_streamId]');
          }

          if (statusCode != null) {
            // Это трейлер, проверяем статус
            final code = int.parse(statusCode);
            if (code != RpcStatus.OK) {
              final errorMessage = message.metadata
                      ?.getHeaderValue(RpcConstants.GRPC_MESSAGE_HEADER) ??
                  '';
              _logger?.error(
                  'Ошибка gRPC: $code - $errorMessage для $_methodPath [streamId: $_streamId]');
              error(Exception('gRPC error $code: $errorMessage'));
            } else {
              _logger?.debug(
                  'Получен успешный статус завершения для $_methodPath [streamId: $_streamId]');
            }

            if (message.isEndOfStream) {
              _logger?.debug(
                  'Получен END_STREAM, закрываем контроллер $_methodPath [streamId: $_streamId]');
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
            'Получено сообщение от транспорта размером: ${messageBytes.length} байт для $_methodPath [streamId: $_streamId]',
          );

          final messages = _parser(messageBytes);
          _logger?.debug(
              'Парсер извлек ${messages.length} сообщений из фрейма для $_methodPath [streamId: $_streamId]');

          for (var msgBytes in messages) {
            try {
              _logger?.debug(
                  'Десериализация сообщения размером ${msgBytes.length} байт для $_methodPath [streamId: $_streamId]');
              final response = _responseSerializer.deserialize(msgBytes);
              final responseMessage = RpcMessage.withPayload(response);
              add(responseMessage);
            } catch (e, stackTrace) {
              _logger?.error(
                'Ошибка при десериализации сообщения для $_methodPath [streamId: $_streamId]: $e',
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
          'Ошибка от транспорта для $_methodPath [streamId: $_streamId]: $e',
          error: e,
          stackTrace: stackTrace,
        );
        error(e, stackTrace);
        await done();
      },
      onDone: () async {
        _logger?.debug(
            'Транспорт завершил поток сообщений для $_methodPath [streamId: $_streamId]');
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
      _logger?.debug(
          'Отправка запроса в стрим $_methodPath [streamId: $_streamId]');
      _requestController.add(request);
    } else {
      _logger?.warning(
          'Попытка отправить запрос в закрытый стрим $_methodPath [streamId: $_streamId]');
    }
  }

  /// Завершает отправку запросов.
  ///
  /// Сигнализирует серверу, что клиент закончил отправку запросов.
  /// После вызова этого метода новые запросы отправлять нельзя,
  /// но можно продолжать получать ответы от сервера.
  Future<void> finishSending() async {
    if (!_requestController.isClosed) {
      _logger?.info(
          'Завершение отправки запросов для $_methodPath [streamId: $_streamId]');
      await _requestController.close();
    } else {
      _logger?.debug(
          'Попытка завершить уже закрытый поток запросов $_methodPath [streamId: $_streamId]');
    }
  }

  /// Закрывает стрим.
  ///
  /// Полностью завершает двунаправленный стрим, освобождая все ресурсы.
  /// - Завершает отправку запросов
  /// - Закрывает транспортное соединение
  /// - Отменяет все подписки на события
  Future<void> close() async {
    _logger?.info(
        'Закрытие двунаправленного стрима $_methodPath [streamId: $_streamId]');
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
final class BidirectionalStreamResponder<TRequest, TResponse> {
  late final RpcLogger? _logger;

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
  BidirectionalStreamResponder({
    required IRpcTransport transport,
    required this.serviceName,
    required this.methodName,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    RpcLogger? logger,
  })  : _transport = transport,
        _requestSerializer = requestSerializer,
        _responseSerializer = responseSerializer {
    _logger = logger?.child('BidirectionalResponder');
    _parser = RpcMessageParser(logger: _logger);
    _methodPath = '/$serviceName/$methodName';
    _logger?.info('Создан серверный двунаправленный стрим для $_methodPath');
    unawaited(_setupStreams());
  }

  /// Настраивает потоки данных для обработки запросов и отправки ответов.
  ///
  /// 1. Слушает все входящие сообщения и реагирует на новые Stream ID
  /// 2. Настраивает пайплайн для отправки ответов
  /// 3. Настраивает обработку входящих сообщений от клиента
  Future<void> _setupStreams() async {
    _logger?.debug('Настройка обработки сообщений для $_methodPath');

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
            _logger?.debug(
                'Новый вызов $_methodPath на stream ${message.streamId}');

            // Отправляем начальные заголовки в ответ
            final initialHeaders = RpcMetadata.forServerInitialResponse();
            await _transport.sendMetadata(_activeStreamId!, initialHeaders);
            _logger?.debug(
                'Начальные заголовки отправлены для $_methodPath [streamId: ${message.streamId}]');

            // Настраиваем отправку ответов для этого stream
            _responseController.stream.listen(
              (response) async {
                _logger?.debug(
                    'Отправка ответа для $_methodPath [streamId: ${message.streamId}]');
                final serialized = _responseSerializer.serialize(response);
                _logger?.debug(
                    'Ответ сериализован, размер: ${serialized.length} байт [streamId: ${message.streamId}]');
                final framedMessage = RpcMessageFrame.encode(serialized);
                await _transport.sendMessage(_activeStreamId!, framedMessage);
                _logger?.debug(
                  'Ответ фреймирован и отправлен, размер: ${framedMessage.length} байт [streamId: ${message.streamId}]',
                );
              },
              onDone: () async {
                // Отправляем трейлер при завершении отправки ответов
                _logger?.info(
                    'Завершение отправки ответов для $_methodPath [streamId: ${message.streamId}]');
                final trailers = RpcMetadata.forTrailer(RpcStatus.OK);
                await _transport.sendMetadata(_activeStreamId!, trailers,
                    endStream: true);
                _logger?.debug(
                    'Трейлер отправлен для $_methodPath [streamId: ${message.streamId}]');
              },
              onError: (Object e, StackTrace stackTrace) {
                _logger?.error(
                    'Ошибка при отправке ответа для $_methodPath [streamId: ${message.streamId}]',
                    error: e,
                    stackTrace: stackTrace);
              },
            );
          } else {
            // Это не наш метод, игнорируем
            _logger?.debug(
                'Игнорируем вызов ${message.methodPath}, ожидаем $_methodPath [streamId: ${message.streamId}]');
            return;
          }
        }

        // Обрабатываем данные только для нашего активного stream
        if (message.streamId == _activeStreamId) {
          if (!message.isMetadataOnly && message.payload != null) {
            // Обрабатываем сообщения
            final messageBytes = message.payload!;
            _logger?.debug(
              'Получено сообщение от клиента размером: ${messageBytes.length} байт [streamId: ${message.streamId}]',
            );
            final messages = _parser(messageBytes);
            _logger?.debug(
                'Парсер извлек ${messages.length} сообщений из фрейма [streamId: ${message.streamId}]');

            for (var msgBytes in messages) {
              try {
                _logger?.debug(
                    'Десериализация запроса размером ${msgBytes.length} байт [streamId: ${message.streamId}]');
                final request = _requestSerializer.deserialize(msgBytes);
                _requestController.add(request);
                _logger?.debug(
                    'Запрос десериализован и добавлен в поток запросов [streamId: ${message.streamId}]');
              } catch (e, stackTrace) {
                _logger?.error(
                    'Ошибка при десериализации запроса [streamId: ${message.streamId}]',
                    error: e,
                    stackTrace: stackTrace);
                _requestController.addError(e, stackTrace);
              }
            }
          }

          // Если это конец потока запросов, закрываем контроллер
          if (message.isEndOfStream) {
            _logger?.debug(
                'Получен END_STREAM, закрываем контроллер запросов [streamId: ${message.streamId}]');
            _requestController.close();
          }
        }
      },
      onError: (error, stackTrace) {
        _logger?.error('Ошибка от транспорта: $error',
            error: error, stackTrace: stackTrace);
        _requestController.addError(error, stackTrace);
        _requestController.close();
        if (_activeStreamId != null) {
          sendError(RpcStatus.INTERNAL, 'Внутренняя ошибка: $error');
        }
      },
      onDone: () {
        _logger?.debug('Транспорт завершил поток сообщений для $_methodPath');
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
      _logger?.warning(
          'Попытка отправить ответ без активного соединения для $_methodPath');
      return;
    }

    if (!_responseController.isClosed) {
      _logger?.debug(
          'Отправка ответа в стрим $_methodPath [streamId: $_activeStreamId]');
      _responseController.add(response);
    } else {
      _logger?.warning(
          'Попытка отправить ответ в закрытый стрим $_methodPath [streamId: $_activeStreamId]');
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
      _logger?.warning(
          'Попытка отправить ошибку без активного соединения для $_methodPath');
      return;
    }

    _logger?.error(
        'Отправка ошибки клиенту: $statusCode - $message [streamId: $_activeStreamId]');

    if (!_responseController.isClosed) {
      _responseController.close();
    }

    final trailers = RpcMetadata.forTrailer(statusCode, message: message);
    await _transport.sendMetadata(_activeStreamId!, trailers, endStream: true);
    _logger?.debug(
        'Трейлер с ошибкой отправлен клиенту [streamId: $_activeStreamId]');
  }

  /// Завершает отправку ответов.
  ///
  /// Сигнализирует клиенту, что сервер закончил отправку ответов.
  /// Автоматически отправляет трейлер с успешным статусом.
  /// После вызова этого метода новые ответы отправлять нельзя.
  Future<void> finishReceiving() async {
    if (!_responseController.isClosed) {
      _logger?.info(
          'Завершение отправки ответов для $_methodPath [streamId: $_activeStreamId]');
      await _responseController.close();
    } else {
      _logger?.debug(
          'Попытка завершить уже закрытый поток ответов $_methodPath [streamId: $_activeStreamId]');
    }
  }

  /// Закрывает стрим и освобождает ресурсы.
  ///
  /// Полностью завершает двунаправленный стрим:
  /// - Завершает отправку ответов
  /// - Закрывает транспортное соединение
  /// - Отменяет все подписки
  Future<void> close() async {
    _logger?.info(
        'Закрытие двунаправленного стрима сервера $_methodPath [streamId: $_activeStreamId]');

    // Если нет активного соединения, просто закрываем контроллеры
    if (_activeStreamId == null) {
      if (!_requestController.isClosed) {
        _requestController.close();
      }
      if (!_responseController.isClosed) {
        _responseController.close();
      }
      return;
    }

    // Если есть активное соединение, корректно завершаем его
    await finishReceiving();
    // Не закрываем транспорт, так как он может использоваться другими стримами
  }
}
