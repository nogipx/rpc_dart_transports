part of '_method.dart';

/// Класс для работы с RPC методом типа "серверный стриминг" (один запрос - поток ответов)
final class ServerStreamingRpcMethod<T extends RpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект серверного стриминг RPC метода
  ServerStreamingRpcMethod(
      RpcEndpoint<T> endpoint, String serviceName, String methodName)
      : super(endpoint, serviceName, methodName);

  /// Открывает поток данных от сервера
  ///
  /// [request] - запрос для открытия потока
  /// [metadata] - метаданные (опционально)
  /// [streamId] - ID потока (опционально, генерируется автоматически)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  Stream<Response> openStream<Request extends T, Response extends T>(
    Request request, {
    Map<String, dynamic>? metadata,
    String? streamId,
    Response Function(Map<String, dynamic>)? responseParser,
  }) {
    final effectiveStreamId = streamId ?? generateUniqueId('stream');
    final dynamicRequest = request is RpcMessage ? request.toJson() : request;

    final stream = endpoint.openStream(
      serviceName,
      methodName,
      request: dynamicRequest,
      metadata: metadata,
      streamId: effectiveStreamId,
    );

    if (responseParser != null) {
      return stream.map((data) {
        if (data is Map<String, dynamic>) {
          return responseParser(data);
        }
        return data as Response;
      });
    }

    return stream.cast<Response>();
  }

  /// Регистрирует обработчик серверного стриминг метода
  ///
  /// [handler] - функция обработки запроса, возвращающая поток ответов
  /// [requestParser] - функция преобразования JSON в объект запроса (опционально)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  void register<Request extends T, Response extends T>({
    required Stream<Response> Function(Request) handler,
    Request Function(Map<String, dynamic>)? requestParser,
    Response Function(Map<String, dynamic>)? responseParser,
  }) {
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.serverStreaming);
    final implementation =
        RpcMethodImplementation.serverStream(contract, handler);

    endpoint.registerMethodImplementation(
        serviceName, methodName, implementation);

    // Регистрируем низкоуровневый обработчик
    endpoint.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        try {
          // Конвертируем запрос в типизированный, если нужно
          final typedRequest =
              (context.payload is Map<String, dynamic> && requestParser != null)
                  ? requestParser(context.payload)
                  : context.payload;

          // Получаем ID сообщения из контекста
          final messageId = context.messageId;

          // Запускаем обработку стрима в фоновом режиме
          _activateStreamHandler(
            messageId,
            typedRequest,
            implementation,
            responseParser,
          );

          // Возвращаем только подтверждение принятия запроса
          return {'status': 'streaming'};
        } catch (e) {
          rethrow;
        }
      },
    );
  }

  /// Активирует обработчик стрима и связывает его с транспортом
  void _activateStreamHandler<Request, Response>(
    String messageId,
    Request request,
    RpcMethodImplementation<Request, Response> implementation,
    Response Function(Map<String, dynamic>)? responseParser,
  ) {
    // Запускаем стрим от обработчика
    final stream = implementation.openStream(request);

    // Подписываемся на события и пересылаем их через публичный API Endpoint
    stream.listen((data) {
      // Преобразуем данные и отправляем их в поток
      final processedData = data is RpcMessage ? data.toJson() : data;

      endpoint.sendStreamData(
        messageId,
        processedData,
        serviceName: serviceName,
        methodName: methodName,
      );
    }, onError: (error) {
      // Отправляем ошибку
      endpoint.sendStreamError(
        messageId,
        error.toString(),
      );
    }, onDone: () {
      // Закрываем стрим с указанием serviceName и methodName для middleware
      endpoint.closeStream(
        messageId,
        serviceName: serviceName,
        methodName: methodName,
      );
    });
  }
}
