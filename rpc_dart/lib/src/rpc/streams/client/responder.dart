part of '../_index.dart';

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
final class ClientStreamResponder<TRequest, TResponse>
    implements IRpcResponder {
  late final RpcLogger? _logger;

  @override
  final int id;

  /// Внутренний сервер двунаправленного стрима
  late final BidirectionalStreamResponder<TRequest, TResponse> _innerServer;

  /// Создает сервер клиентского стриминга
  ///
  /// [transport] Транспортный уровень
  /// [serviceName] Имя сервиса (например, "DataService")
  /// [methodName] Имя метода (например, "ProcessData")
  /// [requestCodec] Кодек для десериализации запросов
  /// [responseCodec] Кодек для сериализации ответа
  /// [handler] Функция-обработчик, вызываемая для обработки потока запросов
  /// [logger] Опциональный логгер
  ClientStreamResponder({
    this.id = 0,
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    required Future<TResponse> Function(Stream<TRequest> requests) handler,
    RpcLogger? logger,
  }) {
    _logger = logger?.child('ClientResponder');
    _innerServer = BidirectionalStreamResponder<TRequest, TResponse>(
      id: id,
      transport: transport,
      serviceName: serviceName,
      methodName: methodName,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
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
