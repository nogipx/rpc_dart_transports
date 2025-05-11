// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "серверный стриминг" (один запрос - поток ответов)
final class ServerStreamingRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект серверного стриминг RPC метода
  ServerStreamingRpcMethod(
    IRpcEndpoint<T> endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName);

  /// Открывает поток данных от сервера
  ///
  /// [request] - запрос для открытия потока
  /// [metadata] - метаданные (опционально)
  /// [streamId] - ID потока (опционально, генерируется автоматически)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  Stream<Response> call<Request extends T, Response extends T>({
    required Request request,
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('server_stream');
    final dynamicRequest = request is RpcMessage ? request.toJson() : request;

    final stream = _core.openStream(
      serviceName: serviceName,
      methodName: methodName,
      request: dynamicRequest,
      metadata: metadata,
      streamId: effectiveStreamId,
    );

    return stream.map((data) {
      if (data is Map<String, dynamic>) {
        return responseParser(data);
      }
      return data as Response;
    });
  }

  /// Регистрирует обработчик серверного стриминг метода
  ///
  /// [handler] - функция обработки запроса, возвращающая поток ответов
  /// [requestParser] - функция преобразования JSON в объект запроса (опционально)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  void register<Request extends T, Response extends T>({
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
    final stream = implementation.openStream(request);

    // Подписываемся на события и пересылаем их через публичный API Endpoint
    stream.listen((data) {
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
      _core.sendStreamError(
        streamId: messageId,
        errorMessage: error.toString(),
      );
    }, onDone: () {
      // Закрываем стрим с указанием serviceName и methodName для middleware
      _core.closeStream(
        streamId: messageId,
        serviceName: serviceName,
        methodName: methodName,
      );
    });
  }
}
