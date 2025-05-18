// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '../_index.dart';

/// Базовая реализация конечной точки для обмена сообщениями
///
/// Этот класс является внутренней реализацией и не должен использоваться напрямую.
/// Для публичного API используйте [RpcEndpoint].
final class _RpcEngineImpl implements IRpcEngine {
  /// Транспорт для отправки/получения сообщений
  final IRpcTransport _transport;
  @override
  IRpcTransport get transport => _transport;

  /// Сериализатор для преобразования сообщений
  final IRpcSerializer _serializer;
  @override
  IRpcSerializer get serializer => _serializer;

  /// Реестр методов
  final IRpcMethodRegistry _registry;
  @override
  IRpcMethodRegistry get registry => _registry;

  /// Метка для отладки
  final String? debugLabel;

  /// Обработчики ожидающих ответов
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  /// Контроллеры потоков данных
  final Map<String, StreamController<dynamic>> _streamControllers = {};

  /// Цепочка middleware для обработки запросов и ответов
  final RpcMiddlewareChain _middlewareChain = RpcMiddlewareChain();

  /// Подписка на входящие сообщения
  StreamSubscription<Uint8List>? _subscription;

  /// Генератор уникальных ID
  late final RpcUniqueIdGenerator _uniqueIdGenerator;

  RpcLogger get _logger => RpcLogger('RpcEngineImpl[$debugLabel]');

  /// Создаёт новую конечную точку
  ///
  /// [transport] - транспорт для обмена сообщениями
  /// [serializer] - сериализатор для преобразования сообщений
  /// [debugLabel] - опциональная метка для отладки и логирования
  _RpcEngineImpl({
    required IRpcTransport transport,
    required IRpcSerializer serializer,
    required IRpcMethodRegistry registry,
    this.debugLabel,
    RpcUniqueIdGenerator? uniqueIdGenerator,
  })  : _transport = transport,
        _serializer = serializer,
        _registry = registry {
    _uniqueIdGenerator = uniqueIdGenerator ?? _defaultUniqueIdGenerator;
    _initialize();
  }

  @override
  String generateUniqueId([String? prefix]) => _uniqueIdGenerator(prefix);

  /// Инициализирует конечную точку
  void _initialize() {
    _subscription = _transport.receive().listen(_handleIncomingData);
  }

  /// Добавляет middleware для обработки запросов и ответов
  ///
  /// [middleware] - объект, реализующий интерфейс RpcMiddleware
  @override
  void addMiddleware(IRpcMiddleware middleware) {
    _middlewareChain.add(middleware);
  }

  /// Регистрирует обработчик метода
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [handler] - функция обработки запроса, которая принимает контекст вызова
  @override
  void registerMethod({
    required String serviceName,
    required String methodName,
    required dynamic handler,
    RpcMethodType? methodType,
    Function? argumentParser,
    Function? responseParser,
  }) {
    // Если есть реестр методов, регистрируем метод и там
    _registry.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: methodType,
      handler: handler,
      argumentParser: argumentParser,
      responseParser: responseParser,
    );
  }

  /// Вызывает удаленный метод и возвращает результат
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [request] - данные запроса
  /// [timeout] - таймаут ожидания ответа
  /// Возвращает Future с результатом вызова
  @override
  Future<dynamic> invoke({
    required String serviceName,
    required String methodName,
    required dynamic request,
    Duration? timeout,
    Map<String, dynamic>? metadata,
  }) async {
    final requestId = generateUniqueId('request');
    final completer = Completer<dynamic>();
    _pendingRequests[requestId] = completer;

    final message = RpcMessage(
      type: RpcMessageType.request,
      messageId: requestId,
      serviceName: serviceName,
      methodName: methodName,
      payload: request,
      headerMetadata: metadata,
      debugLabel: debugLabel,
    );

    // Отправляем запрос
    await _sendMessage(message);

    // Если указан таймаут, устанавливаем deadline
    if (timeout != null) {
      // Используем новый механизм установки дедлайна
      await setDeadline(
        requestId: requestId,
        timeout: timeout,
        serviceName: serviceName,
        methodName: methodName,
      );

      return completer.future;
    }

    return completer.future;
  }

  /// Открывает поток данных от удаленной стороны
  ///
  /// [serviceName] - имя сервиса
  /// [methodName] - имя метода
  /// [request] - начальный запрос (опционально). Если это маркер инициализации стрима,
  ///             он будет отправлен как есть.
  /// [metadata] - дополнительные метаданные
  /// [streamId] - опциональный ID для потока, если не указан, будет сгенерирован
  /// Возвращает Stream с данными от удаленной стороны
  @override
  Stream<dynamic> openStream({
    required String serviceName,
    required String methodName,
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Используем переданный streamId или генерируем новый
    final actualStreamId = streamId ?? generateUniqueId('stream');

    // Если поток с таким ID уже существует, возвращаем его
    if (_streamControllers.containsKey(actualStreamId)) {
      return _streamControllers[actualStreamId]!.stream;
    }

    final controller = StreamController<dynamic>.broadcast();
    _streamControllers[actualStreamId] = controller;

    // Проверяем, является ли запрос маркером инициализации стрима
    final isClientStreamInit = RpcMarkerHandler.isServiceMarker(request) &&
        (request is Map &&
                request['_markerType'] ==
                    RpcMarkerType.clientStreamingInit.name ||
            request is RpcClientStreamingMarker);

    final isBidirectionalInit = RpcMarkerHandler.isServiceMarker(request) &&
        (request is Map &&
                request['_markerType'] == RpcMarkerType.bidirectional.name ||
            request is RpcBidirectionalStreamingMarker);

    final message = RpcMessage(
      type: RpcMessageType.request,
      messageId: actualStreamId,
      serviceName: serviceName,
      methodName: methodName,
      payload: request,
      headerMetadata: metadata,
      debugLabel: debugLabel,
    );

    _sendMessage(message);

    // Если это инициализация стрима, логируем это для отладки
    if (isClientStreamInit) {
      _logger.debug('Инициализация клиентского стрима с ID: $actualStreamId');
    } else if (isBidirectionalInit) {
      _logger
          .debug('Инициализация двунаправленного стрима с ID: $actualStreamId');
    }

    return controller.stream;
  }

  /// Обрабатывает входящие данные и направляет их на обработку в соответствии с типом сообщения
  Future<void> _handleIncomingData(Uint8List data) async {
    // Десериализуем данные в сообщение
    final Map<String, dynamic> json = _serializer.deserialize(data);
    final message = RpcMessage.fromJson(json);

    // Логирование типа сообщения для отладки
    _logger.debug(
        '← Получено сообщение типа ${message.type.name} [${message.messageId}] '
        '${message.serviceName != null ? "${message.serviceName}." : ""}${message.methodName ?? ""}');

    // DEBUG: логирование payload для отладки ошибки
    if (message.payload != null) {
      _logger.debug('DEBUG: Тип payload: ${message.payload.runtimeType}, '
          'Значение: ${message.payload.toString()}, '
          'Имеет метод payload: ${message.payload is Map ? "да" : "нет"}'
          '${message.payload is Map ? ", Ключи: ${(message.payload as Map).keys.toList()}" : ""}');
    }

    // Обработка сообщения в соответствии с его типом
    switch (message.type) {
      case RpcMessageType.request:
        _handleRequest(message);
        break;
      case RpcMessageType.response:
        _handleResponse(message);
        break;
      case RpcMessageType.streamData:
        _handleStreamData(message);
        break;
      case RpcMessageType.streamEnd:
        _handleStreamEnd(message);
        break;
      case RpcMessageType.error:
        // DEBUG: Дополнительный лог для отладки перед вызовом handleError
        if (message.payload != null) {
          _logger.debug(
              'DEBUG перед handleError: Тип payload: ${message.payload.runtimeType}, '
              'Значение: ${message.payload.toString()}');
        }
        _handleError(message);
        break;
      case RpcMessageType.ping:
        _handlePing(message);
        break;
      case RpcMessageType.pong:
        // Ничего не делаем с pong сообщениями
        break;
      case RpcMessageType.contract:
        // Обработка контрактов будет добавлена позже
        break;
      case RpcMessageType.unknown:
        // Игнорируем неизвестные типы сообщений
        break;
    }
  }

  /// Обрабатывает входящий запрос
  Future<void> _handleRequest(RpcMessage message) async {
    final serviceName = message.serviceName;
    final methodName = message.methodName;

    if (serviceName == null || methodName == null) {
      await _sendErrorMessage(
        message.messageId,
        'Не указаны serviceName или methodName',
        message.headerMetadata,
      );

      // Отправляем статус ошибки
      await sendStatus(
        requestId: message.messageId,
        statusCode: RpcStatusCode.invalidArgument,
        message: 'Не указаны serviceName или methodName',
        metadata: message.headerMetadata,
      );

      return;
    }

    var methodHandler = _registry.findMethod(serviceName, methodName);
    if (methodHandler == null) {
      await _sendErrorMessage(
        message.messageId,
        'Метод не найден: $serviceName.$methodName',
        message.headerMetadata,
      );

      // Отправляем статус ошибки
      await sendStatus(
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
      final requestResult = await _middlewareChain.executeRequest(
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
      if (methodHandler.handler == null) {
        throw RpcCustomException(
          customMessage:
              'Не найден обработчик для метода $serviceName.$methodName',
          debugLabel: 'RpcEngineImpl._handleRequest',
        );
      }

      // Вызываем обработчик с обновленным контекстом
      // Теперь handler - это адаптер, созданный через RpcMethodAdapterFactory, который корректно обрабатывает контекст
      final result = await methodHandler.handler(updatedRequestContext);

      // Изменяем направление на отправку
      direction = RpcDataDirection.toRemote;

      // Применяем middleware для обработки ответа
      final responseResult = await _middlewareChain.executeResponse(
        serviceName,
        methodName,
        result,
        updatedRequestContext,
        RpcDataDirection.toRemote,
      );

      // Используем финальный контекст после применения всех middleware
      final finalContext = responseResult.context;

      // Отправляем ответ
      await _sendMessage(
        RpcMessage(
          type: RpcMessageType.response,
          messageId: message.messageId,
          payload: responseResult.payload,
          headerMetadata: finalContext.headerMetadata,
          trailerMetadata: finalContext.trailerMetadata,
          debugLabel: debugLabel,
        ),
      );

      // Отправляем статус успешного завершения
      await sendStatus(
        requestId: message.messageId,
        statusCode: RpcStatusCode.ok,
        message: 'OK',
        metadata: finalContext.headerMetadata,
        serviceName: serviceName,
        methodName: methodName,
      );
    } catch (e, stackTrace) {
      // Создаем контекст для ошибки из сообщения
      final errorContext = message;

      // Применяем middleware для обработки ошибки
      final errorResult = await _middlewareChain.executeError(
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
      await sendStatus(
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
      await _sendErrorMessage(
        message.messageId,
        processedError.toString(),
        finalErrorContext.headerMetadata,
        finalErrorContext.trailerMetadata,
      );
    }
  }

  /// Обрабатывает входящий ответ
  void _handleResponse(RpcMessage message) {
    final completer = _pendingRequests.remove(message.messageId);
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

  /// Обрабатывает входящие данные в потоке
  void _handleStreamData(RpcMessage message) {
    final controller = _streamControllers[message.messageId];
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
      try {
        // Создаем локальный обработчик маркеров, который замыкает текущее сообщение
        final localMarkerHandler = RpcMarkerHandler(
          // Обработчик маркера завершения клиентского стрима
          onClientStreamEnd: (marker) {
            if (message.serviceName != null && message.methodName != null) {
              // Если известны имена сервиса и метода, применяем middleware
              _middlewareChain
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
            _sendMessage(
              RpcMessage(
                type: RpcMessageType.pong,
                messageId: message.messageId,
                payload: pongMarker.toJson(),
                headerMetadata: message.headerMetadata,
                debugLabel: debugLabel,
              ),
            );
          },

          // Обработчик маркера понга
          onPong: (marker) {
            // Pong сообщения обрабатываются через _pendingRequests
            final completer = _pendingRequests[message.messageId];
            if (completer != null && !completer.isCompleted) {
              completer.complete(marker.toJson());
            }
          },

          // Обработчик маркера статуса
          onStatus: (marker) {
            // Если это статус ошибки, доставляем как ошибку
            if (marker.code != RpcStatusCode.ok) {
              // Ищем ожидающий Completer
              final completer = _pendingRequests.remove(message.messageId);
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
              sendStatus(
                requestId: message.messageId,
                statusCode: RpcStatusCode.deadlineExceeded,
                message: 'Deadline already exceeded',
                serviceName: message.serviceName,
                methodName: message.methodName,
              );

              // И закрываем поток/операцию с ошибкой
              final completer = _pendingRequests.remove(message.messageId);
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
                sendStatus(
                  requestId: message.messageId,
                  statusCode: RpcStatusCode.deadlineExceeded,
                  message: 'Deadline exceeded',
                  serviceName: message.serviceName,
                  methodName: message.methodName,
                );

                final completer = _pendingRequests.remove(message.messageId);
                if (completer != null && !completer.isCompleted) {
                  completer.completeError('Deadline exceeded');
                }

                final streamController = _streamControllers[message.messageId];
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
              sendStatus(
                requestId: message.messageId,
                statusCode: RpcStatusCode.cancelled,
                message: marker.reason ?? 'Operation cancelled',
                serviceName: message.serviceName,
                methodName: message.methodName,
              );

              // Завершаем операцию
              final completer = _pendingRequests.remove(message.messageId);
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

      return; // Завершаем обработку после маркера
    }

    // Если известны имена сервиса и метода, применяем middleware
    if (message.serviceName != null && message.methodName != null) {
      _middlewareChain
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

  /// Обрабатывает завершение потока
  void _handleStreamEnd(RpcMessage message) {
    final controller = _streamControllers.remove(message.messageId);
    if (controller != null && !controller.isClosed) {
      // Если известны имена сервиса и метода, применяем middleware
      if (message.serviceName != null && message.methodName != null) {
        _middlewareChain
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

  /// Обрабатывает сообщение с ошибкой
  void _handleError(RpcMessage message) {
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
      errorObject = Exception('Ошибка при обработке сообщения');
    }

    final completer = _pendingRequests.remove(message.messageId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(errorObject);
    }

    final controller = _streamControllers[message.messageId];
    if (controller != null && !controller.isClosed) {
      controller.addError(errorObject);
    }
  }

  /// Обрабатывает ping сообщение
  Future<void> _handlePing(RpcMessage message) async {
    await _sendMessage(
      RpcMessage(
        type: RpcMessageType.pong,
        messageId: message.messageId,
        payload: message.payload,
        headerMetadata: message.headerMetadata,
        debugLabel: debugLabel,
      ),
    );
  }

  /// Отправляет сообщение об ошибке
  Future<void> _sendErrorMessage(
    String requestId,
    String errorMessage,
    Map<String, dynamic>? headerMetadata, [
    Map<String, dynamic>? trailerMetadata,
  ]) async {
    await _sendMessage(
      RpcMessage(
        type: RpcMessageType.error,
        messageId: requestId,
        payload: errorMessage,
        headerMetadata: headerMetadata,
        trailerMetadata: trailerMetadata,
        debugLabel: debugLabel,
      ),
    );
  }

  /// Отправляет сообщение через транспорт
  Future<void> _sendMessage(RpcMessage message) async {
    final data = _serializer.serialize(message.toJson());
    await _transport.send(data);
  }

  /// Проверяет, активна ли конечная точка
  @override
  bool get isActive => _transport.isAvailable;

  /// Закрывает конечную точку
  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;

    // Выполняем все ожидающие запросы с ошибкой
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Endpoint closed');
      }
    }
    _pendingRequests.clear();

    // Закрываем все контроллеры потоков
    for (final controller in _streamControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streamControllers.clear();

    final diagnostic = RpcLoggerSettings.diagnostic;
    if (diagnostic != null) {
      RpcLoggerSettings.removeDiagnostic();
      await diagnostic.dispose();
    }

    await _transport.close();
  }

  /// Отправляет данные в поток
  ///
  /// [streamId] - ID потока
  /// [data] - данные для отправки
  /// [metadata] - дополнительные метаданные
  /// [serviceName] - имя сервиса (опционально, для middleware)
  /// [methodName] - имя метода (опционально, для middleware)
  @override
  Future<void> sendStreamData({
    required String streamId,
    required dynamic data,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Проверка на null и конвертация в пустой объект для совместимости с MsgPack
    data ??= {'_empty': true};
    // Если указаны имена сервиса и метода, обрабатываем данные через middleware
    dynamic processedData = data;
    if (serviceName != null && methodName != null) {
      processedData = await _middlewareChain.executeStreamData(
        serviceName,
        methodName,
        data,
        streamId,
        RpcDataDirection.toRemote, // Данные отправляются удаленной стороне
      );
    }

    final message = RpcMessage(
      type: RpcMessageType.streamData,
      messageId: streamId,
      serviceName: serviceName,
      methodName: methodName,
      payload: processedData,
      headerMetadata: metadata,
      debugLabel: debugLabel,
    );

    await _sendMessage(message);
  }

  /// Отправляет сигнал об ошибке в поток
  ///
  /// [streamId] - ID потока
  /// [error] - сообщение об ошибке
  /// [metadata] - дополнительные метаданные
  /// [serviceName] - имя сервиса (опционально, для middleware)
  /// [methodName] - имя метода (опционально, для middleware)
  @override
  Future<void> sendStreamError({
    required String streamId,
    required String errorMessage,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    final message = RpcMessage(
      type: RpcMessageType.error,
      messageId: streamId,
      serviceName: serviceName,
      methodName: methodName,
      payload: errorMessage,
      headerMetadata: metadata,
      debugLabel: debugLabel,
    );

    await _sendMessage(message);
  }

  /// Закрывает поток
  ///
  /// [streamId] - ID потока
  /// [metadata] - дополнительные метаданные
  /// [serviceName] - имя сервиса (опционально, для middleware)
  /// [methodName] - имя метода (опционально, для middleware)
  @override
  Future<void> closeStream({
    required String streamId,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Если указаны имена сервиса и метода, уведомляем middleware о закрытии потока
    if (serviceName != null && methodName != null) {
      await _middlewareChain.executeStreamEnd(
        serviceName,
        methodName,
        streamId,
      );
    }

    await _sendMessage(
      RpcMessage(
        type: RpcMessageType.streamEnd,
        messageId: streamId,
        serviceName: serviceName,
        methodName: methodName,
        headerMetadata: metadata,
        debugLabel: debugLabel,
      ),
    );
  }

  /// Отправляет ping-сообщение для проверки соединения
  /// Возвращает Future, который завершится когда придет ответ или произойдет таймаут
  @override
  Future<Duration> sendPing({Duration? timeout}) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final pingId = generateUniqueId('ping');
    final completer = Completer<Duration>();

    // Регистрируем ожидание ответа
    _pendingRequests[pingId] = Completer<dynamic>();

    // Устанавливаем таймаут (по умолчанию 5 секунд)
    final effectiveTimeout = timeout ?? const Duration(seconds: 5);
    final timer = Timer(effectiveTimeout, () {
      final pendingRequest = _pendingRequests.remove(pingId);
      if (pendingRequest != null && !pendingRequest.isCompleted) {
        pendingRequest
            .completeError(TimeoutException('Ping timeout', effectiveTimeout));

        if (!completer.isCompleted) {
          completer.completeError(
              TimeoutException('Ping timeout', effectiveTimeout));
        }
      }
    });

    // Создаем маркер ping и отправляем через универсальный метод
    final pingMarker = RpcPingMarker();
    await sendServiceMarker(
      streamId: pingId,
      marker: pingMarker,
      metadata: null,
    );

    // Ожидаем ответ и вычисляем RTT
    _pendingRequests[pingId]!.future.then((response) {
      timer.cancel();

      try {
        // Парсим ответ для получения временных меток
        if (response is Map<String, dynamic>) {
          final pongMarker = RpcPongMarker.fromJson(response);
          final rtt =
              Duration(milliseconds: pongMarker.responseTimestamp - startTime);

          if (!completer.isCompleted) {
            completer.complete(rtt);
          }
        } else {
          // Некорректный формат ответа
          if (!completer.isCompleted) {
            completer
                .completeError(FormatException('Invalid pong response format'));
          }
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    }).catchError((error) {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    return completer.future;
  }

  /// Отправляет маркер завершения потока в клиентском стриминге
  /// Это специальный метод, который избегает проблем с приведением типов
  @override
  Future<void> sendClientStreamEnd({
    required String streamId,
    String? serviceName,
    String? methodName,
    Map<String, dynamic>? metadata,
  }) async {
    // Используем новый универсальный метод с маркером RpcClientStreamEndMarker
    await sendServiceMarker(
      streamId: streamId,
      marker: const RpcClientStreamEndMarker(),
      serviceName: serviceName,
      methodName: methodName,
      metadata: metadata,
    );
  }

  /// Отправляет любой служебный маркер
  /// Унифицированный метод для отправки любых типов маркеров
  ///
  /// [streamId] - ID потока или соединения
  /// [marker] - служебный маркер для отправки
  /// [serviceName] - имя сервиса (опционально, для middleware)
  /// [methodName] - имя метода (опционально, для middleware)
  /// [metadata] - дополнительные метаданные
  @override
  Future<void> sendServiceMarker({
    required String streamId,
    required RpcServiceMarker marker,
    String? serviceName,
    String? methodName,
    Map<String, dynamic>? metadata,
  }) async {
    // В зависимости от типа маркера, может потребоваться специфическая логика
    RpcMessageType messageType = RpcMessageType.streamData;

    // Специальная обработка для ping маркера
    if (marker is RpcPingMarker) {
      messageType = RpcMessageType.ping;
    }

    // Отправляем маркер через стандартное сообщение
    await _sendMessage(
      RpcMessage(
        type: messageType,
        messageId: streamId,
        serviceName: serviceName,
        methodName: methodName,
        payload: marker.toJson(),
        headerMetadata: metadata,
        debugLabel: debugLabel,
      ),
    );
  }

  /// Отправляет маркер статуса операции
  ///
  /// [requestId] - ID запроса или операции
  /// [statusCode] - код статуса операции
  /// [message] - описание статуса или ошибки
  /// [details] - дополнительные детали (опционально)
  /// [metadata] - дополнительные метаданные (опционально)
  @override
  Future<void> sendStatus({
    required String requestId,
    required RpcStatusCode statusCode,
    required String message,
    Map<String, dynamic>? details,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Создаем маркер статуса
    final statusMarker = RpcStatusMarker(
      code: statusCode,
      message: message,
      details: details,
    );

    // Используем универсальный метод для отправки маркера
    await sendServiceMarker(
      streamId: requestId,
      marker: statusMarker,
      serviceName: serviceName,
      methodName: methodName,
      metadata: metadata,
    );

    // Если это ошибочный статус (не OK), также отправляем сообщение об ошибке
    // для обратной совместимости
    if (statusCode != RpcStatusCode.ok) {
      await _sendErrorMessage(
        requestId,
        message,
        metadata,
        details,
      );
    }
  }

  /// Устанавливает deadline для операции
  ///
  /// [requestId] - ID запроса или операции
  /// [timeout] - таймаут для операции
  /// [metadata] - дополнительные метаданные (опционально)
  @override
  Future<void> setDeadline({
    required String requestId,
    required Duration timeout,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Создаем маркер дедлайна
    final deadlineMarker = RpcDeadlineMarker.fromDuration(timeout);

    // Отправляем маркер
    await sendServiceMarker(
      streamId: requestId,
      marker: deadlineMarker,
      serviceName: serviceName,
      methodName: methodName,
      metadata: metadata,
    );

    // Устанавливаем таймер для автоматического прерывания операции
    Timer(timeout, () {
      // Проверяем, не завершена ли уже операция
      final completer = _pendingRequests[requestId];
      if (completer != null && !completer.isCompleted) {
        // Отправляем статус о превышении времени ожидания
        sendStatus(
          requestId: requestId,
          statusCode: RpcStatusCode.deadlineExceeded,
          message: 'Превышено время ожидания (${timeout.inMilliseconds} мс)',
          serviceName: serviceName,
          methodName: methodName,
        );

        // Завершаем запрос с ошибкой
        completer.completeError(TimeoutException('Deadline exceeded', timeout));
      }
    });
  }

  /// Отменяет операцию
  ///
  /// [operationId] - ID операции для отмены
  /// [reason] - причина отмены (опционально)
  /// [details] - дополнительные детали (опционально)
  @override
  Future<void> cancelOperation({
    required String operationId,
    String? reason,
    Map<String, dynamic>? details,
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  }) async {
    // Создаем маркер отмены
    final cancelMarker = RpcCancelMarker(
      operationId: operationId,
      reason: reason,
      details: details,
    );

    // Отправляем маркер
    await sendServiceMarker(
      streamId: operationId,
      marker: cancelMarker,
      serviceName: serviceName,
      methodName: methodName,
      metadata: metadata,
    );

    // Отправляем статус отмены для гарантированного завершения
    await sendStatus(
      requestId: operationId,
      statusCode: RpcStatusCode.cancelled,
      message: reason ?? 'Операция отменена клиентом',
      details: details,
      serviceName: serviceName,
      methodName: methodName,
    );

    // Завершаем ожидающий запрос, если он есть
    final completer = _pendingRequests.remove(operationId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(reason ?? 'Operation cancelled');
    }

    // Закрываем поток, если он есть
    final controller = _streamControllers.remove(operationId);
    if (controller != null && !controller.isClosed) {
      controller.addError(reason ?? 'Operation cancelled');
      controller.close();
    }
  }
}
