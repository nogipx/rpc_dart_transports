// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "клиентский стриминг" (поток запросов - один ответ)
final class ClientStreamingRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект клиентского стриминг RPC метода
  ClientStreamingRpcMethod(
    IRpcEndpoint<T> endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName) {
    // Создаем логгер с консистентным именем
    _logger = RpcLogger('$serviceName.$methodName.client_stream');
  }

  /// Открывает клиентский стриминг канал и возвращает объект для отправки запросов
  ///
  /// [responseParser] - функция для преобразования JSON в объект ответа
  /// [metadata] - метаданные запроса (опционально)
  /// [streamId] - ID стрима (опционально, генерируется автоматически)
  ClientStreamingBidiStream<Request, Response>
      call<Request extends T, Response extends T>({
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('client_stream');
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final requestId = _endpoint.generateUniqueId('request');

    // Получаем диагностический клиент

    // Отправляем метрику о создании стрима
    _diagnostic?.reportStreamMetric(
      _diagnostic!.createStreamMetric(
        eventType: RpcStreamEventType.created,
        streamId: effectiveStreamId,
        direction: RpcStreamDirection.clientToServer,
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
        metadata: metadata,
      ),
    );

    // Счетчики для диагностики
    var sentMessageCount = 0;
    var totalSentDataSize = 0;

    // Создаем контроллер для запросов
    final requestController = StreamController<Request>();

    // Создаем Future для ответа
    final responseCompleter = Completer<Response>();

    // Инициируем соединение с пустым запросом или метаданными
    _core.invoke(
      serviceName: serviceName,
      methodName: methodName,
      request: {
        '_clientStreaming': true,
        '_streamId': effectiveStreamId,
      },
      metadata: metadata,
    );

    // Подписываемся на ответы от сервера
    final subscription = _core
        .openStream(
      serviceName: serviceName,
      methodName: methodName,
      streamId: effectiveStreamId,
    )
        .listen(
      (data) {
        // Если это ответ на стрим-запрос
        if (data is Map<String, dynamic> && data['_response'] == true) {
          try {
            // Получаем результат и завершаем поток
            final result = responseParser(data['result']);

            // Отправляем событие завершения вызова метода
            final endTime = DateTime.now().millisecondsSinceEpoch;
            final duration = endTime - startTime;

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
                  'totalSentDataSize': totalSentDataSize,
                },
              ),
            );

            // Отправляем метрику задержки
            _diagnostic?.reportLatencyMetric(
              _diagnostic!.createLatencyMetric(
                operationType: RpcLatencyOperationType.methodCall,
                operation: '$serviceName.$methodName',
                startTime: startTime,
                endTime: endTime,
                success: true,
                requestId: requestId,
                metadata: {
                  'streamId': effectiveStreamId,
                  'sentMessageCount': sentMessageCount,
                },
              ),
            );

            responseCompleter.complete(result);
          } catch (e, stackTrace) {
            _logger.error(
              'Ошибка при обработке ответа: $e',
              error: e,
              stackTrace: stackTrace,
            );

            // Отправляем метрику об ошибке
            _diagnostic?.reportErrorMetric(
              _diagnostic!.createErrorMetric(
                errorType: RpcErrorMetricType.serializationError,
                message:
                    'Ошибка при обработке ответа в клиентском стриме $serviceName.$methodName: $e',
                requestId: requestId,
                method: '$serviceName.$methodName',
                stackTrace: stackTrace.toString(),
                details: {'streamId': effectiveStreamId},
              ),
            );

            responseCompleter.completeError(e);
          }
        }
      },
      onError: (error, stackTrace) {
        _logger.error(
          'Ошибка в потоке: $error',
          error: error,
          stackTrace: stackTrace,
        );

        // Отправляем метрику об ошибке
        _diagnostic?.reportErrorMetric(
          _diagnostic!.createErrorMetric(
            errorType: RpcErrorMetricType.unexpectedError,
            message:
                'Ошибка в клиентском стриме $serviceName.$methodName: $error',
            requestId: requestId,
            method: '$serviceName.$methodName',
            stackTrace: stackTrace.toString(),
            details: {'streamId': effectiveStreamId},
          ),
        );

        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(error);
        }
      },
      onDone: () {
        _logger.debug(
          'Завершение потока ответа',
        );

        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(
            StateError(
              'Поток с ID $effectiveStreamId для метода $serviceName.$methodName был закрыт',
            ),
          );
        }
      },
    );

    // Подписываемся на запросы от клиента и отправляем их на сервер
    requestController.stream.listen(
      (request) {
        final processedRequest =
            request is RpcMessage ? request.toJson() : request;
        final dataSize = processedRequest.toString().length;

        _core.sendStreamData(
          streamId: effectiveStreamId,
          data: processedRequest,
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
      onError: (error, stackTrace) {
        _logger.error(
          'Ошибка при отправке запроса: $error',
          error: error,
          stackTrace: stackTrace,
        );

        // Отправляем метрику об ошибке
        _diagnostic?.reportErrorMetric(
          _diagnostic!.createErrorMetric(
            errorType: RpcErrorMetricType.unexpectedError,
            message:
                'Ошибка при отправке запроса в клиентском стриме $serviceName.$methodName: $error',
            requestId: requestId,
            method: '$serviceName.$methodName',
            stackTrace: stackTrace.toString(),
            details: {'streamId': effectiveStreamId},
          ),
        );
      },
      onDone: () {
        final endTime = DateTime.now().millisecondsSinceEpoch;
        final duration = endTime - startTime;

        _logger.debug(
          'Завершение потока запросов',
        );

        // Отправляем метрику о закрытии потока запросов
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

        // Отправляем маркер завершения потока запросов
        _core.sendStreamData(
          streamId: effectiveStreamId,
          data: {'_clientStreamEnd': true},
          serviceName: serviceName,
          methodName: methodName,
        );
      },
    );

    // Создаем BidiStream для передачи в ClientStreamingBidiStream
    final bidiStream = BidiStream<Request, Response>(
      responseStream: Stream.fromFuture(responseCompleter.future),
      sendFunction: (request) => requestController.add(request),
      closeFunction: () {
        requestController.close();
        // Отменяем подписку на стрим от сервера
        subscription.cancel().catchError((e, stackTrace) {
          _logger.error(
            'Ошибка при отмене подписки на серверный стрим: $e',
            error: e,
            stackTrace: stackTrace,
          );
        });
        return Future.value();
      },
    );

    // Создаем ClientStreamingBidiStream с правильным конструктором
    return ClientStreamingBidiStream<Request, Response>(bidiStream);
  }

  /// Регистрирует обработчик клиентского стриминг метода
  ///
  /// [handler] - функция обработки потока запросов, возвращающая один ответ
  /// [requestParser] - функция для преобразования JSON в объект запроса
  /// [responseParser] - функция для преобразования JSON в объект ответа
  void register<Request extends T, Response extends T>({
    required RpcMethodClientStreamHandler<Request, Response> handler,
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
      serviceContract.addClientStreamingMethod<Request, Response>(
        methodName: methodName,
        handler: handler,
        argumentParser: requestParser,
        responseParser: responseParser,
      );
    }

    // Получаем актуальный контракт метода
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.clientStreaming);
    final implementation =
        RpcMethodImplementation.clientStreaming(contract, handler);

    // Регистрируем реализацию метода
    _registrar.registerMethodImplementation(
      serviceName: serviceName,
      methodName: methodName,
      implementation: implementation,
    );

    // Регистрируем низкоуровневый обработчик
    _registrar.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      handler: (context) async {
        final requestId = context.messageId;
        final startTime = DateTime.now().millisecondsSinceEpoch;

        // Отправляем событие начала обработки запроса
        _diagnostic?.reportTraceEvent(
          _diagnostic!.createTraceEvent(
            eventType: RpcTraceMetricType.methodStart,
            method: methodName,
            service: serviceName,
            requestId: requestId,
            metadata: context.metadata,
          ),
        );

        // Счетчики для диагностики
        var receivedMessageCount = 0;
        var totalReceivedDataSize = 0;

        try {
          // Проверяем, что это клиентский стриминг запрос
          final requestData = context.payload;
          final isClientStreaming = requestData is Map<String, dynamic> &&
              requestData['_clientStreaming'] == true;

          // Получаем или создаем ID стрима
          String effectiveStreamId;
          if (isClientStreaming && requestData['_streamId'] != null) {
            effectiveStreamId = requestData['_streamId'] as String;
          } else {
            effectiveStreamId = context.messageId;
          }

          // Отправляем метрику о создании стрима
          _diagnostic?.reportStreamMetric(
            _diagnostic!.createStreamMetric(
              eventType: RpcStreamEventType.created,
              streamId: effectiveStreamId,
              direction: RpcStreamDirection.clientToServer,
              method: '$serviceName.$methodName',
            ),
          );

          // Получаем стрим сообщений от клиента
          final incomingStream = _core
              .openStream(
            serviceName: serviceName,
            methodName: methodName,
            streamId: effectiveStreamId,
          )
              .takeWhile((data) {
            // Останавливаем получение данных, если получаем маркер завершения
            if (data is Map<String, dynamic> &&
                data['_clientStreamEnd'] == true) {
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

              return false;
            }
            return true;
          }).map((data) {
            try {
              // Преобразуем данные в типизированный запрос
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

              return request;
            } catch (e, stackTrace) {
              _logger.error(
                'Ошибка при обработке сообщения: $e',
                error: e,
                stackTrace: stackTrace,
              );

              // Отправляем метрику об ошибке
              _diagnostic?.reportErrorMetric(
                _diagnostic!.createErrorMetric(
                  errorType: RpcErrorMetricType.serializationError,
                  message:
                      'Ошибка при обработке сообщения в клиентском стриме $serviceName.$methodName: $e',
                  requestId: requestId,
                  method: '$serviceName.$methodName',
                  stackTrace: stackTrace.toString(),
                  details: {'streamId': effectiveStreamId},
                ),
              );

              rethrow;
            }
          });

          // Запускаем обработку стрима
          _logger.debug(
            'Начало обработки клиентского стриминга для метода $serviceName.$methodName',
          );

          // Обрабатываем входящий поток запросов
          final result = await implementation.openClientStreaming(
            stream: incomingStream,
            metadata: context.metadata,
            streamId: effectiveStreamId,
          );

          final endTime = DateTime.now().millisecondsSinceEpoch;
          final duration = endTime - startTime;

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
                'receivedMessageCount': receivedMessageCount,
              },
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
                'receivedMessageCount': receivedMessageCount,
                'totalReceivedDataSize': totalReceivedDataSize,
              },
            ),
          );

          // Возвращаем результат клиенту в специальном формате
          final resultForTransport =
              result is RpcMessage ? result.toJson() : result;

          return {
            '_response': true,
            'result': resultForTransport,
          };
        } catch (e, stackTrace) {
          _logger.error(
            'Ошибка при обработке клиентского стриминга: $e',
            error: e,
            stackTrace: stackTrace,
          );

          // Отправляем метрику об ошибке
          _diagnostic?.reportErrorMetric(
            _diagnostic!.createErrorMetric(
              errorType: RpcErrorMetricType.unexpectedError,
              message:
                  'Ошибка при обработке клиентского стрима $serviceName.$methodName: $e',
              requestId: requestId,
              method: '$serviceName.$methodName',
              stackTrace: stackTrace.toString(),
            ),
          );

          rethrow;
        }
      },
    );
  }
}
