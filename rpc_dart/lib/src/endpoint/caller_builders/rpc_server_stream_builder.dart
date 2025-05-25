part of '_index.dart';

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
    _logger.debug(
      'Создан builder для серверного стрима $serviceName.$methodName',
    );
  }

  RpcLogger get _logger => endpoint.logger.child(
        'ServerBuilder',
      );

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

    _logger.debug(
      'Инициализация JSON серверного стрима $serviceName.$methodName',
    );

    // Проверяем формат сериализации запроса
    if (request.getFormat() != RpcSerializationFormat.json) {
      streamController.addError(RpcException(
          'Некорректный формат сериализации. Ожидается JSON, '
          'но объект ${request.runtimeType} использует ${request.getFormat().name}.'));
      return streamController.stream;
    }

    // Создаем сериализаторы - на стороне клиента мы отправляем объекты напрямую
    final requestSerializer = RpcPassthroughSerializer<TRequest>();
    final responseSerializer = RpcPassthroughSerializer<TResponse>();

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
      'Создание клиента JSON серверного стрима для $serviceName.$methodName',
    );
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
          'Отправка запроса в JSON серверный стрим $serviceName.$methodName',
        );
        await client.send(request);
        _logger.debug(
          'Начало получения ответов из JSON серверного стрима $serviceName.$methodName',
        );

        await for (final message in client.responses) {
          if (message.payload != null) {
            _logger.debug(
              'Получен ответ из JSON серверного стрима $serviceName.$methodName',
            );
            streamController.add(message.payload!);
          } else if (message.isMetadataOnly) {
            _logger.debug(
              'Получены метаданные из JSON серверного стрима $serviceName.$methodName',
            );
          }
        }

        _logger.debug(
          'Стрим JSON ответов завершен для $serviceName.$methodName',
        );
        await streamController.close();
      } catch (e, stackTrace) {
        _logger.error('Ошибка в JSON серверном стриме $serviceName.$methodName',
            error: e, stackTrace: stackTrace);
        streamController.addError(e, stackTrace);
      } finally {
        _logger.debug(
          'Закрытие клиента JSON серверного стрима $serviceName.$methodName',
        );
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
      'Инициализация бинарного серверного стрима $serviceName.$methodName',
    );

    // Проверяем формат сериализации запроса
    if (request.getFormat() != RpcSerializationFormat.binary) {
      streamController.addError(RpcException(
          'Некорректный формат сериализации. Ожидается binary, '
          'но объект ${request.runtimeType} использует ${request.getFormat().name}.'));
      return streamController.stream;
    }

    // Создаем сериализаторы - на стороне клиента мы отправляем объекты напрямую
    final requestSerializer = RpcPassthroughSerializer<TRequest>();
    final responseSerializer = RpcPassthroughSerializer<TResponse>();

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
      'Создание клиента бинарного серверного стрима для $serviceName.$methodName',
    );
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
          'Отправка запроса в бинарный серверный стрим $serviceName.$methodName',
        );
        await client.send(request);
        _logger.debug(
          'Начало получения ответов из бинарного серверного стрима $serviceName.$methodName',
        );

        await for (final message in client.responses) {
          if (message.payload != null) {
            _logger.debug(
              'Получен ответ из бинарного серверного стрима $serviceName.$methodName',
            );
            streamController.add(message.payload!);
          } else if (message.isMetadataOnly) {
            _logger.debug(
              'Получены метаданные из бинарного серверного стрима $serviceName.$methodName',
            );
          }
        }

        _logger.debug(
          'Стрим бинарных ответов завершен для $serviceName.$methodName',
        );
        await streamController.close();
      } catch (e, stackTrace) {
        _logger.error(
            'Ошибка в бинарном серверном стриме $serviceName.$methodName',
            error: e,
            stackTrace: stackTrace);
        streamController.addError(e, stackTrace);
      } finally {
        _logger.debug(
          'Закрытие клиента бинарного серверного стрима $serviceName.$methodName',
        );
        await client.close();
      }
    }();

    return streamController.stream;
  }
}
