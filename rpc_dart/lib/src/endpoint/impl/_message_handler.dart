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

    try {
      // Если запрос был получен в RpcMessage, пробуем сначала извлечь payload для типизированного обработчика
      if (updatedRequestContext is RpcMessage &&
          updatedRequestContext.payload != null &&
          methodHandler.argumentParser != null) {
        try {
          final typedRequest =
              methodHandler.argumentParser!(updatedRequestContext.payload);
          return await handler(typedRequest);
        } catch (e) {
          // Если это не сработало, пробуем вызвать как функцию с контекстом
          return await handler(updatedRequestContext);
        }
      } else {
        // Стандартный случай - пробуем вызвать с контекстом
        return await handler(updatedRequestContext);
      }
    } catch (e) {
      if (e is NoSuchMethodError &&
          e.toString().contains('mismatched arguments')) {
        // Если это ошибка несовпадения аргументов, пробуем вызвать без аргументов
        try {
          return await handler();
        } catch (innerE) {
          if (innerE is TypeError &&
              methodHandler.argumentParser != null &&
              updatedRequestContext.payload != null) {
            // Если это ошибка типа, пробуем распарсить запрос и передать его напрямую
            try {
              final typedRequest =
                  methodHandler.argumentParser!(updatedRequestContext.payload);
              return await handler(typedRequest);
            } catch (parsingE, parsingStackTrace) {
              _logger.error('Ошибка при парсинге запроса: $parsingE',
                  error: parsingE, stackTrace: parsingStackTrace);
              rethrow;
            }
          } else {
            _logger.error(
                'Ошибка при вызове обработчика без аргументов: $innerE',
                error: innerE);
            rethrow;
          }
        }
      } else {
        // Если это другая ошибка, пробрасываем её
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
      return; // Нет активного контроллера для этого потока
    }

    // Обработка пустых данных для совместимости с MsgPack
    dynamic payload = message.payload;
    if (RpcServiceMarker.checkIsEmptyServiceMessage(payload)) {
      payload = {};
    }

    // Проверяем, является ли сообщение служебным маркером
    if (RpcServiceMarker.checkIsServiceMessage(payload)) {
      await _handleMarker(message, controller, payload);
      return; // Завершаем обработку после маркера
    }

    // Если известны имена сервиса и метода, применяем middleware
    if (message.serviceName != null && message.methodName != null) {
      _engine._middlewareExecutor
          .executeStreamData(
        message.serviceName!,
        message.methodName!,
        payload,
        message.messageId,
        RpcDataDirection.fromRemote, // Данные получены от удаленной стороны
      )
          .then((processedData) {
        controller.add(processedData);
      }).catchError((error) {
        controller.addError(error);
      });
    } else {
      controller.add(payload);
    }
  }

  /// Обрабатывает служебные маркеры в потоке данных
  Future<void> _handleMarker(RpcMessage message,
      StreamController<dynamic> controller, dynamic payload) async {
    try {
      // Создаем локальный обработчик маркеров, который замыкает текущее сообщение
      final localMarkerHandler = RpcMarkerHandler(
        // Обработчик маркера завершения клиентского стрима
        onClientStreamEnd: (marker) {
          if (message.serviceName != null && message.methodName != null) {
            // Если известны имена сервиса и метода, применяем middleware
            _engine._middlewareExecutor
                .executeStreamEnd(
              message.serviceName!,
              message.methodName!,
              message.messageId,
            )
                .then((_) {
              // Добавляем специальное сообщение для клиентского кода
              controller.add(marker.toJson());
            }).catchError((error) {
              controller.addError(error);
            });
          } else {
            controller.add(marker.toJson());
          }
        },

        // Обработчик маркера завершения серверного стрима
        onServerStreamEnd: (marker) {
          // Для маркера завершения серверного стрима мы просто доставляем его
          controller.add(marker.toJson());
        },

        // Обработчик маркера пинга
        onPing: (marker) {
          // Создаем и отправляем ответный pong маркер
          final pongMarker = RpcPongMarker(
            originalTimestamp: marker.timestamp,
          );

          // Отправляем pong ответ
          _engine._sendMessage(
            RpcMessage(
              type: RpcMessageType.pong,
              messageId: message.messageId,
              payload: pongMarker.toJson(),
              headerMetadata: message.headerMetadata,
              debugLabel: _engine.debugLabel,
            ),
          );
        },

        // Обработчик маркера понга
        onPong: (marker) {
          // Pong сообщения обрабатываются через _pendingRequests
          final completer =
              _engine._requestManager.getRequest(message.messageId);
          if (completer != null && !completer.isCompleted) {
            completer.complete(marker.toJson());
          }
        },

        // Обработчик маркера статуса
        onStatus: (marker) {
          // Если это статус ошибки, доставляем как ошибку
          if (marker.code != RpcStatusCode.ok) {
            // Ищем ожидающий Completer
            final completer =
                _engine._requestManager.getAndRemoveRequest(message.messageId);
            if (completer != null && !completer.isCompleted) {
              // Завершаем с ошибкой
              completer.completeError(
                  'RPC Error [${marker.code.name}]: ${marker.message}');
            }

            // Если есть активный контроллер - добавляем ошибку
            if (!controller.isClosed) {
              controller.addError(
                  'RPC Error [${marker.code.name}]: ${marker.message}');
            }
          } else {
            // Если статус OK, считаем это нормальным сообщением
            controller.add(marker.toJson());
          }
        },

        // Обработчик маркера дедлайна
        onDeadline: (marker) {
          // Проверяем, не истек ли уже срок
          if (marker.isExpired) {
            // Если срок уже истек, немедленно отправляем статус об ошибке
            _engine.sendStatus(
              requestId: message.messageId,
              statusCode: RpcStatusCode.deadlineExceeded,
              message: 'Deadline already exceeded',
              serviceName: message.serviceName,
              methodName: message.methodName,
            );

            // И закрываем поток/операцию с ошибкой
            final completer =
                _engine._requestManager.getAndRemoveRequest(message.messageId);
            if (completer != null && !completer.isCompleted) {
              completer.completeError('Deadline exceeded');
            }

            if (!controller.isClosed) {
              controller.addError('Deadline exceeded');
              controller.close();
            }
          } else {
            // Если срок еще не истек, устанавливаем таймер
            Timer(marker.remaining, () {
              // По истечении срока отправляем статус и закрываем операцию
              _engine.sendStatus(
                requestId: message.messageId,
                statusCode: RpcStatusCode.deadlineExceeded,
                message: 'Deadline exceeded',
                serviceName: message.serviceName,
                methodName: message.methodName,
              );

              final completer = _engine._requestManager
                  .getAndRemoveRequest(message.messageId);
              if (completer != null && !completer.isCompleted) {
                completer.completeError('Deadline exceeded');
              }

              final streamController =
                  _engine._streamManager.getStreamController(message.messageId);
              if (streamController != null && !streamController.isClosed) {
                streamController.addError('Deadline exceeded');
                streamController.close();
              }
            });

            // Пропускаем сообщение дальше
            controller.add(marker.toJson());
          }
        },

        // Обработчик маркера отмены
        onCancel: (marker) {
          // Проверяем, относится ли отмена к текущей операции или потоку
          final operationToCancel = marker.operationId;

          // Если отмена относится к текущей операции
          if (operationToCancel == message.messageId) {
            // Отправляем статус отмены
            _engine.sendStatus(
              requestId: message.messageId,
              statusCode: RpcStatusCode.cancelled,
              message: marker.reason ?? 'Operation cancelled',
              serviceName: message.serviceName,
              methodName: message.methodName,
            );

            // Завершаем операцию
            final completer =
                _engine._requestManager.getAndRemoveRequest(message.messageId);
            if (completer != null && !completer.isCompleted) {
              completer.completeError(marker.reason ?? 'Operation cancelled');
            }

            // Закрываем контроллер потока
            if (!controller.isClosed) {
              controller.addError(marker.reason ?? 'Operation cancelled');
              controller.close();
            }
          } else {
            // Если отмена относится к другой операции, просто пропускаем маркер дальше
            controller.add(marker.toJson());
          }
        },

        // Обработчики для других типов маркеров - просто передаем их дальше
        onHeaders: (marker) => controller.add(marker.toJson()),
        onTrailers: (marker) => controller.add(marker.toJson()),
        onFlowControl: (marker) => controller.add(marker.toJson()),
        onCompression: (marker) => controller.add(marker.toJson()),
        onHealthCheck: (marker) => controller.add(marker.toJson()),
        onClientStreamingInit: (marker) => controller.add(marker.toJson()),
        onBidirectionalInit: (marker) => controller.add(marker.toJson()),
        onChannelClosed: (marker) => controller.add(marker.toJson()),

        // Универсальный обработчик для любых других типов маркеров
        onAnyMarker:
            null, // Не используем, так как у нас есть конкретные обработчики
      );

      // Используем статический метод для создания экземпляра маркера
      final marker = RpcServiceMarker.fromJson(payload);

      // Запускаем обработку маркера с помощью нашего локального обработчика
      localMarkerHandler.handleMarker(marker);
    } catch (e) {
      // При ошибке парсинга маркера, логируем и продолжаем стандартную обработку
      _logger.error('Ошибка при обработке маркера: $e');
      controller.add(payload);
    }
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
