part of '../_index.dart';

/// Клиентская часть унарного вызова.
///
/// Позволяет отправить один запрос и получить один ответ.
/// Максимально упрощенная версия RPC для случая "запрос-ответ".
///
/// Пример использования:
/// ```dart
/// final client = UnaryClient<String, String>(
///   transport: clientTransport,
///   requestSerializer: stringSerializer,
///   responseSerializer: stringSerializer,
/// );
///
/// // Выполняем вызов и получаем результат
/// final response = await client.call("Привет, сервер!");
/// print("Получен ответ: $response");
/// ```
final class UnaryClient<TRequest, TResponse> {
  /// Транспорт для коммуникации
  final IRpcTransport _transport;

  /// Сериализатор запросов
  final IRpcSerializer<TRequest> _requestSerializer;

  /// Сериализатор ответов
  final IRpcSerializer<TResponse> _responseSerializer;

  /// Логгер
  final RpcLogger? _logger;

  /// Создает клиент унарного вызова
  ///
  /// [transport] Транспортный уровень
  /// [requestSerializer] Кодек для сериализации запроса
  /// [responseSerializer] Кодек для десериализации ответа
  /// [logger] Опциональный логгер
  UnaryClient({
    required IRpcTransport transport,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    RpcLogger? logger,
  })  : _transport = transport,
        _requestSerializer = requestSerializer,
        _responseSerializer = responseSerializer,
        _logger = logger;

  /// Выполняет унарный вызов и возвращает результат.
  ///
  /// Отправляет один запрос и ожидает один ответ от сервера.
  /// Метод блокирует выполнение до получения ответа.
  ///
  /// [request] Объект запроса для отправки
  /// Возвращает ответ от сервера при успешном выполнении
  /// Выбрасывает исключение при ошибке выполнения или истечении таймаута
  Future<TResponse> call(TRequest request, {Duration? timeout}) async {
    // Создаем контроллер для получения ответа
    final completer = Completer<TResponse>();

    // Подписываемся на ответы от транспорта только на время этого вызова
    final subscription = _transport.incomingMessages.listen(
      (message) {
        if (!message.isMetadataOnly &&
            message.payload != null &&
            !completer.isCompleted) {
          // Получили полезную нагрузку - десериализуем и возвращаем результат
          try {
            final response = _responseSerializer.deserialize(message.payload!);
            completer.complete(response);
          } catch (e, stackTrace) {
            completer.completeError(e, stackTrace);
          }
        } else if (message.isMetadataOnly && message.metadata != null) {
          // Проверяем статус выполнения, если это трейлер
          final statusHeader =
              message.metadata!.getHeaderValue(RpcConstants.GRPC_STATUS_HEADER);
          if (statusHeader != null) {
            final statusCode = int.parse(statusHeader);
            if (statusCode != RpcStatus.OK && !completer.isCompleted) {
              // Получили ошибку
              final errorMessage = message.metadata!.getHeaderValue(
                    RpcConstants.GRPC_MESSAGE_HEADER,
                  ) ??
                  'Ошибка с кодом $statusCode';

              completer.completeError(Exception(errorMessage));
            }
          }
        }

        // Если это последнее сообщение и мы еще не получили ответ, завершаем с ошибкой
        if (message.isEndOfStream && !completer.isCompleted) {
          completer.completeError(
              Exception('Соединение закрыто без получения ответа'));
        }
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    try {
      // Сериализуем и отправляем запрос
      final serializedRequest = _requestSerializer.serialize(request);
      final framedRequest = RpcMessageFrame.encode(serializedRequest);

      // Отправляем запрос и сразу указываем, что это конец потока запросов
      await _transport.sendMessage(framedRequest, endStream: true);

      // Ожидаем ответ с таймаутом
      if (timeout != null) {
        return await completer.future.timeout(
          timeout,
          onTimeout: () => throw Exception('Таймаут вызова: $timeout'),
        );
      } else {
        return await completer.future;
      }
    } finally {
      // В любом случае отписываемся от потока ответов
      await subscription.cancel();
    }
  }

  /// Закрывает клиент и освобождает ресурсы
  Future<void> close() async {
    await _transport.close();
  }
}

/// Серверная часть унарного вызова.
///
/// Обрабатывает один запрос и отправляет один ответ.
/// Предоставляет простой API для реализации обработчиков унарных RPC методов.
///
/// Пример использования:
/// ```dart
/// final server = UnaryServer<String, String>(
///   transport: serverTransport,
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

  /// Сериализатор запросов
  final IRpcSerializer<TRequest> _requestSerializer;

  /// Сериализатор ответов
  final IRpcSerializer<TResponse> _responseSerializer;

  /// Логгер
  final RpcLogger? _logger;

  /// Подписка на входящие сообщения
  StreamSubscription? _subscription;

  /// Создает сервер унарного вызова
  ///
  /// [transport] Транспортный уровень
  /// [requestSerializer] Кодек для десериализации запроса
  /// [responseSerializer] Кодек для сериализации ответа
  /// [handler] Функция-обработчик, вызываемая при получении запроса
  /// [logger] Опциональный логгер
  UnaryServer({
    required IRpcTransport transport,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    required FutureOr<TResponse> Function(TRequest request) handler,
    RpcLogger? logger,
  })  : _transport = transport,
        _requestSerializer = requestSerializer,
        _responseSerializer = responseSerializer,
        _logger = logger {
    _setupRequestHandler(handler);
  }

  void _setupRequestHandler(
    FutureOr<TResponse> Function(TRequest) handler,
  ) {
    bool requestHandled = false;
    bool initialHeadersSent = false;

    _subscription = _transport.incomingMessages.listen(
      (message) async {
        if (requestHandled) {
          // Игнорируем все дополнительные сообщения после обработки первого запроса
          return;
        }

        if (!message.isMetadataOnly && message.payload != null) {
          requestHandled = true;

          try {
            // Отправляем начальные заголовки, если еще не отправляли
            if (!initialHeadersSent) {
              await _transport
                  .sendMetadata(RpcMetadata.forServerInitialResponse());
              initialHeadersSent = true;
            }

            // Десериализуем запрос
            final request = _requestSerializer.deserialize(message.payload!);

            // Обрабатываем запрос
            final response = await handler(request);

            // Сериализуем и отправляем ответ
            final serializedResponse = _responseSerializer.serialize(response);
            final framedResponse = RpcMessageFrame.encode(serializedResponse);
            await _transport.sendMessage(framedResponse);

            // Отправляем трейлер с успешным статусом
            await _transport.sendMetadata(
              RpcMetadata.forTrailer(RpcStatus.OK),
              endStream: true,
            );
          } catch (e, stackTrace) {
            _logger?.error(
              'Ошибка при обработке запроса',
              error: e,
              stackTrace: stackTrace,
            );

            // При ошибке отправляем трейлер с кодом ошибки
            await _transport.sendMetadata(
              RpcMetadata.forTrailer(
                RpcStatus.INTERNAL,
                message: 'Ошибка при обработке запроса: $e',
              ),
              endStream: true,
            );
          }
        }

        // Если клиент закрыл поток без отправки данных
        if (message.isEndOfStream && !requestHandled) {
          requestHandled = true;
          // Отправляем трейлер с ошибкой
          await _transport.sendMetadata(
            RpcMetadata.forTrailer(
              RpcStatus.INVALID_ARGUMENT,
              message: 'Запрос не получен: поток закрыт без данных',
            ),
            endStream: true,
          );
        }
      },
      onError: (error, stackTrace) async {
        _logger?.error(
          'Ошибка в транспорте',
          error: error,
          stackTrace: stackTrace,
        );

        if (!requestHandled) {
          requestHandled = true;

          // Отправляем трейлер с ошибкой транспорта
          await _transport.sendMetadata(
            RpcMetadata.forTrailer(
              RpcStatus.UNAVAILABLE,
              message: 'Ошибка транспорта: $error',
            ),
            endStream: true,
          );
        }
      },
    );
  }

  /// Закрывает сервер и освобождает ресурсы
  Future<void> close() async {
    await _subscription?.cancel();
    await _transport.close();
  }
}
