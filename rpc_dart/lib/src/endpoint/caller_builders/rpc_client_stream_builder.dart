part of '_index.dart';

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
      'Создан builder для клиентского стрима $serviceName.$methodName',
    );
  }

  RpcLogger get _logger => endpoint.logger.child(
        'ClientBuilder',
      );

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
      'Инициализация JSON клиентского стрима $serviceName.$methodName',
    );

    // Создаем сериализаторы - на стороне клиента мы отправляем объекты напрямую
    final requestSerializer = PassthroughSerializer<TRequest>();
    final responseSerializer = PassthroughSerializer<TResponse>();

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
      'Создание клиента JSON клиентского стрима для $serviceName.$methodName',
    );
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
        'Начало отправки запросов в JSON клиентский стрим $serviceName.$methodName',
      );
      int requestCount = 0;

      // Проверка формата сериализации для первого запроса
      bool isFirstRequest = true;

      await for (final request in requests) {
        if (isFirstRequest) {
          if (request.getFormat() != RpcSerializationFormat.json) {
            throw RpcException(
              'Некорректный формат сериализации. Ожидается JSON, '
              'но объект ${request.runtimeType} использует ${request.getFormat().name}.',
            );
          }
          isFirstRequest = false;
        }

        _logger.debug(
          'Отправка запроса #${++requestCount} в JSON клиентский стрим $serviceName.$methodName',
        );
        client.send(request);
      }

      _logger.debug(
        'Завершение отправки запросов и ожидание ответа $serviceName.$methodName',
      );
      final response = await client.finishSending();
      _logger.debug(
        'Получен финальный ответ от $serviceName.$methodName',
      );
      return response;
    } catch (e, stackTrace) {
      _logger.error('Ошибка в JSON клиентском стриме $serviceName.$methodName',
          error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
        'Закрытие клиента JSON клиентского стрима $serviceName.$methodName',
      );
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
      'Инициализация бинарного клиентского стрима $serviceName.$methodName',
    );

    // Создаем сериализаторы - на стороне клиента мы отправляем объекты напрямую
    final requestSerializer = PassthroughSerializer<TRequest>();
    final responseSerializer = PassthroughSerializer<TResponse>();

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
      'Создание клиента бинарного клиентского стрима для $serviceName.$methodName',
    );
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
        'Начало отправки запросов в бинарный клиентский стрим $serviceName.$methodName',
      );
      int requestCount = 0;

      // Проверка формата сериализации для первого запроса
      bool isFirstRequest = true;

      await for (final request in requests) {
        if (isFirstRequest) {
          if (request.getFormat() != RpcSerializationFormat.binary) {
            throw RpcException(
              'Некорректный формат сериализации. Ожидается binary, '
              'но объект ${request.runtimeType} использует ${request.getFormat().name}.',
            );
          }
          isFirstRequest = false;
        }

        _logger.debug(
          'Отправка запроса #${++requestCount} в бинарный клиентский стрим $serviceName.$methodName',
        );
        client.send(request);
      }

      _logger.debug(
        'Завершение отправки запросов и ожидание ответа $serviceName.$methodName',
      );
      final response = await client.finishSending();
      _logger.debug(
        'Получен финальный ответ от $serviceName.$methodName',
      );
      return response;
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка в бинарном клиентском стриме $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
        'Закрытие клиента бинарного клиентского стрима $serviceName.$methodName',
      );
      await client.close();
    }
  }
}
