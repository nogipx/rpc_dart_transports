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
final class UnaryClient<TRequest, TResponse> {
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
  final RpcLogger? _logger;

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
  UnaryClient({
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
        _logger = logger,
        _parser = RpcMessageParser(logger: logger) {
    _methodPath = '/$_serviceName/$_methodName';
  }

  /// Выполняет унарный вызов
  ///
  /// [request] Объект запроса
  /// [timeout] Таймаут вызова (опционально)
  /// Возвращает ответ сервера
  Future<TResponse> call(TRequest request, {Duration? timeout}) async {
    // Создаем новый stream для этого вызова
    final streamId = _transport.createStream();

    _logger?.debug(
      'UnaryClient: начинаем вызов $_methodPath на stream $streamId',
    );

    final completer = Completer<TResponse>();
    StreamSubscription? subscription;

    try {
      // Подписываемся на ответы для этого stream
      subscription = _transport.getMessagesForStream(streamId).listen(
        (message) async {
          if (!message.isMetadataOnly && message.payload != null) {
            // Получили данные ответа
            try {
              // Используем парсер для извлечения сообщений из фрейма с префиксом
              final messages = _parser(message.payload!);
              for (final msgBytes in messages) {
                final response = _responseSerializer.deserialize(msgBytes);
                if (!completer.isCompleted) {
                  completer.complete(response);
                  break; // Для унарного вызова нужен только первый ответ
                }
              }
            } catch (e) {
              if (!completer.isCompleted) {
                completer.completeError(e);
              }
            }
          } else if (message.isMetadataOnly && message.metadata != null) {
            // Получили метаданные (возможно трейлеры)
            final statusCode = message.metadata!
                .getHeaderValue(RpcConstants.GRPC_STATUS_HEADER);

            if (statusCode != null && message.isEndOfStream) {
              final code = int.parse(statusCode);
              if (code != RpcStatus.OK && !completer.isCompleted) {
                final errorMessage = message.metadata!
                        .getHeaderValue(RpcConstants.GRPC_MESSAGE_HEADER) ??
                    '';
                completer.completeError(
                    Exception('gRPC error $code: $errorMessage'));
              }
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Отправляем метаданные инициализации
      await _transport.sendMetadata(
        streamId,
        RpcMetadata.forClientRequest(_serviceName, _methodName),
      );

      // Сериализуем и отправляем запрос
      final serializedRequest = _requestSerializer.serialize(request);
      final framedRequest = RpcMessageFrame.encode(serializedRequest);
      await _transport.sendMessage(
        streamId,
        framedRequest,
        endStream: true,
      );

      // Ждем ответ с таймаутом, если указан
      if (timeout != null) {
        return await completer.future.timeout(
          timeout,
          onTimeout: () =>
              throw TimeoutException('Call timeout: $timeout', timeout),
        );
      } else {
        return await completer.future;
      }
    } finally {
      // В любом случае отписываемся от потока ответов
      await subscription?.cancel();
    }
  }

  /// Закрывает клиент и освобождает ресурсы
  ///
  /// ВНИМАНИЕ: Не закрывает транспорт, так как он может использоваться
  /// другими клиентами. Транспорт должен закрываться явно.
  Future<void> close() async {
    // Клиент не владеет транспортом, поэтому не закрываем его
    _logger?.debug('UnaryClient: клиент закрыт');
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
final class UnaryServer<TRequest, TResponse> {
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
  final RpcLogger? _logger;

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
  UnaryServer({
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
        _responseSerializer = responseSerializer,
        _logger = logger,
        _parser = RpcMessageParser(logger: logger) {
    _methodPath = '/$_serviceName/$_methodName';
    _setupRequestHandler(handler);
  }

  void _setupRequestHandler(
    FutureOr<TResponse> Function(TRequest) handler,
  ) {
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
                'UnaryServer: stream $streamId привязан к методу $_methodPath');
          }
          return; // Метаданные только регистрируем, но не обрабатываем
        }

        // Для сообщений с данными проверяем принадлежность к нашему методу
        if (!streamBelongsToThisMethod.containsKey(streamId)) {
          return; // Этот stream не для нашего метода
        }

        if (streamRequestHandled[streamId] == true) {
          // Игнорируем дополнительные сообщения после обработки первого запроса
          return;
        }

        if (!message.isMetadataOnly && message.payload != null) {
          streamRequestHandled[streamId] = true;

          try {
            // Отправляем начальные заголовки, если еще не отправляли
            if (streamInitialHeadersSent[streamId] != true) {
              await _transport.sendMetadata(
                streamId,
                RpcMetadata.forServerInitialResponse(),
              );
              streamInitialHeadersSent[streamId] = true;
            }

            // Десериализуем запрос
            // Используем парсер для извлечения сообщений из фрейма с префиксом
            final messages = _parser(message.payload!);
            if (messages.isEmpty) {
              throw Exception('Не удалось извлечь сообщение из payload');
            }
            final request = _requestSerializer.deserialize(messages.first);

            _logger?.debug(
                'UnaryServer: обрабатываем запрос для метода $_methodPath на stream $streamId');

            // Обрабатываем запрос
            final response = await handler(request);

            // Сериализуем и отправляем ответ
            final serializedResponse = _responseSerializer.serialize(response);
            final framedResponse = RpcMessageFrame.encode(serializedResponse);
            await _transport.sendMessage(
              streamId,
              framedResponse,
            );

            // Отправляем трейлер с успешным статусом
            await _transport.sendMetadata(
              streamId,
              RpcMetadata.forTrailer(RpcStatus.OK),
              endStream: true,
            );
          } catch (e, stackTrace) {
            _logger?.error(
              'Ошибка при обработке запроса на stream $streamId',
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
    await _subscription?.cancel();
    _logger?.debug('UnaryServer: сервер $_methodPath закрыт');
  }
}
