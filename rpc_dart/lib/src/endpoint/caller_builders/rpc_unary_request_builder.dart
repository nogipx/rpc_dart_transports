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
    _logger.debug(
      'Создан builder для унарного запроса $serviceName.$methodName',
    );
  }

  RpcLogger get _logger => endpoint.logger.child(
        'UnaryBuilder',
      );

  /// Выполняет унарный запрос с JSON сериализацией
  ///
  /// [request] - Объект запроса, который будет сериализован в JSON
  /// [responseParser] - Функция для преобразования JSON в объект ответа
  Future<TResponse> callJson<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required TRequest request,
    required TResponse Function(Map<String, dynamic>) responseParser,
  }) async {
    _logger.debug(
      'Выполнение JSON унарного запроса $serviceName.$methodName',
    );

    // Проверяем формат сериализации запроса
    if (request.getFormat() != RpcSerializationFormat.json) {
      throw RpcException(
        'Некорректный формат сериализации. Ожидается JSON, '
        'но объект ${request.runtimeType} использует ${request.getFormat().name}.',
      );
    }

    // Создаем сериализаторы для запроса и ответа - на стороне клиента мы отправляем объекты напрямую
    final requestSerializer = RpcPassthroughSerializer<TRequest>();
    final responseSerializer = RpcPassthroughSerializer<TResponse>();

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
      'Создание унарного клиента для $serviceName.$methodName (JSON)',
    );
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
        'Отправка JSON унарного запроса $serviceName.$methodName',
      );
      final response = await client.call(request);
      _logger.debug(
        'Получен ответ на JSON унарный запрос $serviceName.$methodName',
      );
      return response;
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка при выполнении JSON унарного запроса $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
        'Закрытие унарного клиента $serviceName.$methodName',
      );
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
      'Выполнение бинарного унарного запроса $serviceName.$methodName',
    );

    // Проверяем формат сериализации запроса
    if (request.getFormat() != RpcSerializationFormat.binary) {
      throw RpcException(
        'Некорректный формат сериализации. Ожидается binary, '
        'но объект ${request.runtimeType} использует ${request.getFormat().name}.',
      );
    }

    // Создаем сериализаторы для запроса и ответа - на стороне клиента мы отправляем объекты напрямую
    final requestSerializer = RpcPassthroughSerializer<TRequest>();
    final responseSerializer = RpcPassthroughSerializer<TResponse>();

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
      'Создание унарного клиента для $serviceName.$methodName (binary)',
    );
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
        'Отправка бинарного унарного запроса $serviceName.$methodName',
      );
      final response = await client.call(request);
      _logger.debug(
        'Получен ответ на бинарный унарный запрос $serviceName.$methodName',
      );
      return response;
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка при выполнении бинарного унарного запроса $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
        'Закрытие унарного клиента $serviceName.$methodName',
      );
      await client.close();
    }
  }
}
