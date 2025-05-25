part of '_index.dart';

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
      'Создан builder для двунаправленного стрима $serviceName.$methodName',
    );
  }

  RpcLogger get _logger => endpoint.logger.child(
        'BidirectionalBuilder',
      );

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
      'Инициализация JSON двунаправленного стрима $serviceName.$methodName',
    );

    // Создаем сериализаторы - на стороне клиента мы отправляем объекты напрямую
    final requestSerializer = RpcPassthroughSerializer<TRequest>();
    final responseSerializer = RpcPassthroughSerializer<TResponse>();

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
      'Создание клиента JSON двунаправленного стрима для $serviceName.$methodName',
    );
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
        'Запуск отправки запросов в JSON двунаправленный стрим $serviceName.$methodName',
      );

      // Создаем переменную для отслеживания ошибок в потоке запросов
      final requestsErrorCompleter = Completer<void>();

      unawaited(() async {
        try {
          // Проверка формата сериализации для первого запроса
          bool isFirstRequest = true;

          await for (final request in requests) {
            if (isFirstRequest) {
              try {
                if (request.getFormat() != RpcSerializationFormat.json) {
                  throw RpcException(
                    'Некорректный формат сериализации. Ожидается JSON, '
                    'но объект ${request.runtimeType} использует ${request.getFormat().name}.',
                  );
                }
                isFirstRequest = false;
              } catch (e, stack) {
                requestsErrorCompleter.completeError(e, stack);
                rethrow;
              }
            }

            _logger.debug(
              'Отправка запроса #${++requestCount} в JSON двунаправленный стрим $serviceName.$methodName',
            );
            client.send(request);
          }
          _logger.debug(
            'Завершение отправки запросов в JSON двунаправленный стрим $serviceName.$methodName',
          );
          client.finishSending();

          if (!requestsErrorCompleter.isCompleted) {
            requestsErrorCompleter.complete();
          }
        } catch (e, stackTrace) {
          _logger.error(
              'Ошибка при отправке запросов в JSON двунаправленный стрим $serviceName.$methodName',
              error: e,
              stackTrace: stackTrace);

          if (!requestsErrorCompleter.isCompleted) {
            requestsErrorCompleter.completeError(e, stackTrace);
          }
        }
      }());

      // Обрабатываем ответы
      _logger.debug(
        'Начало получения ответов из JSON двунаправленного стрима $serviceName.$methodName',
      );
      int responseCount = 0;

      await for (final message in client.responses) {
        // Если произошла ошибка в потоке запросов, прерываем обработку
        if (requestsErrorCompleter.isCompleted) {
          try {
            await requestsErrorCompleter.future;
          } catch (e, stack) {
            _logger.error(
                'Ошибка в потоке запросов, прерывание обработки ответов',
                error: e,
                stackTrace: stack);
            rethrow;
          }
        }

        if (message.payload != null) {
          _logger.debug(
            'Получен ответ #${++responseCount} из JSON двунаправленного стрима $serviceName.$methodName',
          );
          yield message.payload!;
        } else if (message.isMetadataOnly) {
          _logger.debug(
            'Получены метаданные из JSON двунаправленного стрима $serviceName.$methodName',
          );
        }
      }

      _logger.debug(
        'Стрим JSON ответов завершен для $serviceName.$methodName',
      );
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка в JSON двунаправленном стриме $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
        'Закрытие клиента JSON двунаправленного стрима $serviceName.$methodName',
      );
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
      'Инициализация бинарного двунаправленного стрима $serviceName.$methodName',
    );

    // Создаем сериализаторы - на стороне клиента мы отправляем объекты напрямую
    final requestSerializer = RpcPassthroughSerializer<TRequest>();
    final responseSerializer = RpcPassthroughSerializer<TResponse>();

    // Создаем клиент с выбранными сериализаторами
    _logger.debug(
      'Создание клиента бинарного двунаправленного стрима для $serviceName.$methodName',
    );
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
        'Запуск отправки запросов в бинарный двунаправленный стрим $serviceName.$methodName',
      );

      // Создаем переменную для отслеживания ошибок в потоке запросов
      final requestsErrorCompleter = Completer<void>();

      unawaited(() async {
        try {
          // Проверка формата сериализации для первого запроса
          bool isFirstRequest = true;

          await for (final request in requests) {
            if (isFirstRequest) {
              try {
                if (request.getFormat() != RpcSerializationFormat.binary) {
                  throw RpcException(
                    'Некорректный формат сериализации. Ожидается binary, '
                    'но объект ${request.runtimeType} использует ${request.getFormat().name}.',
                  );
                }
                isFirstRequest = false;
              } catch (e, stack) {
                requestsErrorCompleter.completeError(e, stack);
                rethrow;
              }
            }

            _logger.debug(
              'Отправка запроса #${++requestCount} в бинарный двунаправленный стрим $serviceName.$methodName',
            );
            client.send(request);
          }
          _logger.debug(
            'Завершение отправки запросов в бинарный двунаправленный стрим $serviceName.$methodName',
          );
          client.finishSending();

          if (!requestsErrorCompleter.isCompleted) {
            requestsErrorCompleter.complete();
          }
        } catch (e, stackTrace) {
          _logger.error(
              'Ошибка при отправке запросов в бинарный двунаправленный стрим $serviceName.$methodName',
              error: e,
              stackTrace: stackTrace);

          if (!requestsErrorCompleter.isCompleted) {
            requestsErrorCompleter.completeError(e, stackTrace);
          }
        }
      }());

      // Обрабатываем ответы
      _logger.debug(
        'Начало получения ответов из бинарного двунаправленного стрима $serviceName.$methodName',
      );
      int responseCount = 0;

      await for (final message in client.responses) {
        // Если произошла ошибка в потоке запросов, прерываем обработку
        if (requestsErrorCompleter.isCompleted) {
          try {
            await requestsErrorCompleter.future;
          } catch (e, stack) {
            _logger.error(
                'Ошибка в потоке запросов, прерывание обработки ответов',
                error: e,
                stackTrace: stack);
            rethrow;
          }
        }

        if (message.payload != null) {
          _logger.debug(
            'Получен ответ #${++responseCount} из бинарного двунаправленного стрима $serviceName.$methodName',
          );
          yield message.payload!;
        } else if (message.isMetadataOnly) {
          _logger.debug(
            'Получены метаданные из бинарного двунаправленного стрима $serviceName.$methodName',
          );
        }
      }

      _logger.debug(
        'Стрим бинарных ответов завершен для $serviceName.$methodName',
      );
    } catch (e, stackTrace) {
      _logger.error(
          'Ошибка в бинарном двунаправленном стриме $serviceName.$methodName',
          error: e,
          stackTrace: stackTrace);
      rethrow;
    } finally {
      _logger.debug(
        'Закрытие клиента бинарного двунаправленного стрима $serviceName.$methodName',
      );
      await client.close();
    }
  }
}
