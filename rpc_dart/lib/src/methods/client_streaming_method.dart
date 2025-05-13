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
  /// Возвращает объект ClientStreamingBidiStream для отправки данных и получения результата
  ClientStreamingBidiStream<Request, Response>
      call<Request extends T, Response extends T>({
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    String? streamId,
  }) {
    // Генерируем уникальный ID потока, если не предоставлен
    final effectiveStreamId =
        streamId ?? _endpoint.generateUniqueId('client_stream');

    // Комплитер для ожидания финального ответа
    final completer = Completer<Response>();

    // Флаг, указывающий, был ли уже завершен поток
    var streamCompleted = false;
    var dataTransferFinished = false;

    // Открываем базовый стрим для получения ответов
    final responseStream = _core
        .openStream(
      serviceName: serviceName,
      methodName: methodName,
      metadata: metadata,
      streamId: effectiveStreamId,
    )
        .map((data) {
      // Преобразуем данные через responseParser
      return responseParser(data);
    });

    // Подготавливаем переменную для хранения подписки
    StreamSubscription<Response>? subscription;

    // Подписываемся на ответы и завершаем комплитер при получении результата
    subscription = responseStream.listen(
      (data) {
        // Логируем получение ответа
        rpcMethodLogger.info(
          'ClientStreamingRpcMethod: получен ответ в потоке для $methodName (stream: $effectiveStreamId)',
        );

        // Финальный ответ приходит как последнее сообщение стрима
        if (!completer.isCompleted && !streamCompleted) {
          streamCompleted = true;
          completer.complete(data);
          // Отписываемся от потока, чтобы избежать утечки памяти
          subscription?.cancel();
          subscription = null;
        }
      },
      onError: (error) {
        rpcMethodLogger.error(
            'ClientStreamingRpcMethod: ошибка в потоке $methodName (stream: $effectiveStreamId)',
            error);
        if (!completer.isCompleted && !streamCompleted) {
          streamCompleted = true;
          completer.completeError(error);
          // Отписываемся от потока в случае ошибки
          subscription?.cancel();
          subscription = null;
        }
      },
      onDone: () {
        rpcMethodLogger.debug(
          'ClientStreamingRpcMethod: поток $methodName завершен (stream: $effectiveStreamId)',
        );
        // Если поток завершился без ответа, обрабатываем это
        if (!completer.isCompleted && !streamCompleted) {
          streamCompleted = true;
          completer.completeError('Стрим завершился без ответа');
          subscription?.cancel();
          subscription = null;
        }
      },
    );

    // Создаем BidiStream с функцией отправки данных и функциями завершения/закрытия потока
    final bidiStream = BidiStream<Request, Response>(
      responseStream: responseStream,
      sendFunction: (data) {
        if (streamCompleted || dataTransferFinished) {
          rpcMethodLogger.warning(
            'ClientStreamingRpcMethod: попытка отправки в закрытый или завершенный поток $methodName (stream: $effectiveStreamId)',
          );
          throw StateError(
              'Невозможно отправить данные: поток закрыт или передача данных завершена');
        }

        final processedData = data is RpcMessage ? data.toJson() : data;

        _core.sendStreamData(
          streamId: effectiveStreamId,
          data: processedData,
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      // Функция для завершения передачи данных (отправка маркера завершения)
      finishTransferFunction: () async {
        if (streamCompleted || dataTransferFinished) {
          rpcMethodLogger.warning(
            'ClientStreamingRpcMethod: попытка завершить уже завершенный поток $methodName (stream: $effectiveStreamId)',
          );
          return;
        }

        rpcMethodLogger.debug(
          'ClientStreamingRpcMethod: завершение передачи данных для $methodName (stream: $effectiveStreamId)',
        );

        // Отмечаем, что передача данных завершена
        dataTransferFinished = true;

        // Когда поток запросов закончен, отправляем маркер завершения
        // Включаем как старый _clientStreamEnd, так и новый _finishTransfer маркер
        // для обратной совместимости
        _core.sendStreamData(
          streamId: effectiveStreamId,
          data: {'_clientStreamEnd': true, '_finishTransfer': true},
          serviceName: serviceName,
          methodName: methodName,
        );
      },
      // Функция для полного закрытия потока
      closeFunction: () async {
        if (streamCompleted) {
          rpcMethodLogger.debug(
            'ClientStreamingRpcMethod: попытка закрыть уже закрытый поток $methodName (stream: $effectiveStreamId)',
          );
          return;
        }

        // Если передача данных еще не завершена, завершаем её
        if (!dataTransferFinished) {
          rpcMethodLogger.info(
            'ClientStreamingRpcMethod: автоматическое завершение передачи при закрытии $methodName (stream: $effectiveStreamId)',
          );

          // Отправляем маркер завершения, если ещё не отправлен
          _core.sendStreamData(
            streamId: effectiveStreamId,
            data: {'_clientStreamEnd': true, '_finishTransfer': true},
            serviceName: serviceName,
            methodName: methodName,
          );

          dataTransferFinished = true;
        }

        rpcMethodLogger.debug(
          'ClientStreamingRpcMethod: закрытие потока $methodName (stream: $effectiveStreamId)',
        );

        // Закрываем клиентскую часть стрима
        _core.closeStream(
          streamId: effectiveStreamId,
          serviceName: serviceName,
          methodName: methodName,
        );

        // Отмечаем стрим как завершенный
        streamCompleted = true;

        // Отменяем подписку при закрытии потока
        await subscription?.cancel();
        subscription = null;
      },
    );

    return ClientStreamingBidiStream<Request, Response>(bidiStream);
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
        RpcMethodImplementation.clientStreaming(contract, handler);

    // Регистрируем реализацию метода
    _registrar.registerMethodImplementation(
      serviceName: serviceName,
      methodName: methodName,
      implementation: implementation,
    );

    print(
        'ClientStreamingRpcMethod: регистрация метода $serviceName.$methodName');
    print('Реализация: $implementation');

    // Регистрируем низкоуровневый обработчик - это ключевой шаг для обеспечения
    // связи между контрактом и обработчиком вызова
    _registrar.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      handler: (RpcMethodContext context) async {
        print('Вызов метода $serviceName.$methodName');

        // Получаем ID сообщения из контекста
        final messageId = context.messageId;

        // Будем собирать здесь все запросы до маркера завершения
        final requests = <Request>[];
        var isEndMarkerReceived = false;
        var hasError = false;
        String? errorMessage;

        // Открываем входящий поток
        final incomingStream = _core.openStream(
          serviceName: serviceName,
          methodName: methodName,
          streamId: messageId,
        );

        // Ждем все запросы из потока
        await for (final data in incomingStream) {
          // Проверяем маркер конца клиентского стрима
          if (data is Map<String, dynamic> &&
              (data['_clientStreamEnd'] == true ||
                  data['_finishTransfer'] == true)) {
            if (data['_clientStreamEnd'] == true &&
                data['_finishTransfer'] == true) {
              print(
                  'Получен полный маркер завершения клиентского стрима (включает _clientStreamEnd и _finishTransfer)');
            } else if (data['_clientStreamEnd'] == true) {
              print(
                  'Получен устаревший маркер завершения клиентского стрима (_clientStreamEnd)');
            } else if (data['_finishTransfer'] == true) {
              print(
                  'Получен маркер завершения передачи данных (_finishTransfer)');
            }
            isEndMarkerReceived = true;
            break;
          }

          try {
            // Проверяем, является ли это ответом, а не запросом
            bool looksLikeResponseData = false;

            // Проверяем структуру данных - есть ли у нас поля, характерные для ответа
            if (data is Map<String, dynamic>) {
              // Проверяем наличие полей, которые обычно присутствуют в ответах и отсутствуют в запросах
              // Это эвристика - в реальной системе это может зависеть от конкретных типов данных
              if (data.containsKey('status') &&
                  (data.containsKey('totalSize') ||
                      data.containsKey('totalChunks')) &&
                  !data.containsKey('isLastChunk')) {
                looksLikeResponseData = true;
                print('Пропускаем данные, похожие на ответ: $data');
                continue;
              }
            }

            // Если это не похоже на ответ, пробуем распарсить как запрос
            if (!looksLikeResponseData) {
              final parsedData = requestParser(data);
              requests.add(parsedData);
              print('Добавлен запрос ${requests.length}');
            }
          } catch (e, stack) {
            print('Ошибка при парсинге запроса: $e');
            print('Стек вызовов: $stack');
            errorMessage = e.toString();
            hasError = true;
            break;
          }
        }

        // Если есть ошибка, отправляем её клиенту
        if (hasError) {
          print('Произошла ошибка при обработке запросов: $errorMessage');
          _core.sendStreamError(
            streamId: messageId,
            errorMessage:
                errorMessage ?? 'Неизвестная ошибка при обработке запросов',
            serviceName: serviceName,
            methodName: methodName,
          );
          _core.closeStream(
            streamId: messageId,
            serviceName: serviceName,
            methodName: methodName,
          );
          throw Exception(errorMessage);
        }

        // Проверяем, что мы получили маркер завершения
        if (!isEndMarkerReceived) {
          print(
              'Предупреждение: Стрим запросов закрылся без маркера завершения. '
              'Это может вызвать проблемы с синхронизацией клиента и сервера.');
          // Здесь мы решаем продолжить, так как поток мог быть закрыт
          // и без явного маркера завершения - устаревшее поведение
        }

        try {
          // Получаем ClientStreamingBidiStream от обработчика
          final serviceBidiStream = handler();

          print('Отправляем ${requests.length} запросов в обработчик');
          // Отправляем все запросы в обработчик
          for (final request in requests) {
            serviceBidiStream.send(request);
          }

          // Завершаем отправку и ожидаем ответ
          await serviceBidiStream.finishSending();

          // Ждем результат
          final response = await serviceBidiStream.getResponse().timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Превышено время ожидания ответа от обработчика',
              );
            },
          );
          print('Получен ответ от обработчика: $response');

          // Отправляем ответ клиенту
          final result = response.toJson();
          print('Отправляем результат клиенту: $result');

          _core.sendStreamData(
            streamId: messageId,
            data: result,
            serviceName: serviceName,
            methodName: methodName,
          );

          // Полностью закрываем поток и ресурсы
          await serviceBidiStream.close();

          // Закрываем серверную часть потока
          _core.closeStream(
            streamId: messageId,
            serviceName: serviceName,
            methodName: methodName,
          );

          return {'status': 'streaming'};
        } catch (e, stack) {
          // В случае ошибки в обработчике
          print('Ошибка при обработке клиентского стрима: $e');
          print('Стек вызовов: $stack');

          _core.sendStreamError(
            streamId: messageId,
            errorMessage: e.toString(),
            serviceName: serviceName,
            methodName: methodName,
          );

          _core.closeStream(
            streamId: messageId,
            serviceName: serviceName,
            methodName: methodName,
          );

          rethrow;
        }
      },
    );

    print(
        'ClientStreamingRpcMethod: метод $serviceName.$methodName успешно зарегистрирован');
  }
}
