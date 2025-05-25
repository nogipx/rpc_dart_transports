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
  /// [requestCodec] Кодек для сериализации запроса
  /// [responseCodec] Кодек для десериализации ответов
  /// [logger] Опциональный логгер
  ServerStreamCaller({
    required IRpcTransport transport,
    required String serviceName,
    required String methodName,
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    RpcLogger? logger,
  }) {
    _logger = logger?.child('ServerCaller');
    _innerClient = BidirectionalStreamCaller<TRequest, TResponse>(
      transport: transport,
      serviceName: serviceName,
      methodName: methodName,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
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
