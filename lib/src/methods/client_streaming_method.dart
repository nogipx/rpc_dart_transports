part of '_method.dart';

/// Класс для работы с RPC методом типа "клиентский стриминг" (поток запросов - один ответ)
final class ClientStreamingRpcMethod<T extends RpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект клиентского стриминг RPC метода
  ClientStreamingRpcMethod(
      RpcEndpoint<T> endpoint, String serviceName, String methodName)
      : super(endpoint, serviceName, methodName);

  /// Открывает поток для отправки данных на сервер
  ///
  /// [metadata] - метаданные (опционально)
  /// [streamId] - ID потока (опционально, генерируется автоматически)
  /// [requestParser] - функция преобразования объекта запроса в JSON (опционально)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  ///
  /// Возвращает тюпл из потока для отправки и Future для получения результата
  (StreamController<Request>, Future<Response>)
      openClientStream<Request extends T, Response extends T>({
    Map<String, dynamic>? metadata,
    String? streamId,
    Request Function(Map<String, dynamic>)? requestParser,
    Response Function(Map<String, dynamic>)? responseParser,
  }) {
    final effectiveStreamId = streamId ?? generateUniqueId('stream');

    // Создаем контроллер для отправки данных
    final controller = StreamController<Request>();

    // Комплитер для ожидания финального ответа
    final completer = Completer<Response>();

    // Открываем базовый стрим
    endpoint
        .openStream(
      serviceName,
      methodName,
      metadata: metadata,
      streamId: effectiveStreamId,
    )
        .listen((data) {
      // Финальный ответ приходит как последнее сообщение стрима
      if (!completer.isCompleted) {
        if (data is Map<String, dynamic> && responseParser != null) {
          completer.complete(responseParser(data));
        } else {
          completer.complete(data as Response);
        }
      }
    }, onError: (error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    // Подписываемся на контроллер и отправляем данные
    controller.stream.listen((data) {
      final processedData = data is RpcMessage ? data.toJson() : data;

      endpoint.sendStreamData(
        effectiveStreamId,
        processedData,
        serviceName: serviceName,
        methodName: methodName,
      );
    }, onDone: () {
      // Когда поток запросов закончен, отправляем маркер завершения
      endpoint.sendStreamData(
        effectiveStreamId,
        {'_clientStreamEnd': true},
        serviceName: serviceName,
        methodName: methodName,
      );

      // Закрываем клиентскую часть стрима
      endpoint.closeStream(
        effectiveStreamId,
        serviceName: serviceName,
        methodName: methodName,
      );
    });

    return (controller, completer.future);
  }

  /// Регистрирует обработчик клиентского стриминг метода
  ///
  /// [handler] - функция обработки потока запросов, возвращающая один ответ
  /// [requestParser] - функция преобразования JSON в объект запроса (опционально)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  void register<Request extends T, Response extends T>({
    required Future<Response> Function(Stream<Request>) handler,
    Request Function(Map<String, dynamic>)? requestParser,
    Response Function(Map<String, dynamic>)? responseParser,
  }) {
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.clientStreaming);
    final implementation =
        RpcMethodImplementation.clientStream(contract, handler);

    endpoint.registerMethodImplementation(
        serviceName, methodName, implementation);

    // Регистрируем низкоуровневый обработчик
    endpoint.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        // Получаем ID сообщения из контекста
        final messageId = context.messageId;

        // Создаем контроллер для входящих запросов
        final controller = StreamController<Request>();

        // Открываем входящий поток и преобразуем его к типу Request
        final incomingStream = endpoint.openStream(
          serviceName,
          methodName,
          streamId: messageId,
        );

        // Подписываемся на входящий поток
        incomingStream.listen((data) {
          // Проверяем маркер конца клиентского стрима
          if (data is Map<String, dynamic> &&
              data['_clientStreamEnd'] == true) {
            // Получили маркер завершения, закрываем контроллер
            controller.close();
            return;
          }

          // Преобразуем данные и добавляем в контроллер
          if (data is Map<String, dynamic> && requestParser != null) {
            controller.add(requestParser(data));
          } else {
            controller.add(data as Request);
          }
        }, onError: (error) {
          controller.addError(error);
        }, onDone: () {
          // Поток закрыт, закрываем контроллер
          if (!controller.isClosed) {
            controller.close();
          }
        });

        try {
          // Вызываем обработчик с потоком запросов
          final response =
              await implementation.handleClientStream(controller.stream);

          // Преобразуем результат и отправляем как последнее сообщение стрима
          final result = response is RpcMessage ? response.toJson() : response;

          endpoint.sendStreamData(
            messageId,
            result,
            serviceName: serviceName,
            methodName: methodName,
          );

          // Закрываем стрим
          endpoint.closeStream(
            messageId,
            serviceName: serviceName,
            methodName: methodName,
          );

          // Возвращаем подтверждение, что стрим обрабатывается
          return {'status': 'streaming'};
        } catch (e) {
          // В случае ошибки, отправляем её и закрываем стрим
          endpoint.sendStreamError(messageId, e.toString());
          endpoint.closeStream(messageId);
          rethrow;
        }
      },
    );
  }
}
