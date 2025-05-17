// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "клиентский стриминг" (поток запросов - без ответа)
/// Упрощенная реализация, которая не ожидает ответа от сервера
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
  /// [metadata] - метаданные запроса (опционально)
  /// [streamId] - ID стрима (опционально, генерируется автоматически)
  ClientStreamingBidiStream<Request> call<Request extends T>({
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('client_stream');
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final requestId = _endpoint.generateUniqueId('request');

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

    // Инициируем соединение с пустым запросом или метаданными
    _core.invoke(
      serviceName: serviceName,
      methodName: methodName,
      request: {
        '_clientStreaming': true,
        '_streamId': effectiveStreamId,
        '_noResponse': true, // Всегда устанавливаем флаг noResponse
      },
      metadata: metadata,
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
        _logger?.error(
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

        _logger?.debug(
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
              'totalSentDataSize': totalSentDataSize,
            },
          ),
        );
      },
    );

    // Создаем BidiStream для передачи в ClientStreamingBidiStream
    final bidiStream = BidiStream<Request, RpcNull>(
      // Пустой поток ответов, так как ответ не ожидается
      responseStream: Stream<RpcNull>.empty(),
      sendFunction: (request) => requestController.add(request),
      finishTransferFunction: () async {
        // При завершении передачи данных закрываем запросы, но не стрим
        if (!requestController.isClosed) {
          await requestController.close();
        }
      },
      closeFunction: () {
        // При закрытии стрима закрываем контроллер
        requestController.close();
        return Future.value();
      },
    );

    // Создаем ClientStreamingBidiStream с упрощенным конструктором
    return ClientStreamingBidiStream<Request>(bidiStream);
  }

  /// Регистрирует обработчик клиентского стриминг метода
  ///
  /// [handler] - функция обработки потока запросов
  /// [requestParser] - функция для преобразования JSON в объект запроса
  /// [responseParser] - функция для преобразования JSON в объект ответа
  void register<Request extends T, Response extends T>({
    required dynamic handler,
    required RpcMethodArgumentParser<Request> requestParser,
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
      serviceContract.addClientStreamingMethod<Request>(
        methodName: methodName,
        handler: handler,
        argumentParser: requestParser,
      );
    }

    // Получаем актуальный контракт метода
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.clientStreaming);

    // Создаем соответствующую реализацию метода без ожидания результата
    final implementation =
        RpcMethodImplementation<Request, Response>.clientStreaming(
            contract, handler as RpcMethodClientStreamHandler<Request>);

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
      handler: _createHandlerFunction<Request, Response>(
        implementation: implementation,
        requestParser: requestParser,
      ),
    );
  }

  // Вспомогательный метод для создания обработчика
  Future<dynamic> Function(RpcMethodContext)
      _createHandlerFunction<Request extends T, Response extends T>({
    required RpcMethodImplementation<Request, Response> implementation,
    required RpcMethodArgumentParser<Request> requestParser,
  }) {
    return (context) async {
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

        // Запускаем обработку стрима с таймаутом и защитой от зависания
        _logger?.debug(
          'Начало обработки клиентского стриминга для метода $serviceName.$methodName',
        );

        // Устанавливаем таймаут обработки (30 секунд по умолчанию)
        const handlerTimeout = Duration(seconds: 30);

        // Создаем комплитер для результата с таймаутом
        final resultCompleter = Completer<void>();

        // Запускаем обработчик в отдельной зоне с таймаутом
        Timer? timeoutTimer;

        Future<void> runHandler() async {
          try {
            // Обрабатываем входящий поток без ожидания результата
            await implementation.openClientStreaming(
              stream: incomingStream,
              metadata: context.metadata,
              streamId: effectiveStreamId,
            );

            // Завершаем обработку успешно
            if (!resultCompleter.isCompleted) {
              resultCompleter.complete();
            }
          } catch (e, stackTrace) {
            _logger?.error(
              'Ошибка при обработке клиентского стриминга: $e',
              error: e,
              stackTrace: stackTrace,
            );

            // Только если комплитер еще не завершен
            if (!resultCompleter.isCompleted) {
              resultCompleter.completeError(e, stackTrace);
            }
          }
        }

        // Запускаем обработчик
        runHandler();

        // Устанавливаем таймаут
        timeoutTimer = Timer(handlerTimeout, () {
          if (!resultCompleter.isCompleted) {
            final timeoutError = TimeoutException(
              'Превышено время обработки клиентского стриминга',
              handlerTimeout,
            );

            _logger?.error(
              'Таймаут обработки клиентского стриминга: $timeoutError',
              error: timeoutError,
            );

            resultCompleter.completeError(timeoutError);
          }
        });

        // Ожидаем завершение обработки
        await resultCompleter.future.whenComplete(() {
          timeoutTimer?.cancel();
        });

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

        // Возвращаем служебное сообщение о успешном приеме
        return {
          '_response': true,
          '_noResponse': true,
          '_streamId': effectiveStreamId,
        };
      } catch (e, stackTrace) {
        _logger?.error(
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

        // Возвращаем ошибку в формате, который клиент сможет понять
        return {
          '_response': true,
          '_error': true,
          'errorMessage': 'Ошибка обработки клиентского стрима: $e',
          'errorType': 'RpcUnexpectedError',
        };
      }
    };
  }
}
