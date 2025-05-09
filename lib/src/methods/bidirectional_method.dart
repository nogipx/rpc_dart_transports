part of '_method.dart';

/// Класс для работы с RPC методом типа "двунаправленный стриминг" (поток запросов - поток ответов)
final class BidirectionalRpcMethod<T extends RpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект двунаправленного стриминг RPC метода
  BidirectionalRpcMethod(
      RpcEndpoint<T> endpoint, String serviceName, String methodName)
      : super(endpoint, serviceName, methodName);

  /// Создает типизированный двунаправленный канал связи
  ///
  /// [requestParser] - функция для преобразования JSON в объект запроса (опционально)
  /// [responseParser] - функция для преобразования JSON в объект ответа (опционально)
  /// [metadata] - дополнительные метаданные (опционально)
  /// [streamId] - необязательный идентификатор стрима (генерируется автоматически)
  BidirectionalChannel<Request, Response>
      createChannel<Request extends T, Response extends T>({
    Request Function(Map<String, dynamic>)? requestParser,
    Response Function(Map<String, dynamic>)? responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Генерируем ID стрима если не указан
    final effectiveStreamId = streamId ?? RpcMethod.generateUniqueId('stream');

    // Создаем контроллер для исходящих сообщений
    final outgoingController = StreamController<Request>();

    // Инициируем соединение
    endpoint.invoke(
      serviceName,
      methodName,
      {'_bidirectional': true, '_streamId': effectiveStreamId},
      metadata: metadata,
    );

    // Трансформируем входящий поток, применяя parser
    Stream<Response> typedIncomingStream;
    if (responseParser != null) {
      typedIncomingStream = endpoint
          .openStream(
        serviceName,
        methodName,
        streamId: effectiveStreamId,
      )
          .map((data) {
        if (data is Map<String, dynamic>) {
          // Проверяем маркер конца стрима
          if (data['_clientStreamEnd'] == true) {
            // Пропускаем маркер завершения
            throw StateError('StreamEnd');
          }
          // Проверяем маркер закрытия канала
          if (data['_channelClosed'] == true) {
            throw StateError('ChannelClosed');
          }
          try {
            return responseParser(data);
          } catch (e) {
            // В случае ошибки преобразования, логируем через метаданные для middleware
            endpoint.sendStreamData(
              effectiveStreamId,
              null,
              metadata: {
                '_error': 'Ошибка преобразования: $e',
                '_level': 'warning'
              },
              serviceName: serviceName,
              methodName: methodName,
            );
            return data as Response;
          }
        } else {
          return data as Response;
        }
      }).handleError((error) {
        // Игнорируем ошибки маркера завершения стрима
        if (error is StateError &&
            (error.message == 'StreamEnd' ||
                error.message == 'ChannelClosed')) {
          return;
        }
        // Другие ошибки пробрасываем дальше
        throw error;
      });
    } else {
      typedIncomingStream = endpoint
          .openStream(
        serviceName,
        methodName,
        streamId: effectiveStreamId,
      )
          .where((data) {
        // Фильтруем маркеры завершения стрима
        if (data is Map<String, dynamic> &&
            (data['_clientStreamEnd'] == true ||
                data['_channelClosed'] == true)) {
          return false;
        }
        return true;
      }).cast<Response>();
    }

    // Подписываемся на исходящий поток и пересылаем сообщения
    outgoingController.stream.listen(
      (data) {
        endpoint.sendStreamData(
          effectiveStreamId,
          data is RpcMessage ? data.toJson() : data,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      onDone: () {
        // Маркер завершения для клиентского стрима
        endpoint.sendStreamData(
          effectiveStreamId,
          {'_clientStreamEnd': true},
          serviceName: serviceName,
          methodName: methodName,
        );
      },
    );

    // Создаем и возвращаем канал
    return BidirectionalChannel<Request, Response>(
      endpoint: endpoint,
      serviceName: serviceName,
      methodName: methodName,
      streamId: effectiveStreamId,
      outgoingController: outgoingController,
      incomingStream: typedIncomingStream,
    );
  }

  /// Регистрирует обработчик двунаправленного стриминг метода
  ///
  /// [handler] - функция обработки входящих сообщений, возвращающая стрим ответов
  /// [requestParser] - функция для преобразования JSON в объект запроса (опционально)
  /// [responseParser] - функция для преобразования JSON в объект ответа (опционально)
  void register<Request extends T, Response extends T>({
    required Stream<Response> Function(Stream<Request>, String) handler,
    Request Function(Map<String, dynamic>)? requestParser,
    Response Function(Map<String, dynamic>)? responseParser,
  }) {
    // Пытаемся получить контракт, но не требуем его обязательного наличия
    RpcMethodContract<Request, Response> contract;
    try {
      contract =
          getMethodContract<Request, Response>(RpcMethodType.bidirectional);
    } catch (e) {
      // Создаем временный контракт
      contract = RpcMethodContract<Request, Response>(
        methodName: methodName,
        methodType: RpcMethodType.bidirectional,
      );
    }

    final implementation =
        RpcMethodImplementation.bidirectional(contract, handler);

    endpoint.registerMethodImplementation(
        serviceName, methodName, implementation);

    // Регистрируем обработчик метода
    endpoint.registerMethod(
      serviceName,
      methodName,
      (context) async {
        // Получаем данные запроса и проверяем маркер двунаправленного стрима
        final requestData = context.payload;
        final isBidirectional = requestData is Map<String, dynamic> &&
            requestData['_bidirectional'] == true;

        // Получаем или создаем ID стрима, отличный от ID сообщения
        String effectiveStreamId;
        if (isBidirectional &&
            requestData is Map<String, dynamic> &&
            requestData['_streamId'] != null) {
          // Если клиент указал ID стрима, используем его
          effectiveStreamId = requestData['_streamId'] as String;
        } else {
          // Иначе генерируем новый ID стрима (не используем messageId как streamId)
          effectiveStreamId = RpcMethod.generateUniqueId('stream');
        }

        // Если это инициализация двунаправленного стрима
        if (isBidirectional) {
          // Открываем входящий поток и преобразуем его к типу Request
          Stream<Request> typedIncomingStream;
          if (requestParser != null) {
            typedIncomingStream = endpoint
                .openStream(
              serviceName,
              methodName,
              streamId: effectiveStreamId,
            )
                .map((data) {
              if (data is Map<String, dynamic>) {
                // Проверяем маркер конца стрима
                if (data['_clientStreamEnd'] == true) {
                  throw StateError('StreamEnd');
                }
                // Проверяем маркер закрытия канала
                if (data['_channelClosed'] == true) {
                  throw StateError('ChannelClosed');
                }
                return requestParser(data);
              } else {
                return data as Request;
              }
            }).handleError((error) {
              // Игнорируем ошибки маркера завершения
              if (error is StateError &&
                  (error.message == 'StreamEnd' ||
                      error.message == 'ChannelClosed')) {
                return;
              }
              throw error;
            });
          } else {
            typedIncomingStream = endpoint
                .openStream(
              serviceName,
              methodName,
              streamId: effectiveStreamId,
            )
                .where((data) {
              if (data is Map<String, dynamic> &&
                  (data['_clientStreamEnd'] == true ||
                      data['_channelClosed'] == true)) {
                return false;
              }
              return true;
            }).cast<Request>();
          }

          // Создаем исходящий поток через обработчик
          final outgoingStream = implementation.openBidirectionalStream(
            typedIncomingStream,
            effectiveStreamId,
          );

          // Подписываемся на исходящий поток и отправляем данные
          outgoingStream.listen(
            (data) {
              endpoint.sendStreamData(
                effectiveStreamId,
                data is RpcMessage ? data.toJson() : data,
                serviceName: serviceName,
                methodName: methodName,
              );
            },
            onError: (error) {
              endpoint.sendStreamError(
                effectiveStreamId,
                error.toString(),
              );
            },
            onDone: () {
              endpoint.closeStream(
                effectiveStreamId,
                serviceName: serviceName,
                methodName: methodName,
              );
            },
          );

          // Возвращаем подтверждение установки соединения
          return {
            'status': 'bidirectional_streaming',
            'streamId': effectiveStreamId
          };
        } else {
          // Если это обычный запрос, обрабатываем по старой логике
          // Это может быть нужно для совместимости или других целей
          return {'error': 'Для этого метода требуется маркер _bidirectional'};
        }
      },
    );
  }
}

/// Двунаправленный канал связи для типизированного обмена сообщениями
final class BidirectionalChannel<Request extends RpcSerializableMessage,
    Response extends RpcSerializableMessage> {
  /// Endpoint для связи
  final RpcEndpoint _endpoint;

  /// Название сервиса
  final String serviceName;

  /// Название метода
  final String methodName;

  /// ID потока
  final String streamId;

  /// Контроллер для исходящих сообщений
  final StreamController<Request> outgoingController;

  /// Поток входящих сообщений
  final Stream<Response> incomingStream;

  /// Создает новый двунаправленный канал
  BidirectionalChannel({
    required RpcEndpoint endpoint,
    required this.serviceName,
    required this.methodName,
    required this.streamId,
    required this.outgoingController,
    required this.incomingStream,
  }) : _endpoint = endpoint;

  /// Отправляет сообщение в канал
  void send(Request message) {
    if (outgoingController.isClosed) {
      throw StateError('Канал закрыт для отправки');
    }
    outgoingController.add(message);
  }

  /// Получает поток входящих сообщений
  Stream<Response> get incoming => incomingStream;

  /// Закрывает канал
  Future<void> close() async {
    // Завершаем исходящий поток
    await outgoingController.close();

    // Отправляем маркер завершения канала
    await _endpoint.sendStreamData(
      streamId,
      {'_channelClosed': true},
      serviceName: serviceName,
      methodName: methodName,
    );

    // Закрываем канал
    await _endpoint.closeStream(
      streamId,
      serviceName: serviceName,
      methodName: methodName,
    );
  }
}
