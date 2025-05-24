part of '../_index.dart';

/// Клиентская часть клиентского стриминга.
///
/// Позволяет отправить поток запросов и получить один ответ.
/// В отличие от двунаправленного стрима, автоматически извлекает
/// только первый ответ из потока и предоставляет его как результат.
///
/// Пример использования:
/// ```dart
/// final client = ClientStreamClient<String, String>(
///   transport: clientTransport,
///   requestSerializer: stringSerializer,
///   responseSerializer: stringSerializer,
/// );
///
/// // Отправляем несколько запросов
/// for (int i = 0; i < 5; i++) {
///   client.sendRequest("Часть данных #$i");
/// }
///
/// // Завершаем отправку
/// client.finishRequests();
///
/// // Ждем один ответ
/// final response = await client.response;
/// print("Получен итоговый ответ: $response");
/// ```
final class ClientStreamCaller<TRequest, TResponse> {
  late final RpcLogger? _logger;

  /// Внутренний клиент двунаправленного стрима
  late final BidirectionalStreamCaller<TRequest, TResponse> _innerClient;

  /// Обещание с результатом запроса
  late final Completer<TResponse> _responseCompleter = Completer<TResponse>();

  /// Подписка на поток ответов
  StreamSubscription? _subscription;

  /// Создает клиент клиентского стриминга
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "DataService")
  /// [methodName] Имя метода (например, "ProcessData")
  /// [requestSerializer] Кодек для сериализации запросов
  /// [responseSerializer] Кодек для десериализации ответа
  /// [logger] Опциональный логгер
  ClientStreamCaller({
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    RpcLogger? logger,
  }) {
    _logger = logger?.child('ClientCaller');
    _innerClient = BidirectionalStreamCaller<TRequest, TResponse>(
      transport: transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );
    unawaited(_setupResponseHandler());
  }

  Future<void> _setupResponseHandler() async {
    _subscription = _innerClient.responses.listen(
      (response) {
        // Проверяем на ошибки в метаданных (трейлерах)
        if (response.isMetadataOnly &&
            response.metadata != null &&
            response.isEndOfStream) {
          final statusCode = response.metadata!
              .getHeaderValue(RpcConstants.GRPC_STATUS_HEADER);
          if (statusCode != null && statusCode != '0') {
            final errorMessage = response.metadata!
                    .getHeaderValue(RpcConstants.GRPC_MESSAGE_HEADER) ??
                '';
            if (!_responseCompleter.isCompleted) {
              _responseCompleter.completeError(
                  Exception('gRPC error $statusCode: $errorMessage'));
            }
            return;
          }
        }

        // Обрабатываем нормальные ответы
        if (!response.isMetadataOnly && !_responseCompleter.isCompleted) {
          _responseCompleter.complete(response.payload);
        }
      },
      onError: (error) {
        if (!_responseCompleter.isCompleted) {
          _responseCompleter.completeError(error);
        }
      },
      onDone: () {
        if (!_responseCompleter.isCompleted) {
          _responseCompleter
              .completeError(Exception('Стрим закрыт без получения ответа'));
        }
      },
    );
  }

  /// Отправляет запрос в поток
  ///
  /// [request] Объект запроса для отправки
  Future<void> send(TRequest request) async {
    await _innerClient.send(request);
  }

  /// Завершает отправку запросов
  ///
  /// Сигнализирует серверу, что клиент закончил отправку запросов.
  /// После вызова этого метода новые запросы отправлять нельзя.
  ///
  /// Предоставляет доступ к Future с единственным ответом от сервера.
  /// Если сервер отправил несколько ответов, возвращается только первый.
  /// Если сервер не отправил ни одного ответа до закрытия потока,
  /// возникает ошибка.
  Future<TResponse> finishSending() async {
    await _innerClient.finishSending();
    return await _responseCompleter.future;
  }

  /// Закрывает стрим и освобождает ресурсы
  ///
  /// Полностью завершает стрим, освобождая все ресурсы.
  Future<void> close() async {
    await _subscription?.cancel();
    await _innerClient.close();
  }
}

/// Серверная часть клиентского стриминга.
///
/// Получает поток запросов и отправляет один ответ.
/// Автоматически агрегирует все запросы и передает их обработчику,
/// который должен вернуть единственный ответ.
///
/// Пример использования:
/// ```dart
/// final server = ClientStreamServer<String, String>(
///   transport: serverTransport,
///   requestSerializer: stringSerializer,
///   responseSerializer: stringSerializer,
///   handler: (requests) async {
///     // Собираем все запросы
///     final allRequests = await requests.toList();
///     return "Обработано ${allRequests.length} запросов";
///   }
/// );
/// ```
final class ClientStreamResponder<TRequest, TResponse> {
  late final RpcLogger? _logger;

  /// Внутренний сервер двунаправленного стрима
  late final BidirectionalStreamResponder<TRequest, TResponse> _innerServer;

  /// Создает сервер клиентского стриминга
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "DataService")
  /// [methodName] Имя метода (например, "ProcessData")
  /// [requestSerializer] Кодек для десериализации запросов
  /// [responseSerializer] Кодек для сериализации ответа
  /// [handler] Функция-обработчик, вызываемая для обработки потока запросов
  /// [logger] Опциональный логгер
  ClientStreamResponder({
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    required Future<TResponse> Function(Stream<TRequest> requests) handler,
    RpcLogger? logger,
  }) {
    _logger = logger?.child('ClientResponder');
    _innerServer = BidirectionalStreamResponder<TRequest, TResponse>(
      transport: transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );
    unawaited(_setupRequestHandler(handler));
  }

  Future<void> _setupRequestHandler(
    Future<TResponse> Function(Stream<TRequest> requests) handler,
  ) async {
    // Создаем контроллер, который будет управлять потоком запросов
    final requestsController = StreamController<TRequest>();

    // Перенаправляем запросы из внутреннего сервера в контроллер
    _innerServer.requests.listen((request) => requestsController.add(request),
        onDone: () => requestsController.close(),
        onError: (e) {
          requestsController.addError(e);
          requestsController.close();
        });

    // Запускаем обработчик НЕМЕДЛЕННО (чтобы сразу поймать синхронные исключения)
    try {
      final futureResponse = handler(requestsController.stream);

      // Ждем результат асинхронно
      futureResponse.then((response) async {
        // Когда ответ готов, отправляем его
        await _innerServer.send(response);
        await _innerServer.finishReceiving();
      }).catchError((e) async {
        await _innerServer.sendError(RpcStatus.INTERNAL, e.toString());
      });
    } catch (e) {
      // Синхронное исключение - отправляем ошибку немедленно
      await _innerServer.sendError(RpcStatus.INTERNAL, e.toString());
    }
  }

  /// Закрывает стрим и освобождает ресурсы
  ///
  /// Полностью завершает стрим, освобождая все ресурсы.
  Future<void> close() async => await _innerServer.close();
}
