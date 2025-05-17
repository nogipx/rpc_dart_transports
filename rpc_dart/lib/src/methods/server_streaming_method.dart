// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "серверный стриминг" (один запрос - поток ответов)
final class ServerStreamingRpcMethod<
        MessageType extends IRpcSerializableMessage>
    extends RpcMethod<MessageType> {
  /// Создает новый объект серверного стриминг RPC метода
  ServerStreamingRpcMethod(
    IRpcEndpoint<MessageType> endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName) {
    // Создаем логгер с консистентным именем
    _logger = RpcLogger('$serviceName.$methodName.server_stream');
  }

  /// Открывает поток данных от сервера
  ///
  ///
  /// [request] - запрос для открытия потока
  /// [metadata] - метаданные (опционально)
  /// [streamId] - ID потока (опционально, генерируется автоматически)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  ServerStreamingBidiStream<Request, Response>
      call<Request extends MessageType, Response extends MessageType>({
    required Request request,
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('server_stream');

    // Создаем базовый стрим с передачей запроса
    final responseStream = _core
        .openStream(
      serviceName: serviceName,
      methodName: methodName,
      request: request, // Теперь передаем запрос сразу при открытии потока
      metadata: metadata,
      streamId: effectiveStreamId,
    )
        .map((data) {
      if (data is Map<String, dynamic>) {
        return responseParser(data);
      }
      return data as Response;
    });

    // Создаем BidiStream
    final bidiStream = BidiStream<Request, Response>(
      responseStream: responseStream,
      sendFunction: (actualRequest) {
        // Преобразуем запрос в JSON, если это RpcMessage
        final processedRequest = actualRequest is RpcMessage
            ? actualRequest.toJson()
            : actualRequest;

        // Отправляем запрос в стрим
        _core.sendStreamData(
          streamId: effectiveStreamId,
          data: processedRequest,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      closeFunction: () async {
        // Закрываем стрим со стороны клиента
        _core.closeStream(
          streamId: effectiveStreamId,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
    );

    // Оборачиваем в ServerStreamingBidiStream и сразу возвращаем,
    // больше не нужно вызывать sendRequest, так как запрос уже отправлен
    return ServerStreamingBidiStream<Request, Response>(
      stream: bidiStream,
      sendFunction: bidiStream.send,
      closeFunction: bidiStream.close,
    );
  }

  /// Регистрирует обработчик серверного стриминг метода
  ///
  /// [handler] - функция обработки запроса, возвращающая поток ответов
  /// [requestParser] - функция преобразования JSON в объект запроса (опционально)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  void register<Request extends MessageType, Response extends MessageType>({
    required RpcMethodServerStreamHandler<Request, Response> handler,
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
      serviceContract.addServerStreamingMethod<Request, Response>(
        methodName: methodName,
        handler: handler,
        argumentParser: requestParser,
        responseParser: responseParser,
      );
    }

    // Получаем актуальный контракт метода
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.serverStreaming);
    final implementation =
        RpcMethodImplementation.serverStreaming(contract, handler);

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
      handler: (RpcMethodContext context) async {
        try {
          // Конвертируем запрос в типизированный, если нужно
          final typedRequest = (context.payload is Map<String, dynamic>)
              ? requestParser(context.payload)
              : context.payload;

          // Получаем ID сообщения из контекста
          final messageId = context.messageId;

          // Запускаем обработку стрима в фоновом режиме
          _activateStreamHandler<Request, Response>(
            messageId,
            typedRequest,
            implementation,
            responseParser,
          );

          // Возвращаем только подтверждение принятия запроса
          return {'status': 'streaming'};
        } catch (e) {
          rethrow;
        }
      },
    );
  }

  /// Активирует обработчик стрима и связывает его с транспортом
  void _activateStreamHandler<Request extends IRpcSerializableMessage,
      Response extends IRpcSerializableMessage>(
    String messageId,
    Request request,
    RpcMethodImplementation<Request, Response> implementation,
    RpcMethodResponseParser<Response> responseParser,
  ) {
    // Запускаем стрим от обработчика
    final serverStreamBidi = implementation.openServerStreaming(request);

    // Подписываемся на события и пересылаем их через публичный API Endpoint
    serverStreamBidi.listen((data) {
      // Преобразуем данные и отправляем их в поток
      final processedData = data is RpcMessage ? data.toJson() : data;

      _core.sendStreamData(
        streamId: messageId,
        data: processedData,
        serviceName: serviceName,
        methodName: methodName,
      );
    }, onError: (error) {
      // Отправляем ошибку
      _logger.error(
        'Ошибка в серверном стриме: $error',
        error: {'error': error.toString()},
      );

      _core.sendStreamError(
        streamId: messageId,
        errorMessage: error.toString(),
        serviceName: serviceName,
        methodName: methodName,
      );
    }, onDone: () {
      _logger.debug(
        'Серверный стрим завершен',
      );

      // Закрываем стрим с указанием serviceName и methodName для middleware
      _core.closeStream(
        streamId: messageId,
        serviceName: serviceName,
        methodName: methodName,
      );
    });
  }
}
