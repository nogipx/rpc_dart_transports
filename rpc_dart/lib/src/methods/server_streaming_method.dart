// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "серверный стриминг" (один запрос - поток ответов)
final class ServerStreamingRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект серверного стриминг RPC метода
  ServerStreamingRpcMethod(
    IRpcEndpoint endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName) {
    // Создаем логгер с консистентным именем
    _logger = RpcLogger('$serviceName.$methodName.server_stream');
  }

  /// Открывает поток данных от сервера
  ///
  /// [request] - запрос для открытия потока
  /// [metadata] - метаданные (опционально)
  /// [streamId] - ID потока (опционально, генерируется автоматически)
  /// [responseParser] - функция преобразования JSON в объект ответа
  ServerStreamingBidiStream<Request, Response>
      call<Request extends T, Response extends T>({
    required Request request,
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('server_stream');

    final startTime = DateTime.now().millisecondsSinceEpoch;
    final requestId = _endpoint.generateUniqueId('request');

    // Отправляем событие начала стрима
    _diagnostic?.reportTraceEvent(
      _diagnostic!.createTraceEvent(
        eventType: RpcTraceMetricType.methodStart,
        method: methodName,
        service: serviceName,
        requestId: requestId,
        metadata: {
          'streamId': effectiveStreamId,
          'requestType': request.runtimeType.toString(),
          ...?metadata,
        },
      ),
    );

    // Отправляем метрику о создании стрима
    _diagnostic?.reportStreamMetric(
      _diagnostic!.createStreamMetric(
        eventType: RpcStreamEventType.created,
        streamId: effectiveStreamId,
        direction: RpcStreamDirection.serverToClient,
        method: '$serviceName.$methodName',
      ),
    );

    // Создаем базовый стрим с передачей запроса
    final responseStream = _engine
        .openStream(
      serviceName: serviceName,
      methodName: methodName,
      request: request, // Теперь передаем запрос сразу при открытии потока
      metadata: metadata,
      streamId: effectiveStreamId,
    )
        .map((data) {
      if (data is Map<String, dynamic>) {
        return responseParser(data);
      }
      return data as Response;
    });

    // Мониторим счетчики сообщений для диагностики
    var messageCount = 0;
    var totalDataSize = 0;
    final monitoredStream = responseStream.map((data) {
      messageCount++;

      // Если диагностика включена, отправляем метрику о полученном сообщении
      if (_diagnostic != null) {
        // Оцениваем размер данных (приблизительно)
        final dataSize = data.toString().length;
        totalDataSize += dataSize;

        // Отправляем метрику о полученном сообщении
        unawaited(_diagnostic!.reportStreamMetric(
          _diagnostic!.createStreamMetric(
            eventType: RpcStreamEventType.messageReceived,
            streamId: effectiveStreamId,
            direction: RpcStreamDirection.serverToClient,
            method: '$serviceName.$methodName',
            dataSize: dataSize,
            messageCount: messageCount,
          ),
        ));
      }

      return data;
    });

    // Создаем BidiStream
    final bidiStream = BidiStream<Request, Response>(
      responseStream: monitoredStream,
      sendFunction: (actualRequest) {
        // Преобразуем запрос в JSON, если это RpcMessage
        final processedRequest = actualRequest is RpcMessage
            ? actualRequest.toJson()
            : actualRequest;

        // Отправляем запрос в стрим
        _engine.sendStreamData(
          streamId: effectiveStreamId,
          data: processedRequest,
          serviceName: serviceName,
          methodName: methodName,
        );

        // Отправляем метрику об отправке сообщения
        _diagnostic?.reportStreamMetric(
          _diagnostic!.createStreamMetric(
            eventType: RpcStreamEventType.messageSent,
            streamId: effectiveStreamId,
            direction: RpcStreamDirection.clientToServer,
            method: '$serviceName.$methodName',
            dataSize: processedRequest.toString().length,
          ),
        );
      },
      closeFunction: () async {
        final endTime = DateTime.now().millisecondsSinceEpoch;
        final duration = endTime - startTime;

        // Закрываем стрим со стороны клиента
        _engine.closeStream(
          streamId: effectiveStreamId,
          serviceName: serviceName,
          methodName: methodName,
        );

        // Отправляем метрику о закрытии стрима
        _diagnostic?.reportStreamMetric(
          _diagnostic!.createStreamMetric(
            eventType: RpcStreamEventType.closed,
            streamId: effectiveStreamId,
            direction: RpcStreamDirection.serverToClient,
            method: '$serviceName.$methodName',
            messageCount: messageCount,
            throughput: messageCount > 0 ? (totalDataSize / duration) : 0,
            duration: duration,
          ),
        );

        // Отправляем событие завершения метода
        _diagnostic?.reportTraceEvent(
          _diagnostic!.createTraceEvent(
            eventType: RpcTraceMetricType.methodEnd,
            method: methodName,
            service: serviceName,
            requestId: requestId,
            durationMs: duration,
            metadata: {
              'streamId': effectiveStreamId,
              'messageCount': messageCount,
              'totalDataSize': totalDataSize,
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
              'messageCount': messageCount,
              'totalDataSize': totalDataSize,
            },
          ),
        );
      },
    );

    // Оборачиваем в ServerStreamingBidiStream и сразу возвращаем,
    // больше не нужно вызывать sendRequest, так как запрос уже отправлен
    return ServerStreamingBidiStream<Request, Response>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );
  }

  /// Регистрирует обработчик серверного стриминг метода
  ///
  /// [handler] - функция обработки запроса, возвращающая поток ответов
  /// [requestParser] - функция преобразования JSON в объект запроса
  /// [responseParser] - функция преобразования JSON в объект ответа
  void register<Request extends T, Response extends T>({
    required RpcMethodServerStreamHandler<Request, Response> handler,
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
      serviceContract.addServerStreamingMethod<Request, Response>(
        methodName: methodName,
        handler: handler,
        argumentParser: requestParser,
        responseParser: responseParser,
      );
    }

    // Получаем актуальный контракт метода
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.serverStreaming);
    final implementation =
        RpcMethodImplementation.serverStreaming(contract, handler);

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
      methodType: RpcMethodType.serverStreaming,
      argumentParser: requestParser,
      responseParser: responseParser,
      handler: (RpcMethodContext context) async {
        try {
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

          // Конвертируем запрос в типизированный, если нужно
          final typedRequest = (context.payload is Map<String, dynamic>)
              ? requestParser(context.payload)
              : context.payload;

          // Получаем ID сообщения из контекста
          final messageId = context.messageId;

          // Отправляем метрику о создании стрима на стороне сервера
          _diagnostic?.reportStreamMetric(
            _diagnostic!.createStreamMetric(
              eventType: RpcStreamEventType.created,
              streamId: messageId,
              direction: RpcStreamDirection.serverToClient,
              method: '$serviceName.$methodName',
            ),
          );

          // Запускаем обработку стрима в фоновом режиме
          _activateStreamHandler<Request, Response>(
            messageId,
            typedRequest,
            implementation,
            responseParser,
          );

          // Начинаем отслеживать метрики стрима
          _monitorStreamMetrics(messageId, startTime, requestId);

          // Возвращаем только подтверждение принятия запроса
          return {'status': 'streaming'};
        } catch (e, stackTrace) {
          // Логируем ошибку
          _logger?.error(
            'Ошибка при запуске серверного стрима: $e',
            error: e,
            stackTrace: stackTrace,
          );

          _diagnostic?.reportErrorMetric(
            _diagnostic!.createErrorMetric(
              errorType: RpcErrorMetricType.unexpectedError,
              message:
                  'Ошибка при запуске серверного стрима $serviceName.$methodName: $e',
              requestId: context.messageId,
              method: '$serviceName.$methodName',
              stackTrace: stackTrace.toString(),
              details: {'errorType': e.runtimeType.toString()},
            ),
          );

          rethrow;
        }
      },
    );
  }

  /// Активирует обработчик стрима и связывает его с транспортом
  void _activateStreamHandler<Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>(
    String messageId,
    Request request,
    RpcMethodImplementation<Request, Response> implementation,
    RpcMethodResponseParser<Response> responseParser,
  ) {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    var messageCount = 0;
    var totalDataSize = 0;
    // Запускаем стрим от обработчика
    final serverStreamBidi = implementation.openServerStreaming(request);

    // Подписываемся на события и пересылаем их через публичный API Endpoint
    serverStreamBidi.listen((data) {
      messageCount++;

      // Преобразуем данные и отправляем их в поток
      final processedData = data is RpcMessage ? data.toJson() : data;

      // Оцениваем размер данных (приблизительно)
      final dataSize = processedData.toString().length;
      totalDataSize += dataSize;

      _engine.sendStreamData(
        streamId: messageId,
        data: processedData,
        serviceName: serviceName,
        methodName: methodName,
      );

      // Отправляем метрику об отправленном сообщении
      _diagnostic?.reportStreamMetric(
        _diagnostic!.createStreamMetric(
          eventType: RpcStreamEventType.messageSent,
          streamId: messageId,
          direction: RpcStreamDirection.serverToClient,
          method: '$serviceName.$methodName',
          dataSize: dataSize,
          messageCount: messageCount,
        ),
      );
    }, onError: (error, stackTrace) {
      // Отправляем ошибку
      _logger?.error(
        'Ошибка в серверном стриме: $error',
        error: error,
        stackTrace: stackTrace,
      );

      _engine.sendStreamError(
        streamId: messageId,
        errorMessage: error.toString(),
        serviceName: serviceName,
        methodName: methodName,
      );

      // Отправляем метрику об ошибке в стриме
      _diagnostic?.reportErrorMetric(
        _diagnostic!.createErrorMetric(
          errorType: RpcErrorMetricType.unexpectedError,
          message: 'Ошибка в серверном стриме $serviceName.$methodName: $error',
          requestId: messageId,
          method: '$serviceName.$methodName',
          stackTrace: stackTrace.toString(),
          details: {'streamId': messageId},
        ),
      );

      // Отправляем метрику о завершении стрима с ошибкой
      _diagnostic?.reportStreamMetric(
        _diagnostic!.createStreamMetric(
          eventType: RpcStreamEventType.error,
          streamId: messageId,
          direction: RpcStreamDirection.serverToClient,
          method: '$serviceName.$methodName',
          messageCount: messageCount,
          dataSize: totalDataSize,
          error: {'error': error.toString()},
        ),
      );
    }, onDone: () {
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final duration = endTime - startTime;

      _logger?.debug(
        'Серверный стрим завершен',
      );

      // Закрываем стрим с указанием serviceName и methodName для middleware
      _engine.closeStream(
        streamId: messageId,
        serviceName: serviceName,
        methodName: methodName,
      );

      // Отправляем метрику о нормальном завершении стрима
      _diagnostic?.reportStreamMetric(
        _diagnostic!.createStreamMetric(
          eventType: RpcStreamEventType.closed,
          streamId: messageId,
          direction: RpcStreamDirection.serverToClient,
          method: '$serviceName.$methodName',
          messageCount: messageCount,
          throughput: messageCount > 0 ? (totalDataSize / duration) : 0,
          duration: duration,
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
          metadata: {
            'streamId': messageId,
            'messageCount': messageCount,
            'totalDataSize': totalDataSize,
          },
        ),
      );
    });
  }

  /// Мониторит метрики стрима через определенные интервалы
  void _monitorStreamMetrics(String streamId, int startTime, String requestId) {
    // Этот метод может быть использован для периодической отправки метрик о состоянии стрима
    // Например, можно запустить Timer, который будет отправлять статистику каждые N секунд
    // Но для простоты оставим его пустым
  }
}
