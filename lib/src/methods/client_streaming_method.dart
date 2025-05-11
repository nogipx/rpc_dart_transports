// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с RPC методом типа "клиентский стриминг" (поток запросов - один ответ)
final class ClientStreamingRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект клиентского стриминг RPC метода
  ClientStreamingRpcMethod(
    IRpcEndpoint<T> endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName);

  /// Открывает поток для отправки данных на сервер
  ///
  /// [metadata] - метаданные (опционально)
  /// [streamId] - ID потока (опционально, генерируется автоматически)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  ///
  /// Возвращает тюпл из потока для отправки и Future для получения результата
  RpcClientStreamResult<Request, Response>
      openClientStream<Request extends T, Response extends T>({
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    final effectiveStreamId =
        streamId ?? RpcMethod.generateUniqueId('client_stream');

    // Создаем контроллер для отправки данных
    final controller = StreamController<Request>();

    // Комплитер для ожидания финального ответа
    final completer = Completer<Response>();

    // Открываем базовый стрим
    _core
        .openStream(
      serviceName,
      methodName,
      metadata: metadata,
      streamId: effectiveStreamId,
    )
        .listen(
      (data) {
        // Финальный ответ приходит как последнее сообщение стрима
        if (!completer.isCompleted) {
          final result = responseParser(data);
          completer.complete(result);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    // Подписываемся на контроллер и отправляем данные
    controller.stream.listen(
      (data) {
        final processedData = data is RpcMessage ? data.toJson() : data;

        _core.sendStreamData(
          effectiveStreamId,
          processedData,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      onDone: () {
        // Когда поток запросов закончен, отправляем маркер завершения
        _core.sendStreamData(
          effectiveStreamId,
          {'_clientStreamEnd': true},
          serviceName: serviceName,
          methodName: methodName,
        );

        // Закрываем клиентскую часть стрима
        _core.closeStream(
          effectiveStreamId,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
    );

    return RpcClientStreamResult<Request, Response>(
      controller: controller,
      response: completer.future,
    );
  }

  /// Регистрирует обработчик клиентского стриминг метода
  ///
  /// [handler] - функция обработки потока запросов, возвращающая один ответ
  /// [requestParser] - функция преобразования JSON в объект запроса (опционально)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  void register<Request extends T, Response extends T>({
    required RpcMethodClientStreamHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> requestParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    // Получаем контракт сервиса
    final serviceContract = _endpoint.getServiceContract(serviceName);
    if (serviceContract == null) {
      throw RpcCustomException(
        customMessage:
            'Контракт сервиса $serviceName не найден. Необходимо сначала зарегистрировать контракт сервиса.',
        debugLabel: 'ClientStreamingRpcMethod',
      );
    }

    // Проверяем, существует ли метод в контракте
    final existingMethod =
        serviceContract.findMethod<Request, Response>(methodName);

    // Если метод не найден в контракте, добавляем его
    if (existingMethod == null) {
      serviceContract.addClientStreamingMethod<Request, Response>(
        methodName: methodName,
        handler: handler,
        argumentParser: requestParser,
        responseParser: responseParser,
      );
    }

    // Получаем актуальный контракт метода
    final contract =
        getMethodContract<Request, Response>(RpcMethodType.clientStreaming);
    final implementation =
        RpcMethodImplementation.clientStream(contract, handler);

    // Регистрируем реализацию метода
    _registrar.registerMethodImplementation(
        serviceName, methodName, implementation);

    // Регистрируем низкоуровневый обработчик - это ключевой шаг для обеспечения
    // связи между контрактом и обработчиком вызова
    _registrar.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        // Получаем ID сообщения из контекста
        final messageId = context.messageId;

        // Создаем контроллер для входящих запросов
        final controller = StreamController<Request>();

        // Открываем входящий поток и преобразуем его к типу Request
        final incomingStream = _core.openStream(
          serviceName,
          methodName,
          streamId: messageId,
        );

        // Подписываемся на входящий поток
        incomingStream.listen(
          (data) {
            // Проверяем маркер конца клиентского стрима
            if (data is Map<String, dynamic> &&
                data['_clientStreamEnd'] == true) {
              // Получили маркер завершения, закрываем контроллер
              controller.close();
              return;
            }

            final parsedData = requestParser(data);
            controller.add(parsedData);
          },
          onError: (error) {
            controller.addError(error);
          },
          onDone: () {
            // Поток закрыт, закрываем контроллер
            if (!controller.isClosed) {
              controller.close();
            }
          },
        );

        try {
          // Вызываем обработчик с потоком запросов
          final response = await implementation.handleClientStream(
            RpcClientStreamParams<Request, Response>(
              stream: controller.stream,
              metadata: context.metadata,
              streamId: messageId,
            ),
          );

          // Преобразуем результат и отправляем как последнее сообщение стрима
          final result = response.toJson();

          _core.sendStreamData(
            messageId,
            result,
            serviceName: serviceName,
            methodName: methodName,
          );

          // Закрываем стрим
          _core.closeStream(
            messageId,
            serviceName: serviceName,
            methodName: methodName,
          );

          // Возвращаем подтверждение, что стрим обрабатывается
          return {'status': 'streaming'};
        } catch (e) {
          // В случае ошибки, отправляем её и закрываем стрим
          _core.sendStreamError(messageId, e.toString());
          _core.closeStream(messageId);
          rethrow;
        }
      },
    );
  }
}
