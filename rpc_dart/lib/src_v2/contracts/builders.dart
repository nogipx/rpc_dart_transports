part of '_index.dart';

/// Builder для унарных запросов
class RpcUnaryRequestBuilder {
  final RpcEndpoint endpoint;
  final String serviceName;
  final String methodName;
  final RpcSerializationFormat? _preferredFormat;

  RpcUnaryRequestBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
    RpcSerializationFormat? preferredFormat,
  }) : _preferredFormat = preferredFormat;

  Future<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Map<String, dynamic>) responseParser,
    RpcSerializationFormat? serializationFormat,
  }) async {
    // Определяем формат сериализации: указанный в вызове > предпочтительный > из объекта запроса
    final format =
        serializationFormat ?? _preferredFormat ?? request.getFormat();

    // Создаем сериализаторы в зависимости от формата
    final IRpcSerializer<TRequest> requestSerializer;
    final IRpcSerializer<TResponse> responseSerializer;

    if (format == RpcSerializationFormat.binary) {
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
            final jsonMap = jsonDecode(utf8.decode(bytes));
            return responseParser(jsonMap as Map<String, dynamic>);
          } catch (e) {
            throw FormatException(
              'Невозможно десериализовать ответ. Убедитесь, что у вашего типа '
              'есть статический метод fromBytes или укажите правильный '
              'responseParser.',
            );
          }
        },
      );
    } else {
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
    final client = UnaryClient<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: endpoint.logger,
    );

    try {
      final response = await client.call(request);
      return response;
    } finally {
      await client.close();
    }
  }
}

/// Builder для серверных стримов
class RpcServerStreamBuilder {
  final RpcEndpoint endpoint;
  final String serviceName;
  final String methodName;
  final RpcSerializationFormat? _preferredFormat;

  RpcServerStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
    RpcSerializationFormat? preferredFormat,
  }) : _preferredFormat = preferredFormat;

  Stream<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Map<String, dynamic>) responseParser,
    RpcSerializationFormat? serializationFormat,
  }) async* {
    // Определяем формат сериализации: указанный в вызове > предпочтительный > из объекта запроса
    final format =
        serializationFormat ?? _preferredFormat ?? request.getFormat();

    // Создаем сериализаторы в зависимости от формата
    final IRpcSerializer<TRequest> requestSerializer;
    final IRpcSerializer<TResponse> responseSerializer;

    if (format == RpcSerializationFormat.binary) {
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
            final jsonMap = jsonDecode(utf8.decode(bytes));
            return responseParser(jsonMap as Map<String, dynamic>);
          } catch (e) {
            throw FormatException(
              'Невозможно десериализовать ответ. Убедитесь, что у вашего типа '
              'есть статический метод fromBytes или укажите правильный '
              'responseParser.',
            );
          }
        },
      );
    } else {
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
    final client = ServerStreamClient<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: endpoint.logger,
    );

    try {
      await client.send(request);
      await for (final message in client.responses) {
        if (message.payload != null) {
          yield message.payload!;
        }
      }
    } finally {
      await client.close();
    }
  }
}

/// Builder для клиентских стримов
class RpcClientStreamBuilder {
  final RpcEndpoint endpoint;
  final String serviceName;
  final String methodName;
  final RpcSerializationFormat? _preferredFormat;

  RpcClientStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
    RpcSerializationFormat? preferredFormat,
  }) : _preferredFormat = preferredFormat;

  Future<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Map<String, dynamic>) responseParser,
    RpcSerializationFormat? serializationFormat,
  }) async {
    // Определяем формат сериализации (используем предпочтительный, если указан)
    final format =
        serializationFormat ?? _preferredFormat ?? RpcSerializationFormat.json;

    // Создаем сериализаторы в зависимости от формата
    final IRpcSerializer<TRequest> requestSerializer;
    final IRpcSerializer<TResponse> responseSerializer;

    if (format == RpcSerializationFormat.binary) {
      // Для binary формата (потенциально protobuf)
      // Можно использовать формат первого элемента в потоке, если нужно
      // Пример:
      // TRequest? firstRequest;
      // try {
      //   firstRequest = await requests.first.timeout(Duration(milliseconds: 10));
      //   final requestFormat = firstRequest?.getFormat() ?? format;
      // } catch (_) {
      //   // Если не можем получить первый элемент за таймаут, используем указанный формат
      // }

      // Создаем сериализаторы для бинарного формата
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) {
          try {
            // Пробуем через JSON
            final jsonMap = jsonDecode(utf8.decode(bytes));
            return responseParser(jsonMap as Map<String, dynamic>);
          } catch (e) {
            throw FormatException(
              'Невозможно десериализовать ответ. Убедитесь, что у вашего типа '
              'есть статический метод fromBytes или укажите правильный '
              'responseParser.',
            );
          }
        },
      );
    } else {
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
    final client = ClientStreamClient<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: endpoint.logger,
    );

    try {
      await for (final request in requests) {
        client.send(request);
      }
      final response = await client.finishSending();
      return response;
    } finally {
      await client.close();
    }
  }
}

/// Builder для двунаправленных стримов
class RpcBidirectionalStreamBuilder {
  final RpcEndpoint endpoint;
  final String serviceName;
  final String methodName;
  final RpcSerializationFormat? _preferredFormat;

  RpcBidirectionalStreamBuilder({
    required this.endpoint,
    required this.serviceName,
    required this.methodName,
    RpcSerializationFormat? preferredFormat,
  }) : _preferredFormat = preferredFormat;

  Stream<TResponse> call<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Map<String, dynamic>) responseParser,
    RpcSerializationFormat? serializationFormat,
  }) async* {
    // Определяем формат сериализации (используем предпочтительный, если указан)
    final format =
        serializationFormat ?? _preferredFormat ?? RpcSerializationFormat.json;

    // Создаем сериализаторы в зависимости от формата
    final IRpcSerializer<TRequest> requestSerializer;
    final IRpcSerializer<TResponse> responseSerializer;

    if (format == RpcSerializationFormat.binary) {
      // Для binary формата (потенциально protobuf)
      // Можно использовать формат первого элемента в потоке, если нужно
      // Пример:
      // TRequest? firstRequest;
      // try {
      //   firstRequest = await requests.first.timeout(Duration(milliseconds: 10));
      //   final requestFormat = firstRequest?.getFormat() ?? format;
      // } catch (_) {
      //   // Если не можем получить первый элемент за таймаут, используем указанный формат
      // }

      // Создаем сериализаторы для бинарного формата
      requestSerializer = RpcSerializerFactory.binary<TRequest>(
        (bytes) => throw UnsupportedError(
          'Десериализация TRequest не требуется в клиентском билдере',
        ),
      );

      responseSerializer = RpcSerializerFactory.binary<TResponse>(
        (bytes) {
          try {
            // Пробуем через JSON
            final jsonMap = jsonDecode(utf8.decode(bytes));
            return responseParser(jsonMap as Map<String, dynamic>);
          } catch (e) {
            throw FormatException(
              'Невозможно десериализовать ответ. Убедитесь, что у вашего типа '
              'есть статический метод fromBytes или укажите правильный '
              'responseParser.',
            );
          }
        },
      );
    } else {
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
    final client = BidirectionalStreamClient<TRequest, TResponse>(
      transport: endpoint.transport,
      serviceName: serviceName,
      methodName: methodName,
      requestSerializer: requestSerializer,
      responseSerializer: responseSerializer,
      logger: endpoint.logger,
    );

    try {
      unawaited(() async {
        await for (final request in requests) {
          client.send(request);
        }
        client.finishSending();
      }());

      await for (final message in client.responses) {
        if (message.payload != null) {
          yield message.payload!;
        }
      }
    } finally {
      await client.close();
    }
  }

  /// Вызов с бинарным парсером (для обратной совместимости)
  Stream<TResponse> callWithBinaryParser<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required Stream<TRequest> requests,
    required TResponse Function(Uint8List bytes) responseParser,
  }) async* {
    final client = BidirectionalStreamClient<TRequest, TResponse>(
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
      logger: endpoint.logger,
    );

    try {
      unawaited(() async {
        await for (final request in requests) {
          client.send(request);
        }
        client.finishSending();
      }());

      await for (final message in client.responses) {
        if (message.payload != null) {
          yield message.payload!;
        }
      }
    } finally {
      await client.close();
    }
  }
}
