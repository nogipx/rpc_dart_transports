// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Интерфейс обработчика сообщений
abstract class _IMessageHandler {
  Future<void> handleMessage(RpcMessage message);
}

/// Обработчик для сообщений с запросами
final class _RequestMessageHandler implements _IMessageHandler {
  final _RpcEngineImpl _engine;
  final RpcLogger _logger = RpcLogger('RequestHandler');

  _RequestMessageHandler(this._engine);

  @override
  Future<void> handleMessage(RpcMessage message) async {
    final serviceName = message.serviceName;
    final methodName = message.methodName;

    if (serviceName == null || methodName == null) {
      await _engine._sendErrorMessage(
        message.messageId,
        'Не указаны serviceName или methodName',
        message.headerMetadata,
      );

      // Отправляем статус ошибки
      await _engine.sendStatus(
        requestId: message.messageId,
        statusCode: RpcStatusCode.invalidArgument,
        message: 'Не указаны serviceName или methodName',
        metadata: message.headerMetadata,
      );

      return;
    }

    var methodHandler = _engine.registry.findMethod(serviceName, methodName);
    if (methodHandler == null) {
      await _engine._sendErrorMessage(
        message.messageId,
        'Метод не найден: $serviceName.$methodName',
        message.headerMetadata,
      );

      // Отправляем статус ошибки
      await _engine.sendStatus(
        requestId: message.messageId,
        statusCode: RpcStatusCode.notFound,
        message: 'Метод не найден: $serviceName.$methodName',
        metadata: message.headerMetadata,
      );

      return;
    }

    var direction = RpcDataDirection.fromRemote;

    try {
      // Используем само сообщение как контекст
      final IRpcContext context = message;

      // Применяем middleware для обработки запроса
      final requestResult = await _engine._middlewareExecutor.executeRequest(
        serviceName,
        methodName,
        message.payload,
        context,
        RpcDataDirection.fromRemote,
      );

      // Используем обновленный контекст от middleware
      final updatedRequestContext = requestResult.context is RpcMessage
          ? (requestResult.context as RpcMessage)
              .withPayload(requestResult.payload)
          : requestResult.context;

      // Проверяем наличие обработчика
      if (methodHandler.getHandler() == null) {
        throw RpcCustomException(
          customMessage:
              'Не найден обработчик для метода $serviceName.$methodName',
          debugLabel: 'RpcEngineImpl._handleRequest',
        );
      }

      // Вызываем обработчик с обновленным контекстом
      dynamic result =
          await _callMethodHandler(methodHandler, updatedRequestContext);

      // Изменяем направление на отправку
      direction = RpcDataDirection.toRemote;

      // Применяем middleware для обработки ответа
      final responseResult = await _engine._middlewareExecutor.executeResponse(
        serviceName,
        methodName,
        result,
        updatedRequestContext,
        RpcDataDirection.toRemote,
      );

      // Используем финальный контекст после применения всех middleware
      final finalContext = responseResult.context;

      // Проверяем, является ли результат ServerStreamingBidiStream
      if (result is ServerStreamingBidiStream) {
        _logger.debug(
            'Обнаружен ServerStreamingBidiStream, настраиваем обработку данных');

        // Устанавливаем обработчик для данных из стрима
        // Используем доступ к свойству responseStream в RpcStream, от которого наследуется ServerStreamingBidiStream
        result.listen(
          (data) async {
            // Отправляем каждый элемент как streamData
            await _engine.sendStreamData(
              streamId: message.messageId,
              data: data,
              serviceName: serviceName,
              methodName: methodName,
            );
          },
          onError: (error) async {
            // При ошибке отправляем сообщение об ошибке
            await _engine.sendStreamError(
              streamId: message.messageId,
              errorMessage: error.toString(),
              serviceName: serviceName,
              methodName: methodName,
            );
          },
          onDone: () async {
            // При завершении закрываем поток
            await _engine.closeStream(
              streamId: message.messageId,
              serviceName: serviceName,
              methodName: methodName,
            );
          },
        );

        // Отправляем пустой ответ, стримы будут обрабатываться отдельно
        await _engine._sendMessage(
          RpcMessage(
            type: RpcMessageType.response,
            messageId: message.messageId,
            payload: 'Stream started',
            headerMetadata: finalContext.headerMetadata,
            trailerMetadata: finalContext.trailerMetadata,
            debugLabel: _engine.debugLabel,
          ),
        );
      }
      // Проверяем, является ли результат ClientStreamingBidiStream
      else if (result is ClientStreamingBidiStream) {
        _logger.debug(
            'Обнаружен ClientStreamingBidiStream, настраиваем обработку данных');

        // Для ClientStreamingBidiStream не нужно подписываться на стрим,
        // так как он уже имеет внутренний механизм обработки.
        // Просто отправляем пустой ответ, чтобы подтвердить инициализацию стрима.
        await _engine._sendMessage(
          RpcMessage(
            type: RpcMessageType.response,
            messageId: message.messageId,
            payload: 'Stream started',
            headerMetadata: finalContext.headerMetadata,
            trailerMetadata: finalContext.trailerMetadata,
            debugLabel: _engine.debugLabel,
          ),
        );
      }
      // Проверяем, является ли результат BidiStream
      else if (result is BidiStream) {
        _logger.debug('Обнаружен BidiStream, настраиваем обработку данных');

        // Устанавливаем обработчик для данных из стрима
        result.listen(
          (data) async {
            // Отправляем каждый элемент как streamData
            await _engine.sendStreamData(
              streamId: message.messageId,
              data: data,
              serviceName: serviceName,
              methodName: methodName,
            );
          },
          onError: (error) async {
            // При ошибке отправляем сообщение об ошибке
            await _engine.sendStreamError(
              streamId: message.messageId,
              errorMessage: error.toString(),
              serviceName: serviceName,
              methodName: methodName,
            );
          },
          onDone: () async {
            // При завершении закрываем поток
            await _engine.closeStream(
              streamId: message.messageId,
              serviceName: serviceName,
              methodName: methodName,
            );
          },
        );

        // Отправляем пустой ответ, стримы будут обрабатываться отдельно
        await _engine._sendMessage(
          RpcMessage(
            type: RpcMessageType.response,
            messageId: message.messageId,
            payload: 'Stream started',
            headerMetadata: finalContext.headerMetadata,
            trailerMetadata: finalContext.trailerMetadata,
            debugLabel: _engine.debugLabel,
          ),
        );
      } else {
        // Отправляем обычный ответ
        await _engine._sendMessage(
          RpcMessage(
            type: RpcMessageType.response,
            messageId: message.messageId,
            payload: responseResult.payload,
            headerMetadata: finalContext.headerMetadata,
            trailerMetadata: finalContext.trailerMetadata,
            debugLabel: _engine.debugLabel,
          ),
        );
      }

      // Отправляем статус успешного завершения
      await _engine.sendStatus(
        requestId: message.messageId,
        statusCode: RpcStatusCode.ok,
        message: 'OK',
        metadata: finalContext.headerMetadata,
        serviceName: serviceName,
        methodName: methodName,
      );
    } catch (e, stackTrace) {
      await _handleRequestError(
          message, serviceName, methodName, e, stackTrace, direction);
    }
  }

  /// Вызывает обработчик метода с учетом различных сценариев вызова
  Future<dynamic> _callMethodHandler(MethodRegistration methodHandler,
      IRpcContext updatedRequestContext) async {
    final handler = methodHandler.getHandler();
    _logger.debug(
        'ДИАГНОСТИКА: _callMethodHandler: Вызов обработчика ${methodHandler.methodName}, тип метода: ${methodHandler.methodType}');

    try {
      // Проверяем, является ли контекст RpcMessage
      if (updatedRequestContext is RpcMessage) {
        final payload = updatedRequestContext.payload;
        _logger.debug(
            'ДИАГНОСТИКА: _callMethodHandler: Контекст является RpcMessage, payload: $payload');

        // Проверяем, является ли payload маркером двунаправленного стрима
        if (payload is Map<String, dynamic> &&
            payload['_bidirectional'] == true &&
            methodHandler.methodType == RpcMethodType.bidirectional) {
          // Это маркер инициализации двунаправленного стрима
          _logger.debug(
              'ДИАГНОСТИКА: _callMethodHandler: Обнаружен маркер двунаправленного стриминга, вызываем invokeBidirectional');

          // Важно: убедимся, что у нас есть контроллер для этого стрима
          if (payload['_streamId'] != null) {
            final streamId = payload['_streamId'] as String;
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: Проверяем наличие контроллера для стрима $streamId');

            if (!_engine._streamManager.hasStream(streamId)) {
              _logger.debug(
                  'ДИАГНОСТИКА: _callMethodHandler: Создаем контроллер для двунаправленного стрима: $streamId');
              _engine._streamManager.getOrCreateStream(streamId);
            } else {
              _logger.debug(
                  'ДИАГНОСТИКА: _callMethodHandler: Контроллер для стрима $streamId уже существует');
            }
          }

          try {
            final result = methodHandler.invokeBidirectional();
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: invokeBidirectional успешно вызван, результат: ${result.runtimeType}');
            return result;
          } catch (e) {
            _logger.error(
                'ДИАГНОСТИКА: _callMethodHandler: Ошибка при вызове invokeBidirectional: $e');
            rethrow;
          }
        }

        // Если это обычное сообщение для двунаправленного стрима, перенаправляем его в контроллер
        if (methodHandler.methodType == RpcMethodType.bidirectional) {
          _logger.debug(
              'ДИАГНОСТИКА: _callMethodHandler: Перенаправляем обычное сообщение в двунаправленный стрим: ${updatedRequestContext.messageId}');

          // Проверяем наличие контроллера для этого стрима
          final streamId = updatedRequestContext.messageId;
          if (_engine._streamManager.hasStream(streamId)) {
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: Найден контроллер для стрима: $streamId');

            // Получаем контроллер и отправляем сообщение
            final controller =
                _engine._streamManager.getStreamController(streamId);
            if (controller != null && !controller.isClosed) {
              _logger.debug(
                  'ДИАГНОСТИКА: _callMethodHandler: Добавляем данные в контроллер: $payload');
              controller.add(payload);

              // Возвращаем пустой результат, так как данные были обработаны
              _logger.debug(
                  'ДИАГНОСТИКА: _callMethodHandler: Сообщение успешно перенаправлено в стрим');
              return null;
            } else {
              _logger.error(
                  'ДИАГНОСТИКА: _callMethodHandler: Контроллер для стрима $streamId закрыт или null');
            }
          } else {
            // Не удалось найти контроллер, что странно - логируем и продолжаем стандартную обработку
            _logger.error(
                'ДИАГНОСТИКА: _callMethodHandler: Не найден контроллер для стрима: $streamId');
          }
        }

        // Проверяем, является ли payload маркером клиентского стрима
        if (payload is Map<String, dynamic> &&
            payload['_clientStreaming'] == true &&
            methodHandler.methodType == RpcMethodType.clientStreaming) {
          // Это маркер инициализации клиентского стрима
          _logger.debug(
              'ДИАГНОСТИКА: _callMethodHandler: Обнаружен маркер клиентского стриминга, вызываем invokeClientStreaming');

          // Важно: убедимся, что у нас есть контроллер для этого стрима
          if (payload['_streamId'] != null) {
            final streamId = payload['_streamId'] as String;
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: Проверяем наличие контроллера для стрима $streamId');

            if (!_engine._streamManager.hasStream(streamId)) {
              _logger.debug(
                  'ДИАГНОСТИКА: _callMethodHandler: Создаем контроллер для клиентского стрима: $streamId');
              _engine._streamManager.getOrCreateStream(streamId);
            } else {
              _logger.debug(
                  'ДИАГНОСТИКА: _callMethodHandler: Контроллер для стрима $streamId уже существует');
            }
          }

          try {
            final result = methodHandler.invokeClientStreaming();
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: invokeClientStreaming успешно вызван, результат: ${result.runtimeType}');
            return result;
          } catch (e) {
            _logger.error(
                'ДИАГНОСТИКА: _callMethodHandler: Ошибка при вызове invokeClientStreaming: $e');
            rethrow;
          }
        }

        // Если запрос был получен в RpcMessage, пробуем сначала извлечь payload для типизированного обработчика
        if (payload != null && methodHandler.argumentParser != null) {
          try {
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: Попытка парсинга типизированного запроса');
            final typedRequest = methodHandler.argumentParser!(payload);
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: Запрос успешно приведен к типу: ${typedRequest.runtimeType}');
            final result = await handler(typedRequest);
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: Вызов обработчика с типизированным запросом успешен, результат: ${result?.runtimeType}');
            return result;
          } catch (e) {
            // Если это не сработало, пробуем вызвать как функцию с контекстом
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: Ошибка типизированного вызова: $e, пробуем с контекстом');
            final result = await handler(updatedRequestContext);
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: Вызов с контекстом успешен, результат: ${result?.runtimeType}');
            return result;
          }
        } else {
          // Стандартный случай - пробуем вызвать с контекстом
          _logger.debug(
              'ДИАГНОСТИКА: _callMethodHandler: Вызов обработчика со стандартным контекстом');
          final result = await handler(updatedRequestContext);
          _logger.debug(
              'ДИАГНОСТИКА: _callMethodHandler: Вызов со стандартным контекстом успешен, результат: ${result?.runtimeType}');
          return result;
        }
      } else {
        // Стандартный случай - пробуем вызвать с контекстом
        _logger.debug(
            'ДИАГНОСТИКА: _callMethodHandler: Вызов обработчика с нестандартным контекстом типа: ${updatedRequestContext.runtimeType}');
        final result = await handler(updatedRequestContext);
        _logger.debug(
            'ДИАГНОСТИКА: _callMethodHandler: Вызов с нестандартным контекстом успешен, результат: ${result?.runtimeType}');
        return result;
      }
    } catch (e, stack) {
      _logger.error(
          'ДИАГНОСТИКА: _callMethodHandler: Ошибка при вызове обработчика: $e',
          error: e,
          stackTrace: stack);
      if (e is NoSuchMethodError &&
          e.toString().contains('mismatched arguments')) {
        // Если это ошибка несовпадения аргументов, пробуем вызвать без аргументов
        _logger.debug(
            'ДИАГНОСТИКА: _callMethodHandler: Обнаружена ошибка несовпадения аргументов, пробуем вызвать без аргументов');
        try {
          final result = await handler();
          _logger.debug(
              'ДИАГНОСТИКА: _callMethodHandler: Вызов без аргументов успешен, результат: ${result?.runtimeType}');
          return result;
        } catch (innerE, innerStack) {
          _logger.error(
              'ДИАГНОСТИКА: _callMethodHandler: Ошибка при вызове без аргументов: $innerE',
              error: innerE,
              stackTrace: innerStack);
          if (innerE is TypeError &&
              methodHandler.argumentParser != null &&
              updatedRequestContext.payload != null) {
            // Если это ошибка типа, пробуем распарсить запрос и передать его напрямую
            _logger.debug(
                'ДИАГНОСТИКА: _callMethodHandler: Обнаружена ошибка типа, пробуем парсинг запроса');
            try {
              final typedRequest =
                  methodHandler.argumentParser!(updatedRequestContext.payload);
              _logger.debug(
                  'ДИАГНОСТИКА: _callMethodHandler: Парсинг запроса успешен: ${typedRequest.runtimeType}');
              final result = await handler(typedRequest);
              _logger.debug(
                  'ДИАГНОСТИКА: _callMethodHandler: Вызов с типизированным запросом успешен, результат: ${result?.runtimeType}');
              return result;
            } catch (parsingE, parsingStackTrace) {
              _logger.error(
                  'ДИАГНОСТИКА: _callMethodHandler: Ошибка при парсинге запроса: $parsingE',
                  error: parsingE,
                  stackTrace: parsingStackTrace);
              rethrow;
            }
          } else {
            _logger.error(
                'ДИАГНОСТИКА: _callMethodHandler: Ошибка при вызове обработчика без аргументов: $innerE',
                error: innerE,
                stackTrace: innerStack);
            rethrow;
          }
        }
      } else {
        // Если это другая ошибка, пробрасываем её
        _logger.error(
            'ДИАГНОСТИКА: _callMethodHandler: Пробрасываем ошибку: $e',
            error: e,
            stackTrace: stack);
        rethrow;
      }
    }
  }

  /// Обрабатывает ошибки, возникающие при обработке запросов
  Future<void> _handleRequestError(
    RpcMessage message,
    String serviceName,
    String methodName,
    Object e,
    StackTrace stackTrace,
    RpcDataDirection direction,
  ) async {
    // Создаем контекст для ошибки из сообщения
    final errorContext = message;

    // Применяем middleware для обработки ошибки
    final errorResult = await _engine._middlewareExecutor.executeError(
      serviceName,
      methodName,
      e,
      stackTrace,
      errorContext,
      direction,
    );

    // Используем финальный контекст после обработки ошибки
    final finalErrorContext = errorResult.context;
    final processedError = errorResult.payload;

    // Определяем тип ошибки для статуса
    RpcStatusCode statusCode;
    if (e is ArgumentError || e is FormatException) {
      statusCode = RpcStatusCode.invalidArgument;
    } else if (e is TimeoutException) {
      statusCode = RpcStatusCode.deadlineExceeded;
    } else if (e is StateError) {
      statusCode = RpcStatusCode.failedPrecondition;
    } else if (e is UnimplementedError) {
      statusCode = RpcStatusCode.unimplemented;
    } else {
      statusCode = RpcStatusCode.internal;
    }

    // Отправляем статус ошибки
    await _engine.sendStatus(
      requestId: message.messageId,
      statusCode: statusCode,
      message: processedError.toString(),
      details: {
        'error': processedError.toString(),
        'stackTrace': stackTrace.toString(),
      },
      metadata: finalErrorContext.headerMetadata,
      serviceName: serviceName,
      methodName: methodName,
    );

    // Для обратной совместимости также отправляем обычное сообщение об ошибке
    await _engine._sendErrorMessage(
      message.messageId,
      processedError.toString(),
      finalErrorContext.headerMetadata,
      finalErrorContext.trailerMetadata,
    );
  }
}

/// Обработчик для сообщений с ответами
final class _ResponseMessageHandler implements _IMessageHandler {
  final _RpcEngineImpl _engine;

  _ResponseMessageHandler(this._engine);

  @override
  Future<void> handleMessage(RpcMessage message) async {
    final completer =
        _engine._requestManager.getAndRemoveRequest(message.messageId);
    if (completer == null || completer.isCompleted) {
      return;
    }

    // Проверяем, содержит ли ответ маркер статуса
    if (RpcServiceMarker.checkIsServiceMessage(
      message.payload,
      specificMarkerType: RpcMarkerType.status,
    )) {
      try {
        // Парсим маркер статуса
        final statusMarker = RpcStatusMarker.fromJson(message.payload);

        // Если статус OK, завершаем запрос успешно с пустым результатом
        if (statusMarker.code == RpcStatusCode.ok) {
          completer.complete(null);
        } else {
          // Иначе завершаем с ошибкой
          completer.completeError(
              'RPC Error [${statusMarker.code.name}]: ${statusMarker.message}');
        }
      } catch (e) {
        // При ошибке парсинга просто передаем payload как есть
        completer.complete(message.payload);
      }
    } else {
      // Обычный ответ - просто передаем payload
      completer.complete(message.payload);
    }
  }
}

/// Обработчик для данных, передаваемых в потоке
final class _StreamDataMessageHandler implements _IMessageHandler {
  final _RpcEngineImpl _engine;
  final RpcLogger _logger = RpcLogger('StreamDataHandler');

  _StreamDataMessageHandler(this._engine);

  @override
  Future<void> handleMessage(RpcMessage message) async {
    final controller =
        _engine._streamManager.getStreamController(message.messageId);
    if (controller == null || controller.isClosed) {
      _logger.debug(
          'StreamData: Контроллер для ${message.messageId} не найден или закрыт');

      // Попробуем создать контроллер, если его нет
      if (message.serviceName != null && message.methodName != null) {
        _logger.debug(
            'StreamData: Пытаемся создать новый контроллер для ${message.messageId}');
        final newController = StreamController<dynamic>.broadcast();
        _engine._streamManager._streamControllers[message.messageId] =
            newController;
        // Продолжаем с новым контроллером
        await _processStreamDataMessage(message, newController);
      }

      return; // Нет активного контроллера для этого потока
    }

    await _processStreamDataMessage(message, controller);
  }

  /// Обрабатывает сообщение streamData с переданным контроллером
  Future<void> _processStreamDataMessage(
      RpcMessage message, StreamController<dynamic> controller) async {
    _logger.debug(
        'StreamData: Получено сообщение типа ${message.type} для стрима ${message.messageId}');
    _logger.debug(
        'StreamData: Payload=${message.payload}, metadata=${message.headerMetadata}');

    // Обработка пустых данных для совместимости с MsgPack
    dynamic payload = message.payload;
    if (RpcServiceMarker.checkIsEmptyServiceMessage(payload)) {
      _logger.debug('StreamData: Пустые данные, заменяем на пустой объект');
      payload = {};
    }

    // Проверяем, является ли сообщение служебным маркером
    if (RpcServiceMarker.checkIsServiceMessage(payload)) {
      _logger.debug(
          'StreamData: Обнаружен служебный маркер в payload типа: ${payload.runtimeType}');
      await _handleMarker(message, controller, payload);
      return; // Завершаем обработку после маркера
    }

    _logger.debug('StreamData: Перенаправляем данные в стрим: $payload');

    // Если известны имена сервиса и метода, применяем middleware
    if (message.serviceName != null && message.methodName != null) {
      _logger.debug(
          'StreamData: Вызов middleware для ${message.serviceName}.${message.methodName}');
      try {
        final processedData =
            await _engine._middlewareExecutor.executeStreamData(
          message.serviceName!,
          message.methodName!,
          payload,
          message.messageId,
          RpcDataDirection.fromRemote, // Данные получены от удаленной стороны
        );

        _logger.debug(
            'StreamData: Middleware применен успешно, результат: $processedData');
        _logger.debug(
            'StreamData: Добавляем данные в контроллер ${message.messageId}');
        controller.add(processedData);
      } catch (error, stackTrace) {
        _logger.error('StreamData: Ошибка в middleware: $error',
            error: error, stackTrace: stackTrace);
        controller.addError(error, stackTrace);
      }
    } else {
      _logger.debug(
          'StreamData: Не указаны serviceName/methodName, отправляем данные напрямую');
      controller.add(payload);
    }
  }

  /// Обрабатывает маркеры в потоке данных
  Future<void> _handleMarker(
    RpcMessage message,
    StreamController<dynamic> controller,
    dynamic payload,
  ) async {
    _logger.debug(
        'ДИАГНОСТИКА: _handleMarker: Начало обработки маркера для ${message.messageId}');

    // Проверяем тип маркера
    if (payload is Map<String, dynamic>) {
      _logger.debug('ДИАГНОСТИКА: _handleMarker: Содержимое маркера: $payload');

      // Если есть ключ _markerType, выводим его
      if (payload.containsKey('_markerType')) {
        _logger.debug(
            'ДИАГНОСТИКА: _handleMarker: Тип маркера: ${payload['_markerType']}');
      }

      // Обработка маркера завершения потока
      if (payload['_endOfStream'] == true) {
        _logger.debug(
            'ДИАГНОСТИКА: _handleMarker: Обработка маркера завершения стрима ${message.messageId}');
        // Закрываем контроллер, если еще не закрыт
        if (!controller.isClosed) {
          _logger.debug(
              'ДИАГНОСТИКА: _handleMarker: Закрываем контроллер ${message.messageId}');
          await controller.close();
          _logger.debug(
              'ДИАГНОСТИКА: _handleMarker: Контроллер ${message.messageId} закрыт');
        } else {
          _logger.debug(
              'ДИАГНОСТИКА: _handleMarker: Контроллер ${message.messageId} уже был закрыт');
        }
        // Удаляем контроллер из менеджера
        _logger.debug(
            'ДИАГНОСТИКА: _handleMarker: Удаляем контроллер ${message.messageId} из менеджера');
        _engine._streamManager.removeStreamController(message.messageId);
        _logger.debug(
            'ДИАГНОСТИКА: _handleMarker: Контроллер ${message.messageId} удален');
        return;
      }

      // Обработка маркера ошибки
      if (payload['_error'] != null) {
        _logger.debug(
            'ДИАГНОСТИКА: _handleMarker: Обработка маркера ошибки для ${message.messageId}');
        final errorMessage = payload['_error'];
        final errorDetails = payload['_errorDetails'];
        _logger.debug(
            'ДИАГНОСТИКА: _handleMarker: Сообщение ошибки: $errorMessage, детали: $errorDetails');

        // Исправляем создание RpcException согласно API класса
        // Используем строку ошибки напрямую вместо создания объекта
        final error =
            'RPC Error: $errorMessage ${errorDetails != null ? "(details: $errorDetails)" : ""}';
        // Добавляем ошибку в контроллер, если он еще не закрыт
        if (!controller.isClosed) {
          _logger.debug(
              'ДИАГНОСТИКА: _handleMarker: Добавляем ошибку в контроллер ${message.messageId}');
          controller.addError(error);
          _logger.debug(
              'ДИАГНОСТИКА: _handleMarker: Ошибка добавлена в контроллер ${message.messageId}');
        } else {
          _logger.debug(
              'ДИАГНОСТИКА: _handleMarker: Контроллер ${message.messageId} закрыт, ошибка игнорируется');
        }
        return;
      }

      // Проверка на маркер статуса, эти тоже нужно обрабатывать
      if (payload['_markerType'] == 'status') {
        _logger.debug(
            'ДИАГНОСТИКА: _handleMarker: Обработка маркера статуса для ${message.messageId}');
        final statusCode = payload['code'];
        final statusMessage = payload['message'];
        _logger.debug(
            'ДИАГНОСТИКА: _handleMarker: Код статуса: $statusCode, сообщение: $statusMessage');

        // Если статус не OK, добавляем ошибку
        if (statusCode != 0) {
          _logger.debug(
              'ДИАГНОСТИКА: _handleMarker: Статус не OK, добавляем ошибку в контроллер ${message.messageId}');
          if (!controller.isClosed) {
            controller.addError(
                'RPC Status Error: $statusMessage (code: $statusCode)');
            _logger.debug(
                'ДИАГНОСТИКА: _handleMarker: Ошибка статуса добавлена в контроллер ${message.messageId}');
          }
        } else {
          _logger.debug(
              'ДИАГНОСТИКА: _handleMarker: Статус OK, игнорируем для ${message.messageId}');
        }
        return;
      }

      // Для других типов маркеров (инициализация и т.д.)
      // Игнорируем их в потоке streamData, так как они уже были обработаны
      _logger.debug(
          'ДИАГНОСТИКА: _handleMarker: Игнорирование служебного маркера для ${message.messageId}');
      return;
    }

    // Если это не распознанный маркер, обрабатываем как обычные данные
    _logger.debug(
        'ДИАГНОСТИКА: _handleMarker: Необрабатываемый маркер, передаем как данные: $payload');
    controller.add(payload);
    _logger.debug(
        'ДИАГНОСТИКА: _handleMarker: Данные добавлены в контроллер ${message.messageId}');
  }
}

/// Обработчик для завершения потока
final class _StreamEndMessageHandler implements _IMessageHandler {
  final _RpcEngineImpl _engine;

  _StreamEndMessageHandler(this._engine);

  @override
  Future<void> handleMessage(RpcMessage message) async {
    final controller =
        _engine._streamManager.removeStreamController(message.messageId);
    if (controller != null && !controller.isClosed) {
      // Если известны имена сервиса и метода, применяем middleware
      if (message.serviceName != null && message.methodName != null) {
        _engine._middlewareExecutor
            .executeStreamEnd(
          message.serviceName!,
          message.methodName!,
          message.messageId,
        )
            .then((_) {
          controller.close();
        }).catchError((error) {
          controller.addError(error);
          controller.close();
        });
      } else {
        controller.close();
      }
    }
  }
}

/// Обработчик для сообщений с ошибками
final class _ErrorMessageHandler implements _IMessageHandler {
  final _RpcEngineImpl _engine;
  final RpcLogger _logger = RpcLogger('ErrorHandler');

  _ErrorMessageHandler(this._engine);

  @override
  Future<void> handleMessage(RpcMessage message) async {
    // Преобразуем ошибку в безопасный объект ошибки
    Object errorObject;

    try {
      // Пытаемся безопасно использовать payload
      if (message.payload == null) {
        errorObject = Exception('Неизвестная ошибка');
      } else if (message.payload is String) {
        errorObject = Exception(message.payload);
      } else if (message.payload is Exception || message.payload is Error) {
        // Если это уже исключение, используем его напрямую
        errorObject = message.payload;
      } else {
        // Безопасно преобразуем любой объект в исключение
        errorObject = Exception(message.payload.toString());
      }
    } catch (e) {
      _logger.error('Ошибка при обработке объекта ошибки: $e');
      errorObject = Exception('Ошибка при обработке сообщения');
    }

    final completer =
        _engine._requestManager.getAndRemoveRequest(message.messageId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(errorObject);
    }

    final controller =
        _engine._streamManager.getStreamController(message.messageId);
    if (controller != null && !controller.isClosed) {
      controller.addError(errorObject);
    }
  }
}

/// Обработчик для ping-сообщений
final class _PingMessageHandler implements _IMessageHandler {
  final _RpcEngineImpl _engine;

  _PingMessageHandler(this._engine);

  @override
  Future<void> handleMessage(RpcMessage message) async {
    await _engine._sendMessage(
      RpcMessage(
        type: RpcMessageType.pong,
        messageId: message.messageId,
        payload: message.payload,
        headerMetadata: message.headerMetadata,
        debugLabel: _engine.debugLabel,
      ),
    );
  }
}

/// Обработчик сообщений, который диспетчеризует обработку в зависимости от типа сообщения
final class _MessageDispatcher {
  final Map<RpcMessageType, _IMessageHandler> _handlers = {};
  final RpcLogger _logger = RpcLogger('MessageDispatcher');

  _MessageDispatcher(
    _RpcEngineImpl engine,
  ) {
    // Инициализируем обработчики
    _handlers[RpcMessageType.request] = _RequestMessageHandler(engine);
    _handlers[RpcMessageType.response] = _ResponseMessageHandler(engine);
    _handlers[RpcMessageType.streamData] = _StreamDataMessageHandler(engine);
    _handlers[RpcMessageType.streamEnd] = _StreamEndMessageHandler(engine);
    _handlers[RpcMessageType.error] = _ErrorMessageHandler(engine);
    _handlers[RpcMessageType.ping] = _PingMessageHandler(engine);
    // Для pong сообщений не нужен специальный обработчик, так как они обрабатываются через _pendingRequests
  }

  Future<void> dispatch(RpcMessage message) async {
    final handler = _handlers[message.type];
    if (handler != null) {
      await handler.handleMessage(message);
    } else {
      _logger.debug('Получено сообщение неизвестного типа: ${message.type}');
    }
  }
}
