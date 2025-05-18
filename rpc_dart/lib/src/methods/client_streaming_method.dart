// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "клиентский стриминг" (поток запросов - с ответом или без)
/// Поддерживает два режима:
/// 1. С ответом после завершения обработки (как в gRPC)
/// 2. Без ответа (упрощенный режим)
final class ClientStreamingRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Статическая карта для хранения активных стримов
  /// Ключ: serviceName + methodName + идентификатор клиента (если нужно)
  /// Значение: кешированный стрим и его метаданные
  static final Map<String, _CachedStream> _streamCache = {};

  /// Создает ключ для кеша стримов
  String _createCacheKey<Request extends T, Response extends T>({
    String? streamId,
    String? clientId,
  }) {
    // Формируем ключ из имени сервиса и метода
    // Можно также добавить clientId для разделения по клиентам, если нужно
    final key = '$serviceName.$methodName';
    if (clientId != null) {
      return '$key.$clientId';
    }
    return key;
  }

  /// Периодически очищает кеш от закрытых или устаревших стримов
  static void _cleanupCache() {
    final keysToRemove = <String>[];

    // Находим все ключи, соответствующие закрытым стримам
    for (final entry in _streamCache.entries) {
      final cachedStream = entry.value;

      // Если стрим закрыт или истек срок жизни кеша
      if (cachedStream.isClosed ||
          DateTime.now().difference(cachedStream.createdAt).inMinutes > 30) {
        keysToRemove.add(entry.key);
      }
    }

    // Удаляем найденные ключи
    for (final key in keysToRemove) {
      _streamCache.remove(key);
    }
  }

  /// Создает новый объект клиентского стриминг RPC метода
  ClientStreamingRpcMethod(
    IRpcEndpoint endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName) {
    // Создаем логгер с консистентным именем
    _logger = RpcLogger('$serviceName.$methodName.client_stream');
  }

  /// Открывает клиентский стриминг канал и возвращает объект для отправки запросов
  ///
  /// [metadata] - метаданные запроса (опционально)
  /// [streamId] - ID стрима (опционально, генерируется автоматически)
  /// [clientId] - ID клиента (опционально, для разделения по клиентам)
  /// [forceNewStream] - флаг создания нового стрима даже если существует активный
  ClientStreamingBidiStream<Request, Response>
      call<Request extends T, Response extends T>({
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
    String? clientId,
    bool forceNewStream = false,
  }) {
    // Периодически очищаем кеш стримов
    _cleanupCache();

    // Создаем ключ для кеша
    final cacheKey = _createCacheKey<Request, Response>(
      streamId: streamId,
      clientId: clientId,
    );

    // Проверяем, есть ли уже активный стрим в кеше, если нас не просят создать новый поток
    if (!forceNewStream && _streamCache.containsKey(cacheKey)) {
      final cachedStream = _streamCache[cacheKey]!;

      // Если стрим активен, используем его
      if (!cachedStream.isClosed) {
        _logger?.debug('Переиспользуем существующий стрим из кеша: $cacheKey');
        return cachedStream.stream
            as ClientStreamingBidiStream<Request, Response>;
      } else {
        // Если стрим закрыт, удаляем его из кеша
        _streamCache.remove(cacheKey);
      }
    }

    // Если в кеше нет активного стрима или нужно создать новый, создаем его
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('client_stream');
    final startTime = DateTime.now().millisecondsSinceEpoch;

    _logger?.debug('Инициализация клиентского стрима с ID: $effectiveStreamId');

    // Отправляем метрику о создании стрима
    _diagnostic?.reportStreamMetric(
      _diagnostic!.createStreamMetric(
        eventType: RpcStreamEventType.created,
        streamId: effectiveStreamId,
        direction: RpcStreamDirection.clientToServer,
        method: '$serviceName.$methodName',
      ),
    );

    // Счетчики для диагностики
    var sentMessageCount = 0;
    var totalSentDataSize = 0;

    // Создаем контроллер для ответа
    final responseController = StreamController<Response>();

    // Создаем маркер инициализации клиентского стрима
    final clientStreamMarker = RpcClientStreamingMarker(
      streamId: effectiveStreamId,
      parameters: metadata,
    );

    // Используем единый способ инициализации через openStream с маркером
    final responseStream = _engine.openStream(
      serviceName: serviceName,
      methodName: methodName,
      request: clientStreamMarker,
      metadata: metadata,
      streamId: effectiveStreamId,
    );

    // Подписываемся на поток ответов от сервера
    responseStream.listen(
      (response) {
        // Обрабатываем ответ от сервера после завершения стрима
        if (response != null && !responseController.isClosed) {
          try {
            // Проверяем, не является ли ответ маркером
            if (!RpcMarkerHandler.isServiceMarker(response)) {
              // Преобразуем ответ в нужный тип
              final parsedResponse = responseParser(response);

              // Добавляем ответ в контроллер
              responseController.add(parsedResponse);
            }
          } catch (error, stackTrace) {
            // В случае ошибки преобразования добавляем ошибку в контроллер
            _logger?.error(
              'Ошибка при преобразовании ответа: $error',
              error: error,
              stackTrace: stackTrace,
            );
            responseController.addError(error, stackTrace);
          }
        }
      },
      onError: (error, stackTrace) {
        // В случае ошибки в потоке добавляем ошибку в контроллер ответов
        _logger?.error(
          'Ошибка потока ответов: $error',
          error: error,
          stackTrace: stackTrace,
        );
        if (!responseController.isClosed) {
          responseController.addError(error, stackTrace);
        }
      },
      onDone: () {
        // Закрываем контроллер ответов при завершении потока
        if (!responseController.isClosed) {
          responseController.close();
        }

        // Удаляем стрим из кеша
        _streamCache.remove(cacheKey);
        _logger?.debug('Удален стрим из кеша при завершении: $cacheKey');
      },
    );

    // Создаем BidiStream для передачи в ClientStreamingBidiStream
    final bidiStream = BidiStream<Request, Response>(
      responseStream: responseController.stream,
      sendFunction: (request) {
        try {
          // Преобразуем запрос в JSON, если это RpcMessage
          final processedRequest =
              request is RpcMessage ? request.toJson() : request;

          // Отправляем запрос в стрим, используя тот же streamId
          _engine.sendStreamData(
            streamId: effectiveStreamId,
            data: processedRequest,
            serviceName: serviceName,
            methodName: methodName,
          );

          // Увеличиваем счетчики для диагностики
          sentMessageCount++;
          final dataSize = processedRequest.toString().length;
          totalSentDataSize += dataSize;

          // Отправляем метрику об отправке сообщения
          _diagnostic?.reportStreamMetric(
            _diagnostic!.createStreamMetric(
              eventType: RpcStreamEventType.messageSent,
              streamId: effectiveStreamId,
              direction: RpcStreamDirection.clientToServer,
              method: '$serviceName.$methodName',
              dataSize: dataSize,
              messageCount: sentMessageCount,
            ),
          );
        } catch (e, stackTrace) {
          // Логируем ошибку при отправке сообщения
          _logger?.error(
            'Ошибка при отправке сообщения: $e',
            error: e,
            stackTrace: stackTrace,
          );
          responseController.addError(e, stackTrace);
        }
      },
      // Реализуем finishTransferFunction для завершения отправки
      finishTransferFunction: () async {
        _logger?.debug('Вызов finishTransfer - отправка маркера завершения');

        try {
          final endTime = DateTime.now().millisecondsSinceEpoch;
          final duration = endTime - startTime;

          // Отправляем метрику о закрытии потока запросов
          _diagnostic?.reportStreamMetric(
            _diagnostic!.createStreamMetric(
              eventType: RpcStreamEventType.closed,
              streamId: effectiveStreamId,
              direction: RpcStreamDirection.clientToServer,
              method: '$serviceName.$methodName',
              messageCount: sentMessageCount,
              throughput:
                  sentMessageCount > 0 ? (totalSentDataSize / duration) : 0,
              duration: duration,
            ),
          );

          // Отправляем типизированный маркер завершения потока запросов
          await _engine.sendServiceMarker(
            streamId: effectiveStreamId,
            marker: const RpcClientStreamEndMarker(),
            serviceName: serviceName,
            methodName: methodName,
          );

          _logger?.debug('Маркер завершения потока отправлен');
        } catch (e, stackTrace) {
          _logger?.error(
            'Ошибка при отправке маркера завершения потока: $e',
            error: e,
            stackTrace: stackTrace,
          );
        }
      },
      closeFunction: () async {
        // Закрываем контроллер ответов при закрытии BidiStream
        if (!responseController.isClosed) {
          await responseController.close();
        }

        // Удаляем стрим из кеша
        _streamCache.remove(cacheKey);
        _logger?.debug('Удален стрим из кеша при закрытии: $cacheKey');
      },
    );

    // Создаем и оборачиваем в ClientStreamingBidiStream
    final streamingBidiStream =
        ClientStreamingBidiStream<Request, Response>(bidiStream);

    // Сохраняем стрим в кеше
    _streamCache[cacheKey] = _CachedStream(
      stream: streamingBidiStream,
      streamId: effectiveStreamId,
      createdAt: DateTime.now(),
    );

    _logger?.debug('Сохранен новый стрим в кеш: $cacheKey');

    return streamingBidiStream;
  }

  /// Регистрирует обработчик клиентского стриминг метода
  ///
  /// [handler] - функция обработки потока запросов
  /// [requestParser] - функция для преобразования JSON в объект запроса
  /// [responseParser] - функция для преобразования JSON в объект ответа
  void register<Request extends T, Response extends T>({
    required dynamic handler,
    required RpcMethodArgumentParser<Request> requestParser,
    RpcMethodArgumentParser<Response>? responseParser,
  }) {
    // Получаем контракт сервиса
    final serviceContract = _endpoint.getServiceContract(serviceName);
    if (serviceContract == null) {
      throw Exception(
          'Контракт сервиса $serviceName не найден. Необходимо сначала зарегистрировать контракт сервиса.');
    }

    // Проверяем, существует ли метод в контракте
    final existingMethod =
        serviceContract.findMethod<Request, Response>(methodName);

    // Если метод не найден в контракте, добавляем его
    if (existingMethod == null) {
      // Определяем тип обработчика и добавляем соответствующий метод
      if (handler is RpcMethodClientStreamHandler<Request, Response>) {
        // Проверяем, что передан парсер ответа
        if (responseParser == null) {
          throw ArgumentError(
            'Для обработчика с ответом необходимо указать responseParser',
          );
        }

        // Добавляем метод с ответом
        serviceContract.addClientStreamingMethod<Request, Response>(
          methodName: methodName,
          handler: handler,
          argumentParser: requestParser,
          responseParser: responseParser,
        );
      } else {
        throw ArgumentError(
          'Неподдерживаемый тип обработчика: ${handler.runtimeType}',
        );
      }
    }

    // Получаем актуальный контракт метода
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.clientStreaming);

    // Создаем соответствующую реализацию метода, в зависимости от типа обработчика
    final implementation =
        RpcMethodImplementation<Request, Response>.clientStreaming(
            contract, handler);

    // Регистрируем реализацию метода
    _registry.registerMethodImplementation(
      serviceName: serviceName,
      methodName: methodName,
      implementation: implementation,
    );

    // Регистрируем низкоуровневый обработчик
    _registry.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      methodType: RpcMethodType.clientStreaming,
      argumentParser: requestParser,
      responseParser: responseParser,
      handler: RpcMethodAdapterFactory.createClientStreamHandlerAdapter(
        handler,
      ),
    );
  }
}

/// Класс для хранения кешированного стрима и его метаданных
class _CachedStream {
  final dynamic stream;
  final String streamId;
  final DateTime createdAt;

  _CachedStream({
    required this.stream,
    required this.streamId,
    required this.createdAt,
  });

  /// Проверяет, закрыт ли стрим
  bool get isClosed {
    if (stream is ClientStreamingBidiStream) {
      return (stream as ClientStreamingBidiStream).isClosed;
    }
    return false;
  }
}
