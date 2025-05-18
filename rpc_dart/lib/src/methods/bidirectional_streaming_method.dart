// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "двунаправленный стриминг" (поток запросов - поток ответов)
final class BidirectionalStreamingRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект двунаправленного стриминг RPC метода
  BidirectionalStreamingRpcMethod(
    IRpcEndpoint endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName) {
    // Создаем логгер с консистентным именем
    _logger = RpcLogger('$serviceName.$methodName.bidi_stream');
  }

  /// Создает типизированный двунаправленный канал связи
  ///
  /// [responseParser] - функция для преобразования JSON в объект ответа
  /// [metadata] - дополнительные метаданные (опционально)
  /// [streamId] - необязательный идентификатор стрима (генерируется автоматически)
  BidiStream<Request, Response> call<Request extends T, Response extends T>({
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Генерируем ID стрима если не указан
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('bidirectional_stream');

    final startTime = DateTime.now().millisecondsSinceEpoch;
    final requestId = _endpoint.generateUniqueId('request');

    // Отправляем метрику о создании стрима
    _diagnostic?.reportStreamMetric(
      _diagnostic!.createStreamMetric(
        eventType: RpcStreamEventType.created,
        streamId: effectiveStreamId,
        direction: RpcStreamDirection.bidirectional,
        method: '$serviceName.$methodName',
      ),
    );

    // Отправляем событие начала вызова метода
    _diagnostic?.reportTraceEvent(
      _diagnostic!.createTraceEvent(
        eventType: RpcTraceMetricType.methodStart,
        method: methodName,
        service: serviceName,
        requestId: requestId,
        metadata: {
          'streamId': effectiveStreamId,
          ...?metadata,
        },
      ),
    );

    // Создаем контроллер для исходящих сообщений
    final outgoingController = StreamController<Request>();

    // Инициируем соединение с использованием типизированного маркера
    _engine.invoke(
      serviceName: serviceName,
      methodName: methodName,
      request: RpcBidirectionalStreamingMarker(
        streamId: effectiveStreamId,
        parameters: metadata,
      ),
      metadata: metadata,
    );

    // Счетчики для диагностики
    var sentMessageCount = 0;
    var receivedMessageCount = 0;
    var totalSentDataSize = 0;
    var totalReceivedDataSize = 0;

    // Трансформируем входящий поток, применяя parser и отслеживая метрики
    Stream<Response> typedIncomingStream;
    typedIncomingStream = _engine
        .openStream(
      serviceName: serviceName,
      methodName: methodName,
      streamId: effectiveStreamId,
    )
        .map((data) {
      // Проверяем, является ли входящее сообщение маркером
      final marker = RpcMarkerHandler.tryParseMarker(data);
      if (marker != null) {
        // Обрабатываем различные типы маркеров
        if (marker is RpcClientStreamEndMarker) {
          // Пропускаем маркер завершения клиентского стрима
          throw StateError('StreamEnd');
        } else if (marker is RpcChannelClosedMarker) {
          // Обрабатываем закрытие канала
          throw StateError('ChannelClosed');
        }
      }

      // Если это не маркер или это маркер другого типа, обрабатываем как обычные данные
      if (data is Map<String, dynamic>) {
        try {
          final response = responseParser(data);

          // Увеличиваем счетчики для диагностики
          receivedMessageCount++;
          final dataSize = data.toString().length;
          totalReceivedDataSize += dataSize;

          // Отправляем метрику о полученном сообщении
          _diagnostic?.reportStreamMetric(
            _diagnostic!.createStreamMetric(
              eventType: RpcStreamEventType.messageReceived,
              streamId: effectiveStreamId,
              direction: RpcStreamDirection.serverToClient,
              method: '$serviceName.$methodName',
              dataSize: dataSize,
              messageCount: receivedMessageCount,
            ),
          );

          return response;
        } catch (e) {
          // В случае ошибки преобразования, логируем через метаданные для middleware
          _engine.sendStreamData(
            streamId: effectiveStreamId,
            data: null,
            metadata: {
              '_error': 'Ошибка преобразования: $e',
              '_level': 'warning'
            },
            serviceName: serviceName,
            methodName: methodName,
          );

          // Отправляем метрику об ошибке
          _diagnostic?.reportErrorMetric(
            _diagnostic!.createErrorMetric(
              errorType: RpcErrorMetricType.serializationError,
              message:
                  'Ошибка преобразования данных в стриме $serviceName.$methodName: $e',
              requestId: requestId,
              method: '$serviceName.$methodName',
              details: {'streamId': effectiveStreamId},
            ),
          );

          return data as Response;
        }
      } else {
        receivedMessageCount++;
        final dataSize = data.toString().length;
        totalReceivedDataSize += dataSize;

        // Отправляем метрику о полученном сообщении
        _diagnostic?.reportStreamMetric(
          _diagnostic!.createStreamMetric(
            eventType: RpcStreamEventType.messageReceived,
            streamId: effectiveStreamId,
            direction: RpcStreamDirection.serverToClient,
            method: '$serviceName.$methodName',
            dataSize: dataSize,
            messageCount: receivedMessageCount,
          ),
        );

        return data as Response;
      }
    }).handleError((error) {
      // Игнорируем ошибки маркера завершения стрима
      if (error is StateError &&
          (error.message == 'StreamEnd' || error.message == 'ChannelClosed')) {
        return;
      }

      // Отправляем метрику об ошибке
      _diagnostic?.reportErrorMetric(
        _diagnostic!.createErrorMetric(
          errorType: RpcErrorMetricType.unexpectedError,
          message: 'Ошибка в стриме $serviceName.$methodName: $error',
          requestId: requestId,
          method: '$serviceName.$methodName',
          details: {'streamId': effectiveStreamId},
        ),
      );

      // Другие ошибки пробрасываем дальше
      throw error;
    });

    // Подписываемся на исходящий поток и пересылаем сообщения
    outgoingController.stream.listen(
      (data) {
        final processedData = data is RpcMessage ? data.toJson() : data;
        final dataSize = processedData.toString().length;

        _engine.sendStreamData(
          streamId: effectiveStreamId,
          data: processedData,
          serviceName: serviceName,
          methodName: methodName,
        );

        // Увеличиваем счетчики для диагностики
        sentMessageCount++;
        totalSentDataSize += dataSize;

        // Отправляем метрику об отправленном сообщении
        _diagnostic?.reportStreamMetric(
          _diagnostic!.createStreamMetric(
            eventType: RpcStreamEventType.messageSent,
            streamId: effectiveStreamId,
            direction: RpcStreamDirection.clientToServer,
            method: '$serviceName.$methodName',
            dataSize: dataSize,
            messageCount: sentMessageCount,
          ),
        );
      },
      onDone: () {
        final endTime = DateTime.now().millisecondsSinceEpoch;
        final duration = endTime - startTime;

        // Отправляем типизированный маркер завершения клиентского стрима
        _engine.sendServiceMarker(
          streamId: effectiveStreamId,
          marker: const RpcClientStreamEndMarker(),
          serviceName: serviceName,
          methodName: methodName,
        );

        // Отправляем метрику о закрытии исходящего потока
        _diagnostic?.reportStreamMetric(
          _diagnostic!.createStreamMetric(
            eventType: RpcStreamEventType.closed,
            streamId: effectiveStreamId,
            direction: RpcStreamDirection.clientToServer,
            method: '$serviceName.$methodName',
            messageCount: sentMessageCount,
            throughput:
                sentMessageCount > 0 ? (totalSentDataSize / duration) : 0,
            duration: duration,
          ),
        );

        // Отправляем событие завершения вызова метода
        _diagnostic?.reportTraceEvent(
          _diagnostic!.createTraceEvent(
            eventType: RpcTraceMetricType.methodEnd,
            method: methodName,
            service: serviceName,
            requestId: requestId,
            durationMs: duration,
            metadata: {
              'streamId': effectiveStreamId,
              'sentMessageCount': sentMessageCount,
              'receivedMessageCount': receivedMessageCount,
              'totalSentDataSize': totalSentDataSize,
              'totalReceivedDataSize': totalReceivedDataSize,
            },
          ),
        );
      },
      onError: (error, stackTrace) {
        // Отправляем метрику об ошибке
        _diagnostic?.reportErrorMetric(
          _diagnostic!.createErrorMetric(
            errorType: RpcErrorMetricType.unexpectedError,
            message:
                'Ошибка в исходящем потоке $serviceName.$methodName: $error',
            requestId: requestId,
            method: '$serviceName.$methodName',
            stackTrace: stackTrace.toString(),
            details: {'streamId': effectiveStreamId},
          ),
        );
      },
    );

    return BidiStream<Request, Response>(
      responseStream: typedIncomingStream,
      sendFunction: (request) => outgoingController.add(request),
      closeFunction: () => outgoingController.close(),
    );
  }

  /// Регистрирует обработчик двунаправленного стриминг метода
  ///
  /// [handler] - функция обработки входящих сообщений, возвращающая стрим ответов
  /// [requestParser] - функция для преобразования JSON в объект запроса
  /// [responseParser] - функция для преобразования JSON в объект ответа
  void register<Request extends T, Response extends T>({
    required RpcMethodBidirectionalHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> requestParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    // Получаем контракт сервиса
    final serviceContract = _endpoint.getServiceContract(serviceName);
    if (serviceContract == null) {
      throw Exception(
          'Контракт сервиса $serviceName не найден. Необходимо сначала зарегистрировать контракт сервиса.');
    }

    // Проверяем, существует ли метод в контракте
    final existingMethod =
        serviceContract.findMethod<Request, Response>(methodName);

    // Если метод не найден в контракте, добавляем его
    if (existingMethod == null) {
      serviceContract.addBidirectionalStreamingMethod<Request, Response>(
        methodName: methodName,
        handler: handler,
        argumentParser: requestParser,
        responseParser: responseParser,
      );
    }

    // Получаем актуальный контракт метода
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.bidirectional);

    final implementation =
        RpcMethodImplementation.bidirectionalStreaming(contract, handler);

    // Регистрируем реализацию метода
    _registry.registerMethodImplementation(
      serviceName: serviceName,
      methodName: methodName,
      implementation: implementation,
    );

    // Регистрируем низкоуровневый обработчик
    _registry.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: RpcMethodType.bidirectional,
      argumentParser: requestParser,
      responseParser: responseParser,
      handler: _createHandlerAdapter(handler, requestParser, responseParser),
    );
  }

  /// Создает адаптер для хэндлера, который поможет преобразовать
  /// ожидаемый тип запроса из контекста
  Future<dynamic> Function(RpcMethodContext)
      _createHandlerAdapter<Request extends T, Response extends T>(
    RpcMethodBidirectionalHandler<Request, Response> handler,
    RpcMethodArgumentParser<Request> requestParser,
    RpcMethodResponseParser<Response> responseParser,
  ) {
    // Получаем актуальный контракт метода и создаем имплементацию здесь
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.bidirectional);
    final implementation =
        RpcMethodImplementation.bidirectionalStreaming(contract, handler);

    return (RpcMethodContext context) async {
      final requestId = context.messageId;
      final startTime = DateTime.now().millisecondsSinceEpoch;

      try {
        // Получаем данные запроса и проверяем маркер двунаправленного стрима
        final requestData = context.payload;
        RpcBidirectionalStreamingMarker? bidirectionalMarker;

        // Проверяем, является ли входящее сообщение маркером
        final marker = RpcMarkerHandler.tryParseMarker(requestData);
        final isBidirectional = marker is RpcBidirectionalStreamingMarker;

        if (isBidirectional) {
          bidirectionalMarker = marker;
        }

        // Получаем или создаем ID стрима, отличный от ID сообщения
        String effectiveStreamId;
        if (bidirectionalMarker != null) {
          // Если получили типизированный маркер, используем его streamId
          effectiveStreamId = bidirectionalMarker.streamId;
        } else {
          // Иначе генерируем новый ID стрима
          effectiveStreamId = _endpoint.generateUniqueId('stream');
        }

        // Отправляем событие начала обработки запроса
        _diagnostic?.reportTraceEvent(
          _diagnostic!.createTraceEvent(
            eventType: RpcTraceMetricType.methodStart,
            method: methodName,
            service: serviceName,
            requestId: requestId,
            metadata: {
              'streamId': effectiveStreamId,
              ...context.metadata ?? {},
            },
          ),
        );

        // Если это инициализация двунаправленного стрима
        if (isBidirectional) {
          _logger?.debug(
            'Инициализация двунаправленного стрима со streamId: $effectiveStreamId',
          );

          // Отправляем метрику о создании стрима
          _diagnostic?.reportStreamMetric(
            _diagnostic!.createStreamMetric(
              eventType: RpcStreamEventType.created,
              streamId: effectiveStreamId,
              direction: RpcStreamDirection.bidirectional,
              method: '$serviceName.$methodName',
            ),
          );

          // Создаем контроллер для входящих сообщений от клиента
          final incomingController = StreamController<Request>();

          // Счетчики для диагностики
          var receivedMessageCount = 0;
          var sentMessageCount = 0;
          var totalReceivedDataSize = 0;
          var totalSentDataSize = 0;

          // Подписываемся на сообщения из транспорта для этого streamId и перенаправляем их в контроллер
          final subscription = _engine
              .openStream(
            serviceName: serviceName,
            methodName: methodName,
            streamId: effectiveStreamId,
          )
              .listen(
            (data) {
              _logger?.debug(
                'Получено сообщение от клиента: $data',
              );

              // Проверяем, является ли сообщение маркером
              final marker = RpcMarkerHandler.tryParseMarker(data);

              // Проверяем маркер завершения стрима
              if (marker is RpcClientStreamEndMarker) {
                _logger?.debug(
                  'Получен маркер завершения стрима',
                );
                // Закрываем контроллер, но не отменяем подписку - это важно
                incomingController.close();

                // Отправляем метрику о закрытии входящего потока
                _diagnostic?.reportStreamMetric(
                  _diagnostic!.createStreamMetric(
                    eventType: RpcStreamEventType.closed,
                    streamId: effectiveStreamId,
                    direction: RpcStreamDirection.clientToServer,
                    method: '$serviceName.$methodName',
                    messageCount: receivedMessageCount,
                  ),
                );

                return;
              }

              try {
                // Преобразуем данные в объект Request
                final request = data is Map<String, dynamic>
                    ? requestParser(data)
                    : data as Request;

                // Увеличиваем счетчики для диагностики
                receivedMessageCount++;
                final dataSize = data.toString().length;
                totalReceivedDataSize += dataSize;

                // Отправляем метрику о полученном сообщении
                _diagnostic?.reportStreamMetric(
                  _diagnostic!.createStreamMetric(
                    eventType: RpcStreamEventType.messageReceived,
                    streamId: effectiveStreamId,
                    direction: RpcStreamDirection.clientToServer,
                    method: '$serviceName.$methodName',
                    dataSize: dataSize,
                    messageCount: receivedMessageCount,
                  ),
                );

                _logger?.debug(
                  'Добавляем сообщение в стрим обработчика: $request',
                );
                incomingController.add(request);
              } catch (e, stackTrace) {
                _logger?.error(
                  'Ошибка при обработке сообщения: $e',
                  error: e,
                  stackTrace: stackTrace,
                );

                // Отправляем метрику об ошибке
                _diagnostic?.reportErrorMetric(
                  _diagnostic!.createErrorMetric(
                    errorType: RpcErrorMetricType.serializationError,
                    message:
                        'Ошибка при обработке сообщения в стриме $serviceName.$methodName: $e',
                    requestId: requestId,
                    method: '$serviceName.$methodName',
                    stackTrace: stackTrace.toString(),
                    details: {'streamId': effectiveStreamId},
                  ),
                );

                incomingController.addError(e);
              }
            },
            onError: (error, stackTrace) {
              _logger?.error(
                'Ошибка в потоке сообщений: $error',
                error: error,
                stackTrace: stackTrace,
              );

              // Отправляем метрику об ошибке
              _diagnostic?.reportErrorMetric(
                _diagnostic!.createErrorMetric(
                  errorType: RpcErrorMetricType.unexpectedError,
                  message:
                      'Ошибка в потоке сообщений $serviceName.$methodName: $error',
                  requestId: requestId,
                  method: '$serviceName.$methodName',
                  stackTrace: stackTrace.toString(),
                  details: {'streamId': effectiveStreamId},
                ),
              );

              // Не пробрасываем ошибку дальше - просто логируем
              // Это предотвратит завершение стрима в случае временной ошибки
            },
            onDone: () {
              _logger?.debug(
                'Входящий поток закрыт',
              );
              // Закрываем контроллер, если он еще не закрыт
              if (!incomingController.isClosed) {
                incomingController.close();

                // Отправляем метрику о закрытии входящего потока
                _diagnostic?.reportStreamMetric(
                  _diagnostic!.createStreamMetric(
                    eventType: RpcStreamEventType.closed,
                    streamId: effectiveStreamId,
                    direction: RpcStreamDirection.clientToServer,
                    method: '$serviceName.$methodName',
                    messageCount: receivedMessageCount,
                  ),
                );
              }
            },
          );

          // Вместо создания отдельного outgoingStream, используем handleBidirectionalStream,
          // который соединит входящий поток с обработчиком
          final bidiStream = implementation
              .openBidirectionalStreaming(incomingController.stream);

          // Подписываемся на ответы из bidiStream и отправляем их клиенту
          bidiStream.listen(
            (data) {
              _logger?.debug(
                'Отправка ответа клиенту: $data',
              );
              try {
                final processedData = data is RpcMessage ? data.toJson() : data;
                final dataSize = processedData.toString().length;

                _engine.sendStreamData(
                  streamId: effectiveStreamId,
                  data: processedData,
                  serviceName: serviceName,
                  methodName: methodName,
                );

                // Увеличиваем счетчики для диагностики
                sentMessageCount++;
                totalSentDataSize += dataSize;

                // Отправляем метрику об отправленном сообщении
                _diagnostic?.reportStreamMetric(
                  _diagnostic!.createStreamMetric(
                    eventType: RpcStreamEventType.messageSent,
                    streamId: effectiveStreamId,
                    direction: RpcStreamDirection.serverToClient,
                    method: '$serviceName.$methodName',
                    dataSize: dataSize,
                    messageCount: sentMessageCount,
                  ),
                );
              } catch (e, stackTrace) {
                _logger?.error(
                  'Ошибка при отправке ответа клиенту: $e',
                  error: e,
                  stackTrace: stackTrace,
                );

                // Отправляем метрику об ошибке
                _diagnostic?.reportErrorMetric(
                  _diagnostic!.createErrorMetric(
                    errorType: RpcErrorMetricType.unexpectedError,
                    message:
                        'Ошибка при отправке ответа клиенту в стриме $serviceName.$methodName: $e',
                    requestId: requestId,
                    method: '$serviceName.$methodName',
                    stackTrace: stackTrace.toString(),
                    details: {'streamId': effectiveStreamId},
                  ),
                );

                // Не пробрасываем ошибку дальше
              }
            },
            onError: (error, stackTrace) {
              _logger?.error(
                'Ошибка в исходящем потоке: $error',
                error: error,
                stackTrace: stackTrace,
              );

              // Отправляем метрику об ошибке
              _diagnostic?.reportErrorMetric(
                _diagnostic!.createErrorMetric(
                  errorType: RpcErrorMetricType.unexpectedError,
                  message:
                      'Ошибка в исходящем потоке $serviceName.$methodName: $error',
                  requestId: requestId,
                  method: '$serviceName.$methodName',
                  stackTrace: stackTrace.toString(),
                  details: {'streamId': effectiveStreamId},
                ),
              );

              try {
                _engine.sendStreamError(
                  streamId: effectiveStreamId,
                  errorMessage: error.toString(),
                  serviceName: serviceName,
                  methodName: methodName,
                );
              } catch (e, errorStackTrace) {
                _logger?.error(
                  'Ошибка при отправке сообщения об ошибке: $e',
                  error: e,
                  stackTrace: errorStackTrace,
                );
              }
            },
            onDone: () {
              final endTime = DateTime.now().millisecondsSinceEpoch;
              final duration = endTime - startTime;

              _logger?.debug(
                'Исходящий поток завершен',
              );

              try {
                _engine.closeStream(
                  streamId: effectiveStreamId,
                  serviceName: serviceName,
                  methodName: methodName,
                );

                // Отправляем метрику о завершении исходящего потока
                _diagnostic?.reportStreamMetric(
                  _diagnostic!.createStreamMetric(
                    eventType: RpcStreamEventType.closed,
                    streamId: effectiveStreamId,
                    direction: RpcStreamDirection.serverToClient,
                    method: '$serviceName.$methodName',
                    messageCount: sentMessageCount,
                    throughput: sentMessageCount > 0
                        ? (totalSentDataSize / duration)
                        : 0,
                    duration: duration,
                  ),
                );

                // Отправляем событие завершения обработки запроса
                _diagnostic?.reportTraceEvent(
                  _diagnostic!.createTraceEvent(
                    eventType: RpcTraceMetricType.methodEnd,
                    method: methodName,
                    service: serviceName,
                    requestId: requestId,
                    durationMs: duration,
                    metadata: {
                      'streamId': effectiveStreamId,
                      'sentMessageCount': sentMessageCount,
                      'receivedMessageCount': receivedMessageCount,
                      'totalSentDataSize': totalSentDataSize,
                      'totalReceivedDataSize': totalReceivedDataSize,
                    },
                  ),
                );

                // Отправляем метрику задержки
                _diagnostic?.reportLatencyMetric(
                  _diagnostic!.createLatencyMetric(
                    operationType: RpcLatencyOperationType.requestProcessing,
                    operation: '$serviceName.$methodName',
                    startTime: startTime,
                    endTime: endTime,
                    success: true,
                    requestId: requestId,
                    metadata: {
                      'streamId': effectiveStreamId,
                      'sentMessageCount': sentMessageCount,
                      'receivedMessageCount': receivedMessageCount,
                    },
                  ),
                );
              } catch (e, errorStackTrace) {
                _logger?.error(
                  'Ошибка при закрытии стрима: $e',
                  error: e,
                  stackTrace: errorStackTrace,
                );

                // Отправляем метрику об ошибке
                _diagnostic?.reportErrorMetric(
                  _diagnostic!.createErrorMetric(
                    errorType: RpcErrorMetricType.unexpectedError,
                    message:
                        'Ошибка при закрытии стрима $serviceName.$methodName: $e',
                    requestId: requestId,
                    method: '$serviceName.$methodName',
                    stackTrace: errorStackTrace.toString(),
                    details: {'streamId': effectiveStreamId},
                  ),
                );
              }

              // При завершении outgoing потока отменяем подписку на входящие сообщения
              // чтобы избежать утечек ресурсов
              subscription.cancel().catchError((e, cancelStackTrace) {
                _logger?.error(
                  'Ошибка при отмене подписки на входящий поток: $e',
                  error: e,
                  stackTrace: cancelStackTrace,
                );
              });
            },
          );

          // Возвращаем подтверждение установки соединения
          return {
            'status': 'bidirectional_streaming',
            'streamId': effectiveStreamId
          };
        } else {
          // Если это обычный запрос, обрабатываем по старой логике
          // Это может быть нужно для совместимости или других целей
          _logger?.warning(
            'Для метода $serviceName.$methodName требуется маркер _bidirectional',
          );

          return {'error': 'Для этого метода требуется маркер _bidirectional'};
        }
      } catch (e, stackTrace) {
        _logger?.error(
          'Неожиданная ошибка при обработке двунаправленного стрима: $e',
          error: e,
          stackTrace: stackTrace,
        );

        // Отправляем метрику об ошибке
        _diagnostic?.reportErrorMetric(
          _diagnostic!.createErrorMetric(
            errorType: RpcErrorMetricType.unexpectedError,
            message:
                'Неожиданная ошибка при обработке двунаправленного стрима $serviceName.$methodName: $e',
            requestId: requestId,
            method: '$serviceName.$methodName',
            stackTrace: stackTrace.toString(),
          ),
        );

        return {
          'error': 'Unexpected error in bidirectional stream: $e',
          'status': 'error'
        };
      }
    };
  }
}
