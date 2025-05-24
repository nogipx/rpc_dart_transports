part of '_index.dart';

/// Builder для унарных запросов
class RpcUnaryRequestBuilder {
  final RpcEndpointBase endpoint;
  final String serviceName;
  final String methodName;
  final RpcSerializationFormat? _preferredFormat;

  RpcUnaryRequestBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
    RpcSerializationFormat? preferredFormat,
  }) : _preferredFormat = preferredFormat {
    _logger
        .debug('Создан builder для унарного запроса $serviceName.$methodName');
  }

  RpcLogger get _logger => endpoint.logger.child('UnaryBuilder');

  Future<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Map<String, dynamic>) responseParser,
    RpcSerializationFormat? serializationFormat,
  }) async {
    _logger.debug('Выполнение унарного запроса $serviceName.$methodName');

    // Определяем формат сериализации: указанный в вызове > предпочтительный > из объекта запроса
    final format =
        serializationFormat ?? _preferredFormat ?? request.getFormat();

    _logger.debug('Используется формат сериализации: ${format.name}');

    // Создаем сериализаторы в зависимости от формата
    final IRpcSerializer<TRequest> requestSerializer;
    final IRpcSerializer<TResponse> responseSerializer;

    if (format == RpcSerializationFormat.binary) {
      _logger.debug(
          'Создание бинарных сериализаторов для $serviceName.$methodName');
      // Бинарная сериализация
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) {
          // Если объект имеет собственный бинарный формат - пытаемся его использовать
          // В противном случае предполагаем, что внутри JSON
          try {
            // Пробуем через JSON
            _logger.debug('Десериализация бинарного ответа через JSON');
            final jsonMap = jsonDecode(utf8.decode(bytes));
            return responseParser(jsonMap as Map<String, dynamic>);
          } catch (e) {
            _logger.error('Ошибка при десериализации бинарного ответа',
                error: e);
            throw FormatException(
              'Невозможно десериализовать ответ. Убедитесь, что у вашего типа '
              'есть статический метод fromBytes или укажите правильный '
              'responseParser.',
            );
          }
        },
      );
    } else {
      _logger
          .debug('Создание JSON сериализаторов для $serviceName.$methodName');
      // JSON сериализация (по умолчанию)
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) => responseParser(jsonDecode(utf8.decode(bytes))),
      );
    }

    // Создаем клиент с выбранными сериализаторами
    _logger.debug('Создание унарного клиента для $serviceName.$methodName');
    final client = UnaryCaller<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );

    try {
      _logger.debug('Отправка унарного запроса $serviceName.$methodName');
      final response = await client.call(request);
      _logger.debug('Получен ответ на унарный запрос $serviceName.$methodName');
      return response;
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка при выполнении унарного запроса $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug('Закрытие унарного клиента $serviceName.$methodName');
      await client.close();
    }
  }
}

/// Builder для серверных стримов
class RpcServerStreamBuilder {
  final RpcEndpointBase endpoint;
  final String serviceName;
  final String methodName;
  final RpcSerializationFormat? _preferredFormat;

  RpcServerStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
    RpcSerializationFormat? preferredFormat,
  }) : _preferredFormat = preferredFormat {
    _logger
        .debug('Создан builder для серверного стрима $serviceName.$methodName');
  }

  RpcLogger get _logger => endpoint.logger.child('ServerBuilder');

  Stream<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Map<String, dynamic>) responseParser,
    RpcSerializationFormat? serializationFormat,
  }) async* {
    _logger.debug('Инициализация серверного стрима $serviceName.$methodName');

    // Определяем формат сериализации: указанный в вызове > предпочтительный > из объекта запроса
    final format =
        serializationFormat ?? _preferredFormat ?? request.getFormat();

    _logger.debug('Используется формат сериализации: ${format.name}');

    // Создаем сериализаторы в зависимости от формата
    final IRpcSerializer<TRequest> requestSerializer;
    final IRpcSerializer<TResponse> responseSerializer;

    if (format == RpcSerializationFormat.binary) {
      _logger.debug(
          'Создание бинарных сериализаторов для $serviceName.$methodName');
      // Бинарная сериализация
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) {
          // Если объект имеет собственный бинарный формат - пытаемся его использовать
          // В противном случае предполагаем, что внутри JSON
          try {
            // Пробуем через JSON
            _logger.debug('Десериализация бинарного ответа через JSON');
            final jsonMap = jsonDecode(utf8.decode(bytes));
            return responseParser(jsonMap as Map<String, dynamic>);
          } catch (e) {
            _logger.error('Ошибка при десериализации бинарного ответа',
                error: e);
            throw FormatException(
              'Невозможно десериализовать ответ. Убедитесь, что у вашего типа '
              'есть статический метод fromBytes или укажите правильный '
              'responseParser.',
            );
          }
        },
      );
    } else {
      _logger
          .debug('Создание JSON сериализаторов для $serviceName.$methodName');
      // JSON сериализация (по умолчанию)
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) => responseParser(jsonDecode(utf8.decode(bytes))),
      );
    }

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание клиента серверного стрима для $serviceName.$methodName');
    final client = ServerStreamCaller<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );

    try {
      _logger
          .debug('Отправка запроса в серверный стрим $serviceName.$methodName');
      await client.send(request);
      _logger.debug(
          'Начало получения ответов из серверного стрима $serviceName.$methodName');

      await for (final message in client.responses) {
        if (message.payload != null) {
          _logger.debug(
              'Получен ответ из серверного стрима $serviceName.$methodName');
          yield message.payload!;
        } else if (message.isMetadataOnly) {
          _logger.debug(
              'Получены метаданные из серверного стрима $serviceName.$methodName');
        }
      }

      _logger.debug('Стрим ответов завершен для $serviceName.$methodName');
    } catch (e, stackTrace) {
      _logger.error('Ошибка в серверном стриме $serviceName.$methodName',
          error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger
          .debug('Закрытие клиента серверного стрима $serviceName.$methodName');
      await client.close();
    }
  }
}

/// Builder для клиентских стримов
class RpcClientStreamBuilder {
  final RpcEndpointBase endpoint;
  final String serviceName;
  final String methodName;
  final RpcSerializationFormat? _preferredFormat;

  RpcClientStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
    RpcSerializationFormat? preferredFormat,
  }) : _preferredFormat = preferredFormat {
    _logger.debug(
        'Создан builder для клиентского стрима $serviceName.$methodName');
  }

  RpcLogger get _logger => endpoint.logger.child('ClientBuilder');

  Future<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Map<String, dynamic>) responseParser,
    RpcSerializationFormat? serializationFormat,
  }) async {
    _logger.debug('Инициализация клиентского стрима $serviceName.$methodName');

    // Определяем формат сериализации (используем предпочтительный, если указан)
    final format =
        serializationFormat ?? _preferredFormat ?? RpcSerializationFormat.json;

    _logger.debug('Используется формат сериализации: ${format.name}');

    // Создаем сериализаторы в зависимости от формата
    final IRpcSerializer<TRequest> requestSerializer;
    final IRpcSerializer<TResponse> responseSerializer;

    if (format == RpcSerializationFormat.binary) {
      _logger.debug(
          'Создание бинарных сериализаторов для $serviceName.$methodName');
      // Создаем сериализаторы для бинарного формата
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) {
          try {
            _logger.debug('Десериализация бинарного ответа через JSON');
            // Пробуем через JSON
            final jsonMap = jsonDecode(utf8.decode(bytes));
            return responseParser(jsonMap as Map<String, dynamic>);
          } catch (e) {
            _logger.error('Ошибка при десериализации бинарного ответа',
                error: e);
            throw FormatException(
              'Невозможно десериализовать ответ. Убедитесь, что у вашего типа '
              'есть статический метод fromBytes или укажите правильный '
              'responseParser.',
            );
          }
        },
      );
    } else {
      _logger
          .debug('Создание JSON сериализаторов для $serviceName.$methodName');
      // JSON сериализация (по умолчанию)
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) => responseParser(jsonDecode(utf8.decode(bytes))),
      );
    }

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание клиента клиентского стрима для $serviceName.$methodName');
    final client = ClientStreamCaller<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );

    try {
      _logger.debug(
          'Начало отправки запросов в клиентский стрим $serviceName.$methodName');
      int requestCount = 0;

      await for (final request in requests) {
        _logger.debug(
            'Отправка запроса #${++requestCount} в клиентский стрим $serviceName.$methodName');
        client.send(request);
      }

      _logger.debug(
          'Завершение отправки запросов и ожидание ответа $serviceName.$methodName');
      final response = await client.finishSending();
      _logger.debug('Получен финальный ответ от $serviceName.$methodName');
      return response;
    } catch (e, stackTrace) {
      _logger.error('Ошибка в клиентском стриме $serviceName.$methodName',
          error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
          'Закрытие клиента клиентского стрима $serviceName.$methodName');
      await client.close();
    }
  }
}

/// Builder для двунаправленных стримов
class RpcBidirectionalStreamBuilder {
  final RpcEndpointBase endpoint;
  final String serviceName;
  final String methodName;
  final RpcSerializationFormat? _preferredFormat;

  RpcBidirectionalStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
    RpcSerializationFormat? preferredFormat,
  }) : _preferredFormat = preferredFormat {
    _logger.debug(
        'Создан builder для двунаправленного стрима $serviceName.$methodName');
  }

  RpcLogger get _logger => endpoint.logger.child('BidirectionalBuilder');

  Stream<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Map<String, dynamic>) responseParser,
    RpcSerializationFormat? serializationFormat,
  }) async* {
    _logger.debug(
        'Инициализация двунаправленного стрима $serviceName.$methodName');

    // Определяем формат сериализации (используем предпочтительный, если указан)
    final format =
        serializationFormat ?? _preferredFormat ?? RpcSerializationFormat.json;

    _logger.debug('Используется формат сериализации: ${format.name}');

    // Создаем сериализаторы в зависимости от формата
    final IRpcSerializer<TRequest> requestSerializer;
    final IRpcSerializer<TResponse> responseSerializer;

    if (format == RpcSerializationFormat.binary) {
      _logger.debug(
          'Создание бинарных сериализаторов для $serviceName.$methodName');
      // Создаем сериализаторы для бинарного формата
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) {
          try {
            _logger.debug('Десериализация бинарного ответа через JSON');
            // Пробуем через JSON
            final jsonMap = jsonDecode(utf8.decode(bytes));
            return responseParser(jsonMap as Map<String, dynamic>);
          } catch (e) {
            _logger.error('Ошибка при десериализации бинарного ответа',
                error: e);
            throw FormatException(
              'Невозможно десериализовать ответ. Убедитесь, что у вашего типа '
              'есть статический метод fromBytes или укажите правильный '
              'responseParser.',
            );
          }
        },
      );
    } else {
      _logger
          .debug('Создание JSON сериализаторов для $serviceName.$methodName');
      // JSON сериализация (по умолчанию)
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) => responseParser(jsonDecode(utf8.decode(bytes))),
      );
    }

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание клиента двунаправленного стрима для $serviceName.$methodName');
    final client = BidirectionalStreamCaller<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );

    try {
      // Асинхронно отправляем запросы
      int requestCount = 0;
      _logger.debug(
          'Запуск отправки запросов в двунаправленный стрим $serviceName.$methodName');

      unawaited(() async {
        try {
          await for (final request in requests) {
            _logger.debug(
                'Отправка запроса #${++requestCount} в двунаправленный стрим $serviceName.$methodName');
            client.send(request);
          }
          _logger.debug(
              'Завершение отправки запросов в двунаправленный стрим $serviceName.$methodName');
          client.finishSending();
        } catch (e, stackTrace) {
          _logger.error(
              'Ошибка при отправке запросов в двунаправленный стрим $serviceName.$methodName',
              error: e,
              stackTrace: stackTrace);
        }
      }());

      // Обрабатываем ответы
      _logger.debug(
          'Начало получения ответов из двунаправленного стрима $serviceName.$methodName');
      int responseCount = 0;

      await for (final message in client.responses) {
        if (message.payload != null) {
          _logger.debug(
              'Получен ответ #${++responseCount} из двунаправленного стрима $serviceName.$methodName');
          yield message.payload!;
        } else if (message.isMetadataOnly) {
          _logger.debug(
              'Получены метаданные из двунаправленного стрима $serviceName.$methodName');
        }
      }

      _logger.debug('Стрим ответов завершен для $serviceName.$methodName');
    } catch (e, stackTrace) {
      _logger.error('Ошибка в двунаправленном стриме $serviceName.$methodName',
          error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
          'Закрытие клиента двунаправленного стрима $serviceName.$methodName');
      await client.close();
    }
  }

  /// Вызов с бинарным парсером (для обратной совместимости)
  Stream<TResponse> callWithBinaryParser<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Uint8List bytes) responseParser,
  }) async* {
    _logger.debug(
        'Инициализация двунаправленного стрима с бинарным парсером $serviceName.$methodName');

    final client = BidirectionalStreamCaller<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      ),
      responseSerializer: RpcSerializerFactory.binary<TResponse>(
        responseParser,
      ),
      logger: _logger,
    );

    try {
      // Асинхронно отправляем запросы
      int requestCount = 0;
      _logger.debug(
          'Запуск отправки запросов в двунаправленный стрим (бинарный) $serviceName.$methodName');

      unawaited(() async {
        try {
          await for (final request in requests) {
            _logger.debug(
                'Отправка запроса #${++requestCount} в двунаправленный стрим (бинарный) $serviceName.$methodName');
            client.send(request);
          }
          _logger.debug(
              'Завершение отправки запросов в двунаправленный стрим (бинарный) $serviceName.$methodName');
          client.finishSending();
        } catch (e, stackTrace) {
          _logger.error(
              'Ошибка при отправке запросов в двунаправленный стрим (бинарный) $serviceName.$methodName',
              error: e,
              stackTrace: stackTrace);
        }
      }());

      // Обрабатываем ответы
      _logger.debug(
          'Начало получения ответов из двунаправленного стрима (бинарный) $serviceName.$methodName');
      int responseCount = 0;

      await for (final message in client.responses) {
        if (message.payload != null) {
          _logger.debug(
              'Получен ответ #${++responseCount} из двунаправленного стрима (бинарный) $serviceName.$methodName');
          yield message.payload!;
        } else if (message.isMetadataOnly) {
          _logger.debug(
              'Получены метаданные из двунаправленного стрима (бинарный) $serviceName.$methodName');
        }
      }

      _logger.debug(
          'Стрим ответов завершен для бинарного $serviceName.$methodName');
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка в двунаправленном стриме (бинарный) $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
          'Закрытие клиента двунаправленного стрима (бинарный) $serviceName.$methodName');
      await client.close();
    }
  }
}
