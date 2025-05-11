// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "двунаправленный стриминг" (поток запросов - поток ответов)
final class BidirectionalStreamingRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект двунаправленного стриминг RPC метода
  const BidirectionalStreamingRpcMethod(
    IRpcEndpoint<T> endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName);

  /// Создает типизированный двунаправленный канал связи
  ///
  /// [responseParser] - функция для преобразования JSON в объект ответа (опционально)
  /// [metadata] - дополнительные метаданные (опционально)
  /// [streamId] - необязательный идентификатор стрима (генерируется автоматически)
  BidiStream<Request, Response> call<Request extends T, Response extends T>({
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Генерируем ID стрима если не указан
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('bidirectional_stream');

    // Создаем контроллер для исходящих сообщений
    final outgoingController = StreamController<Request>();

    // Инициируем соединение
    _core.invoke(
      serviceName: serviceName,
      methodName: methodName,
      request: {'_bidirectional': true, '_streamId': effectiveStreamId},
      metadata: metadata,
    );

    // Трансформируем входящий поток, применяя parser
    Stream<Response> typedIncomingStream;
    typedIncomingStream = _core
        .openStream(
      serviceName: serviceName,
      methodName: methodName,
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
          _core.sendStreamData(
            streamId: effectiveStreamId,
            data: null,
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
          (error.message == 'StreamEnd' || error.message == 'ChannelClosed')) {
        return;
      }
      // Другие ошибки пробрасываем дальше
      throw error;
    });

    // Подписываемся на исходящий поток и пересылаем сообщения
    outgoingController.stream.listen(
      (data) {
        _core.sendStreamData(
          streamId: effectiveStreamId,
          data: data is RpcMessage ? data.toJson() : data,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      onDone: () {
        // Маркер завершения для клиентского стрима
        _core.sendStreamData(
          streamId: effectiveStreamId,
          data: {'_clientStreamEnd': true},
          serviceName: serviceName,
          methodName: methodName,
        );
      },
    );

    return BidiStream(
      responseStream: typedIncomingStream,
      sendFunction: (request) => outgoingController.add(request),
      closeFunction: () => outgoingController.close(),
    );
  }

  /// Регистрирует обработчик двунаправленного стриминг метода
  ///
  /// [handler] - функция обработки входящих сообщений, возвращающая стрим ответов
  /// [requestParser] - функция для преобразования JSON в объект запроса (опционально)
  /// [responseParser] - функция для преобразования JSON в объект ответа (опционально)
  void register<Request extends T, Response extends T>({
    required RpcMethodBidirectionalHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> requestParser,
    required RpcMethodResponseParser<Response> responseParser,
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
      serviceContract.addBidirectionalStreamingMethod<Request, Response>(
        methodName: methodName,
        handler: handler,
        argumentParser: requestParser,
        responseParser: responseParser,
      );
    }

    // Получаем актуальный контракт метода
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.bidirectional);

    final implementation =
        RpcMethodImplementation.bidirectionalStreaming(contract, handler);

    // Регистрируем реализацию метода
    _registrar.registerMethodImplementation(
      serviceName: serviceName,
      methodName: methodName,
      implementation: implementation,
    );

    // Регистрируем низкоуровневый обработчик - это ключевой шаг для обеспечения
    // связи между контрактом и обработчиком вызова
    _registrar.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      handler: (context) async {
        // Получаем данные запроса и проверяем маркер двунаправленного стрима
        final requestData = context.payload;
        final isBidirectional = requestData is Map<String, dynamic> &&
            requestData['_bidirectional'] == true;

        // Получаем или создаем ID стрима, отличный от ID сообщения
        String effectiveStreamId;
        if (isBidirectional && requestData['_streamId'] != null) {
          // Если клиент указал ID стрима, используем его
          effectiveStreamId = requestData['_streamId'] as String;
        } else {
          // Иначе генерируем новый ID стрима (не используем messageId как streamId)
          effectiveStreamId = _endpoint.generateUniqueId('stream');
        }

        // Если это инициализация двунаправленного стрима
        if (isBidirectional) {
          // Открываем входящий поток и преобразуем его к типу Request
          Stream<Request> typedIncomingStream;
          typedIncomingStream = _core
              .openStream(
            serviceName: serviceName,
            methodName: methodName,
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

          // Создаем исходящий поток через обработчик
          final outgoingStream = implementation.openBidirectionalStream();

          // Подписываемся на исходящий поток и отправляем данные
          outgoingStream.listen(
            (data) {
              _core.sendStreamData(
                streamId: effectiveStreamId,
                data: data is RpcMessage ? data.toJson() : data,
                serviceName: serviceName,
                methodName: methodName,
              );
            },
            onError: (error) {
              _core.sendStreamError(
                streamId: effectiveStreamId,
                errorMessage: error.toString(),
              );
            },
            onDone: () {
              _core.closeStream(
                streamId: effectiveStreamId,
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
