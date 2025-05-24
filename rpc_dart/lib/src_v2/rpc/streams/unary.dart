part of '../_index.dart';

/// Клиентская часть унарного вызова с поддержкой Stream ID.
///
/// Отправляет один запрос и получает один ответ.
/// Соответствует gRPC Unary RPC паттерну (1→1).
/// Каждый вызов создает собственный HTTP/2 stream с уникальным ID.
///
/// Пример использования:
/// ```dart
/// final client = UnaryClient<String, String>(
///   transport: transport,
///   serviceName: 'GreetingService',
///   methodName: 'SayHello',
///   requestSerializer: stringSerializer,
///   responseSerializer: stringSerializer,
/// );
///
/// final response = await client.call('Привет!');
/// print("Ответ: $response");
///
/// await client.close();
/// ```
final class UnaryCaller<TRequest, TResponse> {
  /// Транспорт для коммуникации
  final IRpcTransport _transport;

  /// Имя сервиса
  final String _serviceName;

  /// Имя метода
  final String _methodName;

  /// Путь метода в формате /<ServiceName>/<MethodName>
  late final String _methodPath;

  /// Сериализатор запросов
  final IRpcSerializer<TRequest> _requestSerializer;

  /// Сериализатор ответов
  final IRpcSerializer<TResponse> _responseSerializer;

  /// Логгер
  late final RpcLogger? _logger;

  /// Парсер для обработки фрагментированных сообщений
  late final RpcMessageParser _parser;

  /// Создает клиент унарного вызова
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "GreetingService")
  /// [methodName] Имя метода (например, "SayHello")
  /// [requestSerializer] Кодек для сериализации запроса
  /// [responseSerializer] Кодек для десериализации ответа
  /// [logger] Опциональный логгер
  UnaryCaller({
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
    _logger = logger?.child('UnaryCaller');
    _parser = RpcMessageParser(logger: _logger);
    _methodPath = '/$_serviceName/$_methodName';
    _logger?.info('Создан унарный клиент для $_methodPath');
  }

  /// Выполняет унарный вызов
  ///
  /// [request] Объект запроса
  /// [timeout] Таймаут вызова (опционально)
  /// Возвращает ответ сервера
  Future<TResponse> call(TRequest request, {Duration? timeout}) async {
    // Создаем новый stream для этого вызова
    final streamId = _transport.createStream();

    _logger?.info(
      'Унарный вызов $_methodPath начат [streamId: $streamId]',
    );

    final completer = Completer<TResponse>();
    StreamSubscription? subscription;

    try {
      // Подписываемся на ответы для этого stream
      _logger?.debug('Настройка подписки на ответы [streamId: $streamId]');
      subscription = _transport.getMessagesForStream(streamId).listen(
        (message) async {
          if (!message.isMetadataOnly && message.payload != null) {
            // Получили данные ответа
            _logger?.debug(
              'Получено сообщение от транспорта размером: ${message.payload!.length} байт [streamId: $streamId]',
            );
            try {
              // Используем парсер для извлечения сообщений из фрейма с префиксом
              final messages = _parser(message.payload!);
              _logger?.debug(
                  'Парсер извлек ${messages.length} сообщений из фрейма [streamId: $streamId]');

              for (final msgBytes in messages) {
                _logger?.debug(
                    'Десериализация ответа размером ${msgBytes.length} байт [streamId: $streamId]');
                final response = _responseSerializer.deserialize(msgBytes);
                if (!completer.isCompleted) {
                  _logger?.info(
                      'Унарный вызов $_methodPath успешно завершен [streamId: $streamId]');
                  completer.complete(response);
                  break; // Для унарного вызова нужен только первый ответ
                } else {
                  _logger?.warning(
                      'Получен лишний ответ после завершения вызова [streamId: $streamId]');
                }
              }
            } catch (e, stackTrace) {
              if (!completer.isCompleted) {
                _logger?.error(
                    'Ошибка при обработке ответа [streamId: $streamId]',
                    error: e,
                    stackTrace: stackTrace);
                completer.completeError(e);
              }
            }
          } else if (message.isMetadataOnly && message.metadata != null) {
            // Получили метаданные (возможно трейлеры)
            _logger?.debug('Получены метаданные [streamId: $streamId]');
            final statusCode = message.metadata!
                .getHeaderValue(RpcConstants.GRPC_STATUS_HEADER);

            if (statusCode != null && message.isEndOfStream) {
              final code = int.parse(statusCode);
              _logger?.debug(
                  'Получен статус завершения: $code [streamId: $streamId]');
              if (code != RpcStatus.OK && !completer.isCompleted) {
                final errorMessage = message.metadata!
                        .getHeaderValue(RpcConstants.GRPC_MESSAGE_HEADER) ??
                    '';
                _logger?.error(
                    'Ошибка gRPC: $code - $errorMessage [streamId: $streamId]');
                completer.completeError(
                    Exception('gRPC error $code: $errorMessage'));
              }
            }
          }
        },
        onError: (error, stackTrace) {
          _logger?.error('Ошибка от транспорта [streamId: $streamId]',
              error: error, stackTrace: stackTrace);
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Отправляем метаданные инициализации
      _logger?.debug('Отправка начальных метаданных [streamId: $streamId]');
      await _transport.sendMetadata(
        streamId,
        RpcMetadata.forClientRequest(_serviceName, _methodName),
      );

      // Сериализуем и отправляем запрос
      _logger?.debug('Сериализация запроса [streamId: $streamId]');
      final serializedRequest = _requestSerializer.serialize(request);
      _logger?.debug(
          'Запрос сериализован, размер: ${serializedRequest.length} байт [streamId: $streamId]');
      final framedRequest = RpcMessageFrame.encode(serializedRequest);
      _logger?.debug(
          'Отправка запроса и закрытие потока запросов [streamId: $streamId]');
      await _transport.sendMessage(
        streamId,
        framedRequest,
        endStream: true,
      );

      // Ждем ответ с таймаутом, если указан
      if (timeout != null) {
        _logger?.debug(
            'Установлен таймаут ожидания ответа: $timeout [streamId: $streamId]');
        return await completer.future.timeout(timeout, onTimeout: () {
          _logger?.error(
              'Тайм-аут ожидания ответа: $timeout [streamId: $streamId]');
          throw TimeoutException('Call timeout: $timeout', timeout);
        });
      } else {
        return await completer.future;
      }
    } catch (e, stackTrace) {
      _logger?.error(
          'Ошибка при выполнении унарного вызова $_methodPath [streamId: $streamId]',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      // В любом случае отписываемся от потока ответов
      _logger?.debug('Отмена подписки на ответы [streamId: $streamId]');
      await subscription?.cancel();
    }
  }

  /// Закрывает клиент и освобождает ресурсы
  ///
  /// ВНИМАНИЕ: Не закрывает транспорт, так как он может использоваться
  /// другими клиентами. Транспорт должен закрываться явно.
  Future<void> close() async {
    // Клиент не владеет транспортом, поэтому не закрываем его
    _logger?.info('Унарный клиент $_methodPath закрыт');
  }
}

/// Серверная часть унарного вызова с поддержкой Stream ID.
///
/// Обрабатывает один запрос и отправляет один ответ.
/// Предоставляет простой API для реализации обработчиков унарных RPC методов.
/// Поддерживает автоматическое мультиплексирование по serviceName/methodName и Stream ID.
///
/// Пример использования:
/// ```dart
/// final server = UnaryServer<String, String>(
///   transport: transport,
///   serviceName: 'GreetingService',
///   methodName: 'SayHello',
///   requestSerializer: stringSerializer,
///   responseSerializer: stringSerializer,
///   handler: (request) async {
///     return "Эхо: $request";
///   }
/// );
/// ```
final class UnaryResponder<TRequest, TResponse> {
  /// Транспорт для коммуникации
  final IRpcTransport _transport;

  /// Имя сервиса
  final String _serviceName;

  /// Имя метода
  final String _methodName;

  /// Путь метода в формате /<ServiceName>/<MethodName>
  late final String _methodPath;

  /// Сериализатор запросов
  final IRpcSerializer<TRequest> _requestSerializer;

  /// Сериализатор ответов
  final IRpcSerializer<TResponse> _responseSerializer;

  /// Логгер
  late final RpcLogger? _logger;

  /// Парсер для обработки фрагментированных сообщений
  late final RpcMessageParser _parser;

  /// Подписка на входящие сообщения
  StreamSubscription? _subscription;

  /// Создает сервер унарного вызова
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "GreetingService")
  /// [methodName] Имя метода (например, "SayHello")
  /// [requestSerializer] Кодек для десериализации запроса
  /// [responseSerializer] Кодек для сериализации ответа
  /// [handler] Функция-обработчик, вызываемая при получении запроса
  /// [logger] Опциональный логгер
  UnaryResponder({
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    required FutureOr<TResponse> Function(TRequest request) handler,
    RpcLogger? logger,
  })  : _transport = transport,
        _serviceName = serviceName,
        _methodName = methodName,
        _requestSerializer = requestSerializer,
        _responseSerializer = responseSerializer {
    _logger = logger?.child('UnaryResponder');
    _parser = RpcMessageParser(logger: _logger);
    _methodPath = '/$_serviceName/$_methodName';
    _logger?.info('Создан унарный сервер для $_methodPath');
    _setupRequestHandler(handler);
  }

  void _setupRequestHandler(
    FutureOr<TResponse> Function(TRequest) handler,
  ) {
    _logger?.debug('Настройка обработчика запросов для $_methodPath');

    // Отслеживаем активные streams для этого метода
    final Map<int, bool> streamRequestHandled = <int, bool>{};
    final Map<int, bool> streamInitialHeadersSent = <int, bool>{};
    final Map<int, bool> streamBelongsToThisMethod = <int, bool>{};

    _subscription = _transport.incomingMessages.listen(
      (message) async {
        final streamId = message.streamId;

        // Если это метаданные, проверяем принадлежность к нашему методу
        if (message.isMetadataOnly && message.metadata != null) {
          if (message.methodPath == _methodPath) {
            streamBelongsToThisMethod[streamId] = true;
            _logger?.debug(
                'Унарный сервер: stream $streamId привязан к методу $_methodPath');
          }
          return; // Метаданные только регистрируем, но не обрабатываем
        }

        // Для сообщений с данными проверяем принадлежность к нашему методу
        if (!streamBelongsToThisMethod.containsKey(streamId)) {
          return; // Этот stream не для нашего метода
        }

        if (streamRequestHandled[streamId] == true) {
          // Игнорируем дополнительные сообщения после обработки первого запроса
          _logger?.debug(
              'Игнорируем дополнительное сообщение для stream $streamId (запрос уже обработан)');
          return;
        }

        if (!message.isMetadataOnly && message.payload != null) {
          streamRequestHandled[streamId] = true;
          _logger
              ?.info('Получен запрос для $_methodPath [streamId: $streamId]');

          try {
            // Отправляем начальные заголовки, если еще не отправляли
            if (streamInitialHeadersSent[streamId] != true) {
              _logger?.debug(
                  'Отправка начальных заголовков [streamId: $streamId]');
              await _transport.sendMetadata(
                streamId,
                RpcMetadata.forServerInitialResponse(),
              );
              streamInitialHeadersSent[streamId] = true;
            }

            // Десериализуем запрос
            // Используем парсер для извлечения сообщений из фрейма с префиксом
            _logger?.debug(
                'Парсинг фрейма запроса размером ${message.payload!.length} байт [streamId: $streamId]');
            final messages = _parser(message.payload!);
            if (messages.isEmpty) {
              _logger?.error(
                  'Не удалось извлечь сообщение из payload [streamId: $streamId]');
              throw Exception('Не удалось извлечь сообщение из payload');
            }

            _logger?.debug('Десериализация запроса [streamId: $streamId]');
            final request = _requestSerializer.deserialize(messages.first);

            _logger?.debug(
                'Обработка запроса для $_methodPath [streamId: $streamId]');

            // Обрабатываем запрос
            final response = await handler(request);
            _logger?.debug(
                'Запрос обработан, подготовка ответа [streamId: $streamId]');

            // Сериализуем и отправляем ответ
            _logger?.debug('Сериализация ответа [streamId: $streamId]');
            final serializedResponse = _responseSerializer.serialize(response);
            _logger?.debug(
                'Ответ сериализован, размер: ${serializedResponse.length} байт [streamId: $streamId]');
            final framedResponse = RpcMessageFrame.encode(serializedResponse);
            _logger?.debug('Отправка ответа [streamId: $streamId]');
            await _transport.sendMessage(
              streamId,
              framedResponse,
            );

            // Отправляем трейлер с успешным статусом
            _logger?.debug(
                'Отправка трейлера с успешным статусом [streamId: $streamId]');
            await _transport.sendMetadata(
              streamId,
              RpcMetadata.forTrailer(RpcStatus.OK),
              endStream: true,
            );

            _logger?.info(
                'Ответ успешно отправлен для $_methodPath [streamId: $streamId]');
          } catch (e, stackTrace) {
            _logger?.error(
              'Ошибка при обработке запроса [streamId: $streamId]',
              error: e,
              stackTrace: stackTrace,
            );

            // Отправляем начальные заголовки, если еще не отправляли
            if (streamInitialHeadersSent[streamId] != true) {
              await _transport.sendMetadata(
                streamId,
                RpcMetadata.forServerInitialResponse(),
              );
              streamInitialHeadersSent[streamId] = true;
            }

            // При ошибке отправляем трейлер с кодом ошибки
            _logger?.debug('Отправка трейлера с ошибкой [streamId: $streamId]');
            await _transport.sendMetadata(
              streamId,
              RpcMetadata.forTrailer(
                RpcStatus.INTERNAL,
                message: 'Ошибка при обработке запроса: $e',
              ),
              endStream: true,
            );
          } finally {
            // Очищаем состояние для этого stream
            _logger?.debug('Очистка состояния для stream $streamId');
            streamRequestHandled.remove(streamId);
            streamInitialHeadersSent.remove(streamId);
            streamBelongsToThisMethod.remove(streamId);
          }
        }

        // Если клиент закрыл поток без отправки данных
        if (message.isEndOfStream &&
            streamBelongsToThisMethod[streamId] == true &&
            streamRequestHandled[streamId] != true) {
          streamRequestHandled[streamId] = true;
          _logger?.warning(
              'Клиент закрыл поток без отправки данных [streamId: $streamId]');

          // Отправляем трейлер с ошибкой
          await _transport.sendMetadata(
            streamId,
            RpcMetadata.forTrailer(
              RpcStatus.INVALID_ARGUMENT,
              message: 'Запрос не получен: поток закрыт без данных',
            ),
            endStream: true,
          );

          // Очищаем состояние для этого stream
          streamRequestHandled.remove(streamId);
          streamInitialHeadersSent.remove(streamId);
          streamBelongsToThisMethod.remove(streamId);
        }
      },
      onError: (error, stackTrace) async {
        _logger?.error(
          'Ошибка в транспорте для $_methodPath',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// Закрывает сервер и освобождает ресурсы
  ///
  /// ВНИМАНИЕ: Не закрывает транспорт, так как он может использоваться
  /// другими серверами. Транспорт должен закрываться явно.
  Future<void> close() async {
    _logger?.info('Закрытие унарного сервера $_methodPath');
    await _subscription?.cancel();
    _logger?.debug('Отменена подписка на входящие сообщения');
  }
}
