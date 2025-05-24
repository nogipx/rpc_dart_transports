part of '_index.dart';

/// Builder для унарных запросов
class RpcUnaryRequestBuilder {
  final RpcEndpointBase endpoint;
  final String serviceName;
  final String methodName;

  RpcUnaryRequestBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
  }) {
    _logger
        .debug('Создан builder для унарного запроса $serviceName.$methodName');
  }

  RpcLogger get _logger => endpoint.logger.child('UnaryBuilder');

  /// Выполняет унарный запрос с JSON сериализацией
  ///
  /// [request] - Объект запроса, который будет сериализован в JSON
  /// [responseParser] - Функция для преобразования JSON в объект ответа
  Future<TResponse> callJson<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Map<String, dynamic>) responseParser,
  }) async {
    _logger.debug('Выполнение JSON унарного запроса $serviceName.$methodName');

    // Создаем JSON сериализаторы
    _logger.debug('Создание JSON сериализаторов для $serviceName.$methodName');
    final requestSerializer = RpcSerializerFactory.binary<TRequest>(
      (bytes) => throw UnsupportedError(
        'Десериализация TRequest не требуется в клиентском билдере',
      ),
    );

    final responseSerializer = RpcSerializerFactory.binary<TResponse>(
      (bytes) => responseParser(jsonDecode(utf8.decode(bytes))),
    );

    // Создаем клиент с выбранными сериализаторами
    _logger
        .debug('Создание унарного клиента для $serviceName.$methodName (JSON)');
    final client = UnaryCaller<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );

    try {
      _logger.debug('Отправка JSON унарного запроса $serviceName.$methodName');
      final response = await client.call(request);
      _logger.debug(
          'Получен ответ на JSON унарный запрос $serviceName.$methodName');
      return response;
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка при выполнении JSON унарного запроса $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug('Закрытие унарного клиента $serviceName.$methodName');
      await client.close();
    }
  }

  /// Выполняет унарный запрос с бинарной сериализацией (например, Protobuf)
  ///
  /// [request] - Объект запроса, который будет сериализован в бинарный формат
  /// [responseParser] - Функция для преобразования бинарных данных в объект ответа
  Future<TResponse> callBinary<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Uint8List) responseParser,
  }) async {
    _logger.debug(
        'Выполнение бинарного унарного запроса $serviceName.$methodName');

    // Создаем сериализаторы для бинарного формата
    final requestSerializer = RpcSerializerFactory.binary<TRequest>(
      (bytes) => throw UnsupportedError(
        'Десериализация TRequest не требуется в клиентском билдере',
      ),
    );

    final responseSerializer =
        RpcSerializerFactory.binary<TResponse>(responseParser);

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание унарного клиента для $serviceName.$methodName (binary)');
    final client = UnaryCaller<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );

    try {
      _logger.debug(
          'Отправка бинарного унарного запроса $serviceName.$methodName');
      final response = await client.call(request);
      _logger.debug(
          'Получен ответ на бинарный унарный запрос $serviceName.$methodName');
      return response;
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка при выполнении бинарного унарного запроса $serviceName.$methodName',
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

  RpcServerStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
  }) {
    _logger
        .debug('Создан builder для серверного стрима $serviceName.$methodName');
  }

  RpcLogger get _logger => endpoint.logger.child('ServerBuilder');

  /// Выполняет запрос серверного стрима с JSON сериализацией
  ///
  /// [request] - Объект запроса, который будет сериализован в JSON
  /// [responseParser] - Функция для преобразования JSON в объекты ответов
  Stream<TResponse> callJson<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Map<String, dynamic>) responseParser,
  }) {
    final streamController = StreamController<TResponse>();

    _logger
        .debug('Инициализация JSON серверного стрима $serviceName.$methodName');

    // Создаем JSON сериализаторы
    _logger.debug('Создание JSON сериализаторов для $serviceName.$methodName');
    final requestSerializer = RpcSerializerFactory.binary<TRequest>(
      (bytes) => throw UnsupportedError(
        'Десериализация TRequest не требуется в клиентском билдере',
      ),
    );

    final responseSerializer = RpcSerializerFactory.binary<TResponse>(
      (bytes) => responseParser(jsonDecode(utf8.decode(bytes))),
    );

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание клиента JSON серверного стрима для $serviceName.$methodName');
    final client = ServerStreamCaller<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );

    () async {
      try {
        _logger.debug(
            'Отправка запроса в JSON серверный стрим $serviceName.$methodName');
        await client.send(request);
        _logger.debug(
            'Начало получения ответов из JSON серверного стрима $serviceName.$methodName');

        await for (final message in client.responses) {
          if (message.payload != null) {
            _logger.debug(
                'Получен ответ из JSON серверного стрима $serviceName.$methodName');
            streamController.add(message.payload!);
          } else if (message.isMetadataOnly) {
            _logger.debug(
                'Получены метаданные из JSON серверного стрима $serviceName.$methodName');
          }
        }

        _logger
            .debug('Стрим JSON ответов завершен для $serviceName.$methodName');
        await streamController.close();
      } catch (e, stackTrace) {
        _logger.error('Ошибка в JSON серверном стриме $serviceName.$methodName',
            error: e, stackTrace: stackTrace);
        streamController.addError(e, stackTrace);
      } finally {
        _logger.debug(
            'Закрытие клиента JSON серверного стрима $serviceName.$methodName');
        await client.close();
      }
    }();

    return streamController.stream;
  }

  /// Выполняет запрос серверного стрима с бинарной сериализацией (например, Protobuf)
  ///
  /// [request] - Объект запроса, который будет сериализован в бинарный формат
  /// [responseParser] - Функция для преобразования бинарных данных в объекты ответов
  Stream<TResponse> callBinary<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Uint8List) responseParser,
  }) {
    final streamController = StreamController<TResponse>();

    _logger.debug(
        'Инициализация бинарного серверного стрима $serviceName.$methodName');

    // Создаем сериализаторы для бинарного формата
    final requestSerializer = RpcSerializerFactory.binary<TRequest>(
      (bytes) => throw UnsupportedError(
        'Десериализация TRequest не требуется в клиентском билдере',
      ),
    );

    final responseSerializer =
        RpcSerializerFactory.binary<TResponse>(responseParser);

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание клиента бинарного серверного стрима для $serviceName.$methodName');
    final client = ServerStreamCaller<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: _logger,
    );

    () async {
      try {
        _logger.debug(
            'Отправка запроса в бинарный серверный стрим $serviceName.$methodName');
        await client.send(request);
        _logger.debug(
            'Начало получения ответов из бинарного серверного стрима $serviceName.$methodName');

        await for (final message in client.responses) {
          if (message.payload != null) {
            _logger.debug(
                'Получен ответ из бинарного серверного стрима $serviceName.$methodName');
            streamController.add(message.payload!);
          } else if (message.isMetadataOnly) {
            _logger.debug(
                'Получены метаданные из бинарного серверного стрима $serviceName.$methodName');
          }
        }

        _logger.debug(
            'Стрим бинарных ответов завершен для $serviceName.$methodName');
        await streamController.close();
      } catch (e, stackTrace) {
        _logger.error(
            'Ошибка в бинарном серверном стриме $serviceName.$methodName',
            error: e,
            stackTrace: stackTrace);
        streamController.addError(e, stackTrace);
      } finally {
        _logger.debug(
            'Закрытие клиента бинарного серверного стрима $serviceName.$methodName');
        await client.close();
      }
    }();

    return streamController.stream;
  }
}

/// Builder для клиентских стримов
class RpcClientStreamBuilder {
  final RpcEndpointBase endpoint;
  final String serviceName;
  final String methodName;

  RpcClientStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
  }) {
    _logger.debug(
        'Создан builder для клиентского стрима $serviceName.$methodName');
  }

  RpcLogger get _logger => endpoint.logger.child('ClientBuilder');

  /// Выполняет запрос клиентского стрима с JSON сериализацией
  ///
  /// [requests] - Поток объектов запросов, которые будут сериализованы в JSON
  /// [responseParser] - Функция для преобразования JSON в объект ответа
  Future<TResponse> callJson<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Map<String, dynamic>) responseParser,
  }) async {
    _logger.debug(
        'Инициализация JSON клиентского стрима $serviceName.$methodName');

    // Создаем JSON сериализаторы
    _logger.debug('Создание JSON сериализаторов для $serviceName.$methodName');
    final requestSerializer = RpcSerializerFactory.binary<TRequest>(
      (bytes) => throw UnsupportedError(
        'Десериализация TRequest не требуется в клиентском билдере',
      ),
    );

    final responseSerializer = RpcSerializerFactory.binary<TResponse>(
      (bytes) => responseParser(jsonDecode(utf8.decode(bytes))),
    );

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание клиента JSON клиентского стрима для $serviceName.$methodName');
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
          'Начало отправки запросов в JSON клиентский стрим $serviceName.$methodName');
      int requestCount = 0;

      await for (final request in requests) {
        _logger.debug(
            'Отправка запроса #${++requestCount} в JSON клиентский стрим $serviceName.$methodName');
        client.send(request);
      }

      _logger.debug(
          'Завершение отправки запросов и ожидание ответа $serviceName.$methodName');
      final response = await client.finishSending();
      _logger.debug('Получен финальный ответ от $serviceName.$methodName');
      return response;
    } catch (e, stackTrace) {
      _logger.error('Ошибка в JSON клиентском стриме $serviceName.$methodName',
          error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
          'Закрытие клиента JSON клиентского стрима $serviceName.$methodName');
      await client.close();
    }
  }

  /// Выполняет запрос клиентского стрима с бинарной сериализацией (например, Protobuf)
  ///
  /// [requests] - Поток объектов запросов, которые будут сериализованы в бинарный формат
  /// [responseParser] - Функция для преобразования бинарных данных в объект ответа
  Future<TResponse> callBinary<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Uint8List) responseParser,
  }) async {
    _logger.debug(
        'Инициализация бинарного клиентского стрима $serviceName.$methodName');

    // Определяем формат сериализации (бинарный)
    final format = RpcSerializationFormat.binary;

    _logger.debug('Используется формат сериализации: ${format.name}');

    // Создаем сериализаторы для бинарного формата
    final requestSerializer = RpcSerializerFactory.binary<TRequest>(
      (bytes) => throw UnsupportedError(
        'Десериализация TRequest не требуется в клиентском билдере',
      ),
    );

    final responseSerializer =
        RpcSerializerFactory.binary<TResponse>(responseParser);

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание клиента бинарного клиентского стрима для $serviceName.$methodName');
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
          'Начало отправки запросов в бинарный клиентский стрим $serviceName.$methodName');
      int requestCount = 0;

      await for (final request in requests) {
        _logger.debug(
            'Отправка запроса #${++requestCount} в бинарный клиентский стрим $serviceName.$methodName');
        client.send(request);
      }

      _logger.debug(
          'Завершение отправки запросов и ожидание ответа $serviceName.$methodName');
      final response = await client.finishSending();
      _logger.debug('Получен финальный ответ от $serviceName.$methodName');
      return response;
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка в бинарном клиентском стриме $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
          'Закрытие клиента бинарного клиентского стрима $serviceName.$methodName');
      await client.close();
    }
  }
}

/// Builder для двунаправленных стримов
class RpcBidirectionalStreamBuilder {
  final RpcEndpointBase endpoint;
  final String serviceName;
  final String methodName;

  RpcBidirectionalStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
  }) {
    _logger.debug(
        'Создан builder для двунаправленного стрима $serviceName.$methodName');
  }

  RpcLogger get _logger => endpoint.logger.child('BidirectionalBuilder');

  /// Выполняет запрос двунаправленного стрима с JSON сериализацией
  ///
  /// [requests] - Поток объектов запросов, которые будут сериализованы в JSON
  /// [responseParser] - Функция для преобразования JSON в объекты ответов
  Stream<TResponse> callJson<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Map<String, dynamic>) responseParser,
  }) async* {
    _logger.debug(
        'Инициализация JSON двунаправленного стрима $serviceName.$methodName');

    // Создаем JSON сериализаторы
    _logger.debug('Создание JSON сериализаторов для $serviceName.$methodName');
    final requestSerializer = RpcSerializerFactory.binary<TRequest>(
      (bytes) => throw UnsupportedError(
        'Десериализация TRequest не требуется в клиентском билдере',
      ),
    );

    final responseSerializer = RpcSerializerFactory.binary<TResponse>(
      (bytes) => responseParser(jsonDecode(utf8.decode(bytes))),
    );

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание клиента JSON двунаправленного стрима для $serviceName.$methodName');
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
          'Запуск отправки запросов в JSON двунаправленный стрим $serviceName.$methodName');

      unawaited(() async {
        try {
          await for (final request in requests) {
            _logger.debug(
                'Отправка запроса #${++requestCount} в JSON двунаправленный стрим $serviceName.$methodName');
            client.send(request);
          }
          _logger.debug(
              'Завершение отправки запросов в JSON двунаправленный стрим $serviceName.$methodName');
          client.finishSending();
        } catch (e, stackTrace) {
          _logger.error(
              'Ошибка при отправке запросов в JSON двунаправленный стрим $serviceName.$methodName',
              error: e,
              stackTrace: stackTrace);
        }
      }());

      // Обрабатываем ответы
      _logger.debug(
          'Начало получения ответов из JSON двунаправленного стрима $serviceName.$methodName');
      int responseCount = 0;

      await for (final message in client.responses) {
        if (message.payload != null) {
          _logger.debug(
              'Получен ответ #${++responseCount} из JSON двунаправленного стрима $serviceName.$methodName');
          yield message.payload!;
        } else if (message.isMetadataOnly) {
          _logger.debug(
              'Получены метаданные из JSON двунаправленного стрима $serviceName.$methodName');
        }
      }

      _logger.debug('Стрим JSON ответов завершен для $serviceName.$methodName');
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка в JSON двунаправленном стриме $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
          'Закрытие клиента JSON двунаправленного стрима $serviceName.$methodName');
      await client.close();
    }
  }

  /// Выполняет запрос двунаправленного стрима с бинарной сериализацией (например, Protobuf)
  ///
  /// [requests] - Поток объектов запросов, которые будут сериализованы в бинарный формат
  /// [responseParser] - Функция для преобразования бинарных данных в объекты ответов
  Stream<TResponse> callBinary<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Uint8List) responseParser,
  }) async* {
    _logger.debug(
        'Инициализация бинарного двунаправленного стрима $serviceName.$methodName');

    // Определяем формат сериализации (бинарный)
    final format = RpcSerializationFormat.binary;

    _logger.debug('Используется формат сериализации: ${format.name}');

    // Создаем сериализаторы для бинарного формата
    final requestSerializer = RpcSerializerFactory.binary<TRequest>(
      (bytes) => throw UnsupportedError(
        'Десериализация TRequest не требуется в клиентском билдере',
      ),
    );

    final responseSerializer =
        RpcSerializerFactory.binary<TResponse>(responseParser);

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
        'Создание клиента бинарного двунаправленного стрима для $serviceName.$methodName');
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
          'Запуск отправки запросов в бинарный двунаправленный стрим $serviceName.$methodName');

      unawaited(() async {
        try {
          await for (final request in requests) {
            _logger.debug(
                'Отправка запроса #${++requestCount} в бинарный двунаправленный стрим $serviceName.$methodName');
            client.send(request);
          }
          _logger.debug(
              'Завершение отправки запросов в бинарный двунаправленный стрим $serviceName.$methodName');
          client.finishSending();
        } catch (e, stackTrace) {
          _logger.error(
              'Ошибка при отправке запросов в бинарный двунаправленный стрим $serviceName.$methodName',
              error: e,
              stackTrace: stackTrace);
        }
      }());

      // Обрабатываем ответы
      _logger.debug(
          'Начало получения ответов из бинарного двунаправленного стрима $serviceName.$methodName');
      int responseCount = 0;

      await for (final message in client.responses) {
        if (message.payload != null) {
          _logger.debug(
              'Получен ответ #${++responseCount} из бинарного двунаправленного стрима $serviceName.$methodName');
          yield message.payload!;
        } else if (message.isMetadataOnly) {
          _logger.debug(
              'Получены метаданные из бинарного двунаправленного стрима $serviceName.$methodName');
        }
      }

      _logger.debug(
          'Стрим бинарных ответов завершен для $serviceName.$methodName');
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка в бинарном двунаправленном стриме $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
          'Закрытие клиента бинарного двунаправленного стрима $serviceName.$methodName');
      await client.close();
    }
  }
}
