part of '../_index.dart';

/// Клиентская часть серверного стриминга.
///
/// Позволяет отправить один запрос и получить поток ответов.
/// В отличие от двунаправленного стрима, гарантирует отправку
/// только одного запроса с последующим завершением потока запросов.
///
/// Пример использования:
/// ```dart
/// final client = ServerStreamClient<String, String>(
///   transport: clientTransport,
///   requestSerializer: stringSerializer,
///   responseSerializer: stringSerializer,
/// );
///
/// // Отправляем один запрос и сразу завершаем поток отправки
/// await client.sendRequest("Дай мне поток данных");
///
/// // Получаем поток ответов
/// client.responses.listen((response) {
///   print("Получен ответ: ${response.payload}");
/// });
/// ```
final class ServerStreamCaller<TRequest, TResponse> {
  late final RpcLogger? _logger;

  /// Внутренний клиент двунаправленного стрима
  late final BidirectionalStreamCaller<TRequest, TResponse> _innerClient;

  /// Создает клиент серверного стриминга
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "DataService")
  /// [methodName] Имя метода (например, "GetData")
  /// [requestSerializer] Кодек для сериализации запроса
  /// [responseSerializer] Кодек для десериализации ответов
  /// [logger] Опциональный логгер
  ServerStreamCaller({
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    RpcLogger? logger,
  }) {
    _logger = logger?.child('ServerCaller');
    _innerClient = BidirectionalStreamCaller<TRequest, TResponse>(
      transport: transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );
  }

  /// Поток ответов от сервера
  ///
  /// Предоставляет доступ к потоку ответов, получаемых от сервера.
  /// Поток завершается, когда сервер завершает отправку ответов
  /// или при возникновении ошибки.
  Stream<RpcMessage<TResponse>> get responses => _innerClient.responses;

  /// Отправляет единственный запрос и завершает поток
  ///
  /// В отличие от двунаправленного стрима, этот метод автоматически
  /// завершает поток запросов после отправки единственного запроса.
  ///
  /// [request] Объект запроса для отправки
  Future<void> send(TRequest request) async {
    await _innerClient.send(request);
    await _innerClient.finishSending();
  }

  /// Закрывает стрим и освобождает ресурсы
  ///
  /// Полностью завершает стрим, освобождая все ресурсы.
  Future<void> close() async => await _innerClient.close();
}

/// Серверная часть серверного стриминга.
///
/// Получает один запрос и отправляет поток ответов.
/// Автоматически извлекает первый запрос из потока и вызывает
/// пользовательский обработчик, игнорируя все последующие запросы.
///
/// Пример использования:
/// ```dart
/// final server = ServerStreamServer<String, String>(
///   transport: serverTransport,
///   requestSerializer: stringSerializer,
///   responseSerializer: stringSerializer,
///   handler: (request, responder) {
///     // Обработка запроса
///     for (int i = 0; i < 5; i++) {
///       responder.sendResponse("Данные #$i");
///     }
///     responder.complete();
///   }
/// );
/// ```
final class ServerStreamResponder<TRequest, TResponse> {
  late final RpcLogger? _logger;

  /// Внутренний сервер двунаправленного стрима
  late final BidirectionalStreamResponder<TRequest, TResponse> _innerServer;

  /// Подписка на входящие запросы
  StreamSubscription? _subscription;

  /// Создает сервер серверного стриминга
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "DataService")
  /// [methodName] Имя метода (например, "GetData")
  /// [requestSerializer] Кодек для десериализации запроса
  /// [responseSerializer] Кодек для сериализации ответов
  /// [handler] Функция-обработчик, вызываемая при получении запроса
  /// [logger] Опциональный логгер
  ServerStreamResponder({
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    required void Function(
      TRequest request,
      // ignore: library_private_types_in_public_api
      _ServerStreamResponderInternal<TResponse> responder,
    ) handler,
    RpcLogger? logger,
  }) {
    _logger = logger?.child('ServerResponder');
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
    void Function(TRequest, _ServerStreamResponderInternal<TResponse>) handler,
  ) async {
    bool requestHandled = false;

    _subscription = _innerServer.requests.listen((request) async {
      if (!requestHandled) {
        requestHandled = true;
        final responder =
            _ServerStreamResponderInternal<TResponse>(_innerServer);
        try {
          // Оборачиваем handler в Future для правильной обработки sync/async исключений
          await Future.sync(() => handler(request, responder));
        } catch (e) {
          // Если обработчик бросает исключение (синхронно или асинхронно), отправляем ошибку
          await responder.completeWithError(RpcStatus.INTERNAL, e.toString());
        }
      }
      // Игнорируем все дополнительные запросы
    });
  }

  /// Закрывает стрим и освобождает ресурсы
  ///
  /// Полностью завершает стрим, освобождая все ресурсы.
  Future<void> close() async {
    await _subscription?.cancel();
    await _innerServer.close();
  }
}

/// Вспомогательный класс для отправки ответов в серверном стриминге
///
/// Предоставляет удобный API для отправки нескольких ответов
/// в рамках обработчика серверного стриминга.
final class _ServerStreamResponderInternal<TResponse> {
  final BidirectionalStreamResponder<dynamic, TResponse> _server;

  /// Создает объект ответчика, связанный с сервером
  _ServerStreamResponderInternal(this._server);

  /// Отправляет ответ в поток
  ///
  /// [response] Объект ответа для отправки
  Future<void> send(TResponse response) async {
    await _server.send(response);
  }

  /// Завершает поток ответов с успешным статусом
  Future<void> complete() async {
    await _server.finishReceiving();
  }

  /// Завершает поток с ошибкой
  ///
  /// [statusCode] Код ошибки gRPC (см. GrpcStatus)
  /// [message] Текстовое сообщение с описанием ошибки
  Future<void> completeWithError(int statusCode, String message) async {
    await _server.sendError(statusCode, message);
  }
}
