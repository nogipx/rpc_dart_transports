part of '../_index.dart';

/// Расширение для RpcEndpoint с методами для удобной работы с двунаправленными каналами
extension BidirectionalRpcEndpoint<T extends RpcSerializableMessage>
    on RpcEndpoint<T> {
  /// Создает типизированный двунаправленный канал связи
  ///
  /// [Request] - тип исходящих сообщений
  /// [Response] - тип входящих сообщений
  /// [serviceName] - название сервиса
  /// [methodName] - название метода
  /// [requestParser] - функция для преобразования JSON в объект запроса
  /// [responseParser] - функция для преобразования JSON в объект ответа
  /// [metadata] - дополнительные метаданные
  /// [streamId] - необязательный идентификатор стрима (генерируется автоматически)
  TypedBidirectionalChannel<Request, Response>
      createBidirectionalChannel<Request extends T, Response extends T>({
    required String serviceName,
    required String methodName,
    required Request Function(Map<String, dynamic>)? requestParser,
    required Response Function(Map<String, dynamic>)? responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Генерируем ID стрима если не указан
    final effectiveStreamId = streamId ?? _generateUniqueId('stream');

    // Создаем контроллер для исходящих сообщений
    final outgoingController = StreamController<Request>();

    // Инициируем соединение
    invoke(
      serviceName,
      methodName,
      {'_bidirectional': true},
      metadata: metadata,
    );

    // Трансформируем входящий поток, применяя parser
    Stream<Response> typedIncomingStream;
    if (responseParser != null) {
      typedIncomingStream = openStream(
        serviceName,
        methodName,
        streamId: effectiveStreamId,
      ).map((data) {
        if (data is Map<String, dynamic>) {
          // Проверяем маркер конца стрима
          if (data['_clientStreamEnd'] == true) {
            // Пропускаем маркер завершения
            throw StateError('StreamEnd');
          }
          try {
            return responseParser(data);
          } catch (e) {
            // В случае ошибки преобразования, логируем через метаданные для middleware
            sendStreamData(
              effectiveStreamId,
              null,
              metadata: {
                '_error': 'Ошибка преобразования: $e',
                '_level': 'warning'
              },
              serviceName: serviceName,
              methodName: methodName,
            );
            return data as Response;
          }
        } else {
          return data as Response;
        }
      }).handleError((error) {
        // Игнорируем ошибки маркера завершения стрима
        if (error is StateError && error.message == 'StreamEnd') {
          return;
        }
        // Другие ошибки пробрасываем дальше
        throw error;
      });
    } else {
      typedIncomingStream = openStream(
        serviceName,
        methodName,
        streamId: effectiveStreamId,
      ).where((data) {
        // Фильтруем маркеры завершения стрима
        if (data is Map<String, dynamic> && data['_clientStreamEnd'] == true) {
          return false;
        }
        return true;
      }).cast<Response>();
    }

    // Подписываемся на исходящий поток и пересылаем сообщения
    outgoingController.stream.listen(
      (data) {
        sendStreamData(
          effectiveStreamId,
          data,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      onDone: () {
        // Маркер завершения не отправляем здесь, так как это делается в close()
      },
    );

    // Создаем и возвращаем канал
    return TypedBidirectionalChannel<Request, Response>(
      endpoint: this,
      serviceName: serviceName,
      methodName: methodName,
      streamId: effectiveStreamId,
      outgoingController: outgoingController,
      incomingStream: typedIncomingStream,
      requestParser: requestParser,
      responseParser: responseParser,
    );
  }

  /// Регистрирует типизированный обработчик двунаправленного канала
  ///
  /// [Request] - тип входящих сообщений
  /// [Response] - тип исходящих сообщений
  /// [serviceName] - название сервиса
  /// [methodName] - название метода
  /// [handler] - обработчик входящих сообщений, возвращающий стрим ответов
  /// [requestParser] - функция для преобразования JSON в объект запроса
  /// [responseParser] - функция для преобразования JSON в объект ответа
  void registerBidirectionalHandler<Request extends T, Response extends T>({
    required String serviceName,
    required String methodName,
    required Stream<Response> Function(
            Stream<Request> incomingStream, String messageId)
        handler,
    Request Function(Map<String, dynamic>)? requestParser,
    Response Function(Map<String, dynamic>)? responseParser,
  }) {
    // Регистрируем обработчик метода
    registerMethod(
      serviceName,
      methodName,
      (context) async {
        // Получаем ID сообщения
        final messageId = context.messageId;

        // Открываем входящий поток и преобразуем его к типу RequestT
        Stream<Request> typedIncomingStream;
        if (requestParser != null) {
          typedIncomingStream = openStream(
            serviceName,
            methodName,
            streamId: messageId,
          ).map((data) {
            if (data is Map<String, dynamic>) {
              // Проверяем маркер конца стрима
              if (data['_clientStreamEnd'] == true) {
                throw StateError('StreamEnd');
              }
              return requestParser(data);
            } else {
              return data as Request;
            }
          });
        } else {
          typedIncomingStream = openStream(
            serviceName,
            methodName,
            streamId: messageId,
          ).where((data) {
            if (data is Map<String, dynamic> &&
                data['_clientStreamEnd'] == true) {
              return false;
            }
            return true;
          }).cast<Request>();
        }

        // Создаем исходящий поток через обработчик
        final outgoingStream = handler(typedIncomingStream, messageId);

        // Подписываемся на исходящий поток и отправляем данные
        outgoingStream.listen(
          (data) {
            sendStreamData(
              messageId,
              data,
              serviceName: serviceName,
              methodName: methodName,
            );
          },
          onError: (error) {
            sendStreamError(
              messageId,
              error.toString(),
            );
          },
          onDone: () {
            closeStream(
              messageId,
              serviceName: serviceName,
              methodName: methodName,
            );
          },
        );

        // Возвращаем подтверждение начала двунаправленного стрима
        return {'status': 'bidirectional_streaming_started'};
      },
    );
  }

  /// Регистрирует типизированную реализацию bidirectional стримингового метода
  void registerBidirectionalStreamMethod<Request extends T, Response extends T>(
    String serviceName,
    String methodName,
    Stream<Response> Function(Stream<Request>) handler,
    Request Function(Map<String, dynamic>)? argumentParser,
    Response Function(Map<String, dynamic>)? responseParser,
  ) {
    // Найдем контракт сервиса
    final serviceContract = _getServiceContract(serviceName);

    // Сначала получаем нетипизированный контракт метода
    final methods = serviceContract.methods.where((m) =>
        m.methodName == methodName &&
        m.methodType == RpcMethodType.bidirectional);

    if (methods.isEmpty) {
      throw ArgumentError(
          'Метод $methodName с типом bidirectional не найден в контракте сервиса $serviceName');
    }

    // Создаем типизированный контракт
    final contract = RpcMethodContract<Request, Response>(
      methodName: methodName,
      methodType: RpcMethodType.bidirectional,
    );

    final implementation = RpcMethodImplementation.bidirectionalStream(
      contract,
      handler,
    );

    _implementations[serviceName]![methodName] = implementation;

    // Регистрируем низкоуровневый обработчик
    _delegate.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        try {
          // Получаем ID сообщения из контекста
          final messageId = context.messageId;

          // Создаем контроллер и стрим для входящих сообщений
          final incomingController = StreamController<Request>();

          // Открываем отдельный стрим для получения входящих данных от клиента
          // Мы будем использовать тот же messageId для связывания запросов
          _delegate
              .openStream(
            serviceName,
            methodName,
            streamId: messageId,
          )
              .listen(
            (data) {
              try {
                // Проверяем на специальный маркер завершения потока
                if (data is Map<String, dynamic> &&
                    data['_clientStreamEnd'] == true) {
                  incomingController.close();
                  return;
                }

                final typedData =
                    argumentParser != null && data is Map<String, dynamic>
                        ? argumentParser(data)
                        : data as Request;

                incomingController.add(typedData);
              } catch (e) {
                incomingController.addError(e);
              }
            },
            onError: (error) {
              incomingController.addError(error);
            },
            onDone: () {
              if (!incomingController.isClosed) {
                incomingController.close();
              }
            },
          );

          // Запускаем обработку bidirectional стрима
          final responseStream =
              implementation.openBidirectionalStream(incomingController.stream);

          // Подписываемся на исходящий поток и отправляем данные обратно клиенту
          _activateBidirectionalStreamHandler(
            messageId,
            serviceName,
            methodName,
            responseStream,
            responseParser,
          );

          // Возвращаем подтверждение начала bidirectional стрима
          return {'status': 'bidirectional_streaming_started'};
        } catch (e) {
          rethrow;
        }
      },
    );
  }

  /// Открывает двунаправленный типизированный поток данных
  Stream<Response>
      openBidirectionalStream<Request extends T, Response extends T>(
    String serviceName,
    String methodName,
    Stream<Request> requestStream, {
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Проверяем наличие контракта
    final contract = _getServiceContract(serviceName);

    // Сначала получаем нетипизированный контракт метода
    final methods = contract.methods.where((m) =>
        m.methodName == methodName &&
        m.methodType == RpcMethodType.bidirectional);

    if (methods.isEmpty) {
      throw ArgumentError(
          'Метод $methodName с типом bidirectional не найден в контракте сервиса $serviceName');
    }

    // Получаем parser из контракта
    final methodContract = methods.first;
    final responseParser = contract.getResponseParser(methodContract);

    // Генерируем ID потока, если не указан
    final effectiveStreamId = streamId ?? _generateUniqueId('stream');

    // Создаем контроллер для выходного потока
    final responseController = StreamController<Response>();

    // Открываем стрим с начальным запросом (инициируем соединение)
    _delegate
        .openStream(
      serviceName,
      methodName,
      request: {'_bidirectional': true},
      metadata: metadata,
      streamId: effectiveStreamId,
    )
        .listen(
      (data) {
        try {
          // Преобразуем входящие данные в типизированные
          final typedResponse =
              data is Map<String, dynamic> && responseParser != null
                  ? responseParser(data)
                  : data;

          // Безопасно конвертируем типы
          final Response safeResponse = typedResponse as Response;
          responseController.add(safeResponse);
        } catch (e) {
          responseController.addError(e);
        }
      },
      onError: (error) => responseController.addError(error),
      onDone: () => responseController.close(),
    );

    // Подписываемся на поток входящих запросов и отправляем их в удаленный метод
    requestStream.listen(
      (request) {
        final processedRequest =
            request is RpcMessage ? request.toJson() : request;
        _delegate.sendStreamData(
          effectiveStreamId,
          processedRequest,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      onDone: () {
        // Отправляем сигнал о завершении входящего потока
        _delegate.sendStreamData(
          effectiveStreamId,
          {'_clientStreamEnd': true},
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      onError: (error) {
        responseController.addError(error);
      },
    );

    return responseController.stream;
  }

  /// Активирует обработчик исходящего потока для bidirectional стрима
  void _activateBidirectionalStreamHandler<Response>(
    String messageId,
    String serviceName,
    String methodName,
    Stream<Response> responseStream,
    Response Function(Map<String, dynamic>)? responseParser,
  ) {
    // Подписываемся на события и пересылаем их через публичный API Endpoint
    responseStream.listen(
      (data) {
        // Преобразуем данные и отправляем их в поток
        final processedData = data is RpcMessage ? data.toJson() : data;

        _delegate.sendStreamData(
          messageId,
          processedData,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      onError: (error) {
        // Отправляем ошибку
        _delegate.sendStreamError(
          messageId,
          error.toString(),
        );
      },
      onDone: () {
        // Закрываем исходящий поток с указанием serviceName и methodName для middleware
        _delegate.closeStream(
          messageId,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
    );
  }
}
