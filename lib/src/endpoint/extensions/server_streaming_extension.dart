part of '../_index.dart';

extension ServerStreamingRpcEndpoint<T extends RpcSerializableMessage>
    on RpcEndpoint<T> {
  /// Открывает типизированный поток данных
  Stream<Response> openTypedStream<Request extends T, Response extends T>(
    String serviceName,
    String methodName,
    Request request, {
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Проверяем наличие контракта
    final contract = _getServiceContract(serviceName);
    final methodContract =
        contract.findMethodTyped<Request, Response>(methodName);

    if (methodContract == null) {
      throw ArgumentError(
          'Метод $methodName не найден в контракте сервиса $serviceName');
    }

    // Проверяем типы
    if (!methodContract.validateRequest(request)) {
      throw ArgumentError(
          'Тип запроса ${request.runtimeType} не соответствует контракту метода $methodName');
    }

    // Конвертируем запрос в JSON, если это Message
    final dynamicRequest = request is RpcMessage ? request.toJson() : request;

    // Открываем поток через базовый Endpoint (с поддержкой middleware)
    final stream = _delegate.openStream(
      serviceName,
      methodName,
      request: dynamicRequest,
      metadata: metadata,
      streamId: streamId,
    );

    // Оборачиваем поток для проверки типов
    final responseParser = contract.getResponseParser(methodContract);
    final typedController = StreamController<Response>.broadcast();

    stream.listen(
      (data) {
        try {
          final typedData = responseParser(data);
          if (methodContract.validateResponse(typedData)) {
            typedController.add(typedData);
          } else {
            typedController
                .addError('Тип данных в потоке не соответствует контракту');
          }
        } catch (e) {
          typedController.addError(e);
        }
      },
      onError: (error) => typedController.addError(error),
      onDone: () => typedController.close(),
    );

    return typedController.stream;
  }

  /// Регистрирует типизированную реализацию стримингового метода
  void registerStreamMethod<Request extends T, Response extends T>(
    String serviceName,
    String methodName,
    Stream<Response> Function(Request) handler,
    Request Function(Map<String, dynamic>)? argumentParser,
    Response Function(Map<String, dynamic>)? responseParser,
  ) {
    final contract = _getMethodContract<Request, Response>(
      serviceName,
      methodName,
      RpcMethodType.serverStreaming,
    );

    final implementation =
        RpcMethodImplementation.serverStream(contract, handler);

    _implementations[serviceName]![methodName] = implementation;

    // Регистрируем низкоуровневый обработчик
    _delegate.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        try {
          // Конвертируем запрос в типизированный, если нужно
          final typedRequest = (context.payload is Map<String, dynamic> &&
                  argumentParser != null)
              ? argumentParser(context.payload)
              : context.payload;

          // Получаем ID сообщения из контекста
          final messageId = context.messageId;

          // Запускаем обработку стрима в фоновом режиме
          _activateStreamHandler(
            messageId,
            serviceName,
            methodName,
            typedRequest,
            implementation,
            responseParser,
          );

          // Возвращаем только подтверждение принятия запроса
          // Сами данные будут отправляться через streamData сообщения при активации потока
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
      String serviceName,
      String methodName,
      Request request,
      RpcMethodImplementation<Request, Response> implementation,
      [Response Function(Map<String, dynamic>)? responseParser]) {
    // Запускаем стрим от обработчика
    final stream = implementation.openStream(request);

    // Подписываемся на события и пересылаем их через публичный API Endpoint
    stream.listen((data) {
      // Преобразуем данные и отправляем их в поток
      // Важно отправлять с указанием serviceName и methodName для middleware
      final processedData = data is RpcMessage ? data.toJson() : data;

      _delegate.sendStreamData(
        messageId,
        processedData,
        serviceName: serviceName,
        methodName: methodName,
      );
    }, onError: (error) {
      // Отправляем ошибку
      _delegate.sendStreamError(
        messageId,
        error.toString(),
      );
    }, onDone: () {
      // Закрываем стрим с указанием serviceName и methodName для middleware
      _delegate.closeStream(
        messageId,
        serviceName: serviceName,
        methodName: methodName,
      );
    });
  }
}
