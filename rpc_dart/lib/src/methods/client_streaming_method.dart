// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "клиентский стриминг" (поток запросов - с ответом или без)
/// Поддерживает два режима:
/// 1. С ответом после завершения обработки (как в gRPC)
/// 2. Без ответа (упрощенный режим)
final class ClientStreamingRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Статическая карта для хранения активных стримов
  /// Ключ: serviceName + methodName + идентификатор клиента (если нужно)
  /// Значение: кешированный стрим и его метаданные
  static final Map<String, _CachedStream> _streamCache = {};

  /// Создает ключ для кеша стримов
  String _createCacheKey<Request extends T, Response extends T>({
    String? streamId,
    String? clientId,
  }) {
    // Формируем ключ из имени сервиса и метода
    // Можно также добавить clientId для разделения по клиентам, если нужно
    final key = '$serviceName.$methodName';
    if (clientId != null) {
      return '$key.$clientId';
    }
    return key;
  }

  /// Периодически очищает кеш от закрытых или устаревших стримов
  static void _cleanupCache() {
    final keysToRemove = <String>[];

    // Находим все ключи, соответствующие закрытым стримам
    for (final entry in _streamCache.entries) {
      final cachedStream = entry.value;

      // Если стрим закрыт или истек срок жизни кеша
      if (cachedStream.isClosed ||
          DateTime.now().difference(cachedStream.createdAt).inMinutes > 30) {
        keysToRemove.add(entry.key);
      }
    }

    // Удаляем найденные ключи
    for (final key in keysToRemove) {
      _streamCache.remove(key);
    }
  }

  /// Создает новый объект клиентского стриминг RPC метода
  ClientStreamingRpcMethod(
    IRpcEndpoint endpoint,
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
  /// [clientId] - ID клиента (опционально, для разделения по клиентам)
  /// [forceNewStream] - флаг создания нового стрима даже если существует активный
  ClientStreamingBidiStream<Request, Response>
      call<Request extends T, Response extends T>({
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
    String? clientId,
    bool forceNewStream = false,
  }) {
    // Периодически очищаем кеш стримов
    _cleanupCache();

    // Создаем ключ для кеша
    final cacheKey = _createCacheKey<Request, Response>(
      streamId: streamId,
      clientId: clientId,
    );

    // Проверяем, есть ли уже активный стрим в кеше, если нас не просят создать новый поток
    if (!forceNewStream && _streamCache.containsKey(cacheKey)) {
      final cachedStream = _streamCache[cacheKey]!;

      // Если стрим активен, используем его
      if (!cachedStream.isClosed) {
        _logger?.debug('Переиспользуем существующий стрим из кеша: $cacheKey');
        return cachedStream.stream
            as ClientStreamingBidiStream<Request, Response>;
      } else {
        // Если стрим закрыт, удаляем его из кеша
        _streamCache.remove(cacheKey);
      }
    }

    // Если в кеше нет активного стрима или нужно создать новый, создаем его
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('client_stream');
    final startTime = DateTime.now().millisecondsSinceEpoch;

    _logger?.debug('Инициализация клиентского стрима с ID: $effectiveStreamId');

    // Отправляем метрику о создании стрима
    _diagnostic?.reportStreamMetric(
      _diagnostic!.createStreamMetric(
        eventType: RpcStreamEventType.created,
        streamId: effectiveStreamId,
        direction: RpcStreamDirection.clientToServer,
        method: '$serviceName.$methodName',
      ),
    );

    // Счетчики для диагностики
    var sentMessageCount = 0;
    var totalSentDataSize = 0;

    // Создаем контроллер для ответа
    final responseController = StreamController<Response>();

    // Создаем маркер инициализации клиентского стрима
    final clientStreamMarker = RpcClientStreamingMarker(
      streamId: effectiveStreamId,
      parameters: metadata,
    );

    // Используем единый способ инициализации через openStream с маркером
    final responseStream = _engine.openStream(
      serviceName: serviceName,
      methodName: methodName,
      request: clientStreamMarker,
      metadata: metadata,
      streamId: effectiveStreamId,
    );

    // Подписываемся на поток ответов от сервера
    responseStream.listen(
      (response) {
        // Обрабатываем ответ от сервера после завершения стрима
        if (response != null && !responseController.isClosed) {
          try {
            // Проверяем, не является ли ответ маркером
            if (!RpcMarkerHandler.isServiceMarker(response)) {
              // Преобразуем ответ в нужный тип
              final parsedResponse = responseParser(response);

              // Добавляем ответ в контроллер
              responseController.add(parsedResponse);
            }
          } catch (error, stackTrace) {
            // В случае ошибки преобразования добавляем ошибку в контроллер
            _logger?.error(
              'Ошибка при преобразовании ответа: $error',
              error: error,
              stackTrace: stackTrace,
            );
            responseController.addError(error, stackTrace);
          }
        }
      },
      onError: (error, stackTrace) {
        // В случае ошибки в потоке добавляем ошибку в контроллер ответов
        _logger?.error(
          'Ошибка потока ответов: $error',
          error: error,
          stackTrace: stackTrace,
        );
        if (!responseController.isClosed) {
          responseController.addError(error, stackTrace);
        }
      },
      onDone: () {
        // Закрываем контроллер ответов при завершении потока
        if (!responseController.isClosed) {
          responseController.close();
        }

        // Удаляем стрим из кеша
        _streamCache.remove(cacheKey);
        _logger?.debug('Удален стрим из кеша при завершении: $cacheKey');
      },
    );

    // Создаем BidiStream для передачи в ClientStreamingBidiStream
    final bidiStream = BidiStream<Request, Response>(
      responseStream: responseController.stream,
      sendFunction: (request) {
        try {
          // Преобразуем запрос в JSON, если это RpcMessage
          final processedRequest =
              request is RpcMessage ? request.toJson() : request;

          // Отправляем запрос в стрим, используя тот же streamId
          _engine.sendStreamData(
            streamId: effectiveStreamId,
            data: processedRequest,
            serviceName: serviceName,
            methodName: methodName,
          );

          // Увеличиваем счетчики для диагностики
          sentMessageCount++;
          final dataSize = processedRequest.toString().length;
          totalSentDataSize += dataSize;

          // Отправляем метрику об отправке сообщения
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
        } catch (e, stackTrace) {
          // Логируем ошибку при отправке сообщения
          _logger?.error(
            'Ошибка при отправке сообщения: $e',
            error: e,
            stackTrace: stackTrace,
          );
          responseController.addError(e, stackTrace);
        }
      },
      // Реализуем finishTransferFunction для завершения отправки
      finishTransferFunction: () async {
        _logger?.debug('Вызов finishTransfer - отправка маркера завершения');

        try {
          final endTime = DateTime.now().millisecondsSinceEpoch;
          final duration = endTime - startTime;

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

          // Отправляем типизированный маркер завершения потока запросов
          await _engine.sendServiceMarker(
            streamId: effectiveStreamId,
            marker: const RpcClientStreamEndMarker(),
            serviceName: serviceName,
            methodName: methodName,
          );

          _logger?.debug('Маркер завершения потока отправлен');
        } catch (e, stackTrace) {
          _logger?.error(
            'Ошибка при отправке маркера завершения потока: $e',
            error: e,
            stackTrace: stackTrace,
          );
        }
      },
      closeFunction: () async {
        // Закрываем контроллер ответов при закрытии BidiStream
        if (!responseController.isClosed) {
          await responseController.close();
        }

        // Удаляем стрим из кеша
        _streamCache.remove(cacheKey);
        _logger?.debug('Удален стрим из кеша при закрытии: $cacheKey');
      },
    );

    // Создаем и оборачиваем в ClientStreamingBidiStream
    final streamingBidiStream =
        ClientStreamingBidiStream<Request, Response>(bidiStream);

    // Сохраняем стрим в кеше
    _streamCache[cacheKey] = _CachedStream(
      stream: streamingBidiStream,
      streamId: effectiveStreamId,
      createdAt: DateTime.now(),
    );

    _logger?.debug('Сохранен новый стрим в кеш: $cacheKey');

    return streamingBidiStream;
  }

  /// Регистрирует обработчик клиентского стриминг метода
  ///
  /// [handler] - функция обработки потока запросов
  /// [requestParser] - функция для преобразования JSON в объект запроса
  /// [responseParser] - функция для преобразования JSON в объект ответа
  void register<Request extends T, Response extends T>({
    required dynamic handler,
    required RpcMethodArgumentParser<Request> requestParser,
    RpcMethodArgumentParser<Response>? responseParser,
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
      // Определяем тип обработчика и добавляем соответствующий метод
      if (handler is RpcMethodClientStreamHandler<Request, Response>) {
        // Проверяем, что передан парсер ответа
        if (responseParser == null) {
          throw ArgumentError(
            'Для обработчика с ответом необходимо указать responseParser',
          );
        }

        // Добавляем метод с ответом
        serviceContract.addClientStreamingMethod<Request, Response>(
          methodName: methodName,
          handler: handler,
          argumentParser: requestParser,
          responseParser: responseParser,
        );
      } else {
        throw ArgumentError(
          'Неподдерживаемый тип обработчика: ${handler.runtimeType}',
        );
      }
    }

    // Получаем актуальный контракт метода
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.clientStreaming);

    // Создаем соответствующую реализацию метода, в зависимости от типа обработчика
    final implementation =
        RpcMethodImplementation<Request, Response>.clientStreaming(
            contract, handler);

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
      methodType: RpcMethodType.clientStreaming,
      argumentParser: requestParser,
      responseParser: responseParser,
      handler: _createHandlerAdapter<Request, Response>(
        implementation: implementation,
        requestParser: requestParser,
        responseParser: responseParser,
      ),
    );
  }

  // Вспомогательный метод для создания обработчика
  /// Создает адаптер для хэндлера, который поможет преобразовать
  /// ожидаемый тип запроса из контекста
  Future<dynamic> Function(RpcMethodContext)
      _createHandlerAdapter<Request extends T, Response extends T>({
    required RpcMethodImplementation<Request, Response> implementation,
    required RpcMethodArgumentParser<Request> requestParser,
    RpcMethodArgumentParser<Response>? responseParser,
  }) {
    return (RpcMethodContext context) async {
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
        RpcClientStreamingMarker? clientStreamingMarker;

        // Проверяем, является ли входящее сообщение маркером
        final marker = RpcMarkerHandler.tryParseMarker(requestData);
        final isClientStreaming = marker is RpcClientStreamingMarker;

        if (isClientStreaming) {
          clientStreamingMarker = marker;
          _logger?.debug(
              'Получен маркер инициализации клиентского стрима: ${clientStreamingMarker.streamId}');
        }

        // Получаем или создаем ID стрима
        String effectiveStreamId;
        if (clientStreamingMarker != null) {
          // Если получили типизированный маркер, используем его streamId
          effectiveStreamId = clientStreamingMarker.streamId;
          _logger?.debug('Используем ID из маркера: $effectiveStreamId');
        } else {
          effectiveStreamId = context.messageId;
          _logger?.debug('Используем ID сообщения: $effectiveStreamId');
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

        // Получаем стрим сообщений от клиента - стрим уже должен быть создан
        // при отправке маркера инициализации, просто подключаемся к нему
        final incomingStream = _engine
            .openStream(
          serviceName: serviceName,
          methodName: methodName,
          streamId: effectiveStreamId,
        )
            .takeWhile((data) {
          // Проверяем, является ли сообщение маркером
          final marker = RpcMarkerHandler.tryParseMarker(data);

          // Останавливаем получение данных, если получаем маркер завершения
          if (marker is RpcClientStreamEndMarker) {
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
        final resultCompleter = Completer<dynamic>();

        // Запускаем обработчик в отдельной зоне с таймаутом
        Timer? timeoutTimer;

        Future<void> runHandler() async {
          try {
            // Определяем, есть ли обработчик с ответом
            final hasResponseHandler =
                implementation._clientStreamHandler != null;

            // Если есть обработчик с ответом и ответ ожидается клиентом
            if (hasResponseHandler) {
              // Обрабатываем входящий поток и получаем ответ
              final response = await implementation.openClientStreaming(
                stream: incomingStream,
                metadata: context.metadata,
                streamId: effectiveStreamId,
              );

              // Завершаем обработку успешно с ответом
              if (!resultCompleter.isCompleted) {
                resultCompleter.complete(response);
              }
            } else {
              // Обрабатываем входящий поток без ожидания результата
              await implementation.openClientStreaming(
                stream: incomingStream,
                metadata: context.metadata,
                streamId: effectiveStreamId,
              );

              // Завершаем обработку успешно
              if (!resultCompleter.isCompleted) {
                resultCompleter.complete(RpcNull());
              }
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
        final result = await resultCompleter.future.whenComplete(() {
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

        // Если получили результат отличный от RpcNull и ожидается ответ, возвращаем его
        if (result != null && result is! RpcNull) {
          // Преобразуем результат в формат для передачи
          final response =
              result is IRpcSerializableMessage ? result.toJson() : result;

          return response;
        }

        // Иначе возвращаем служебное сообщение о успешном приеме
        return {
          '_response': true,
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

/// Класс для хранения кешированного стрима и его метаданных
class _CachedStream {
  final dynamic stream;
  final String streamId;
  final DateTime createdAt;

  _CachedStream({
    required this.stream,
    required this.streamId,
    required this.createdAt,
  });

  /// Проверяет, закрыт ли стрим
  bool get isClosed {
    if (stream is ClientStreamingBidiStream) {
      return (stream as ClientStreamingBidiStream).isClosed;
    }
    return false;
  }
}
