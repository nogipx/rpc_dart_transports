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
final class ClientStreamClient<TRequest, TResponse> {
  /// Внутренний клиент двунаправленного стрима
  final BidirectionalStreamClient<TRequest, TResponse> _innerClient;

  /// Обещание с результатом запроса
  late final Completer<TResponse> _responseCompleter = Completer<TResponse>();

  /// Подписка на поток ответов
  StreamSubscription? _subscription;

  /// Создает клиент клиентского стриминга
  ///
  /// [transport] Транспортный уровень
  /// [requestSerializer] Кодек для сериализации запросов
  /// [responseSerializer] Кодек для десериализации ответа
  /// [logger] Опциональный логгер
  ClientStreamClient({
    required IRpcTransport transport,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    RpcLogger? logger,
  }) : _innerClient = BidirectionalStreamClient<TRequest, TResponse>(
          transport: transport,
          requestSerializer: requestSerializer,
          responseSerializer: responseSerializer,
          logger: logger,
        ) {
    unawaited(_setupResponseHandler());
  }

  Future<void> _setupResponseHandler() async {
    _subscription = _innerClient.responses.listen(
      (response) {
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
final class ClientStreamServer<TRequest, TResponse> {
  /// Внутренний сервер двунаправленного стрима
  final BidirectionalStreamServer<TRequest, TResponse> _innerServer;

  /// Создает сервер клиентского стриминга
  ///
  /// [transport] Транспортный уровень
  /// [requestSerializer] Кодек для десериализации запросов
  /// [responseSerializer] Кодек для сериализации ответа
  /// [handler] Функция-обработчик, вызываемая для обработки потока запросов
  /// [logger] Опциональный логгер
  ClientStreamServer({
    required IRpcTransport transport,
    required IRpcSerializer<TRequest> requestSerializer,
    required IRpcSerializer<TResponse> responseSerializer,
    required Future<TResponse> Function(Stream<TRequest> requests) handler,
    RpcLogger? logger,
  }) : _innerServer = BidirectionalStreamServer<TRequest, TResponse>(
          transport: transport,
          requestSerializer: requestSerializer,
          responseSerializer: responseSerializer,
          logger: logger,
        ) {
    unawaited(_setupRequestHandler(handler));
  }

  Future<void> _setupRequestHandler(
    Future<TResponse> Function(Stream<TRequest> requests) handler,
  ) async {
    try {
      final response = await handler(_innerServer.requests);
      await _innerServer.send(response);
      await _innerServer.finishReceiving();
    } catch (e) {
      await _innerServer.sendError(RpcStatus.INTERNAL, e.toString());
    }
  }

  /// Закрывает стрим и освобождает ресурсы
  ///
  /// Полностью завершает стрим, освобождая все ресурсы.
  Future<void> close() async => await _innerServer.close();
}
