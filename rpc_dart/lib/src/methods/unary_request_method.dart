// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с унарным RPC методом (один запрос - один ответ)
final class UnaryRequestRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект унарного RPC метода
  UnaryRequestRpcMethod(
    IRpcEndpoint<T> endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName) {
    // Создаем логгер с консистентным именем
    _logger = RpcLogger('$serviceName.$methodName.unary');
  }

  /// Вызывает унарный метод и возвращает результат
  ///
  /// [request] - запрос
  /// [metadata] - метаданные (опционально)
  /// [timeout] - таймаут (опционально)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  Future<Response> call<Request extends T, Response extends T>({
    required Request request,
    required RpcMethodResponseParser<Response> responseParser,
    Map<String, dynamic>? metadata,
    Duration? timeout,
  }) async {
    _logger.debug(
      'Вызов унарного метода $serviceName.$methodName',
    );

    final result = await _core.invoke(
      serviceName: serviceName,
      methodName: methodName,
      request: request is RpcMessage ? request.toJson() : request,
      metadata: metadata,
      timeout: timeout,
    );

    _logger.debug(
      'Получен ответ от метода $serviceName.$methodName',
    );

    // Если результат - Map<String, dynamic> и предоставлен парсер, используем его
    if (result is Map<String, dynamic>) {
      return responseParser(result);
    }

    // Иначе возвращаем результат как есть
    return result as Response;
  }

  /// Регистрирует обработчик унарного метода
  ///
  /// [handler] - функция обработки запроса
  /// [requestParser] - функция преобразования JSON в объект запроса (опционально)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  void register<Request extends T, Response extends T>({
    required RpcMethodUnaryHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> requestParser,
    required RpcMethodResponseParser<Response> responseParser,
  }) {
    // Получаем контракт сервиса
    final serviceContract = _endpoint.getServiceContract(serviceName);
    if (serviceContract == null) {
      _logger.error(
        'Контракт сервиса $serviceName не найден при регистрации метода $methodName',
      );
      throw Exception(
          'Контракт сервиса $serviceName не найден. Необходимо сначала зарегистрировать контракт сервиса.');
    }

    // Проверяем, существует ли метод в контракте
    final existingMethod =
        serviceContract.findMethod<Request, Response>(methodName);

    // Если метод не найден в контракте, добавляем его
    if (existingMethod == null) {
      _logger.debug(
        'Добавление метода $methodName в контракт сервиса $serviceName',
      );
      serviceContract.addUnaryRequestMethod<Request, Response>(
        methodName: methodName,
        handler: handler,
        argumentParser: requestParser,
        responseParser: responseParser,
      );
    }

    // Получаем актуальный контракт метода
    final contract = getMethodContract<Request, Response>(RpcMethodType.unary);
    final implementation = RpcMethodImplementation.unary(contract, handler);

    // Регистрируем реализацию метода
    _registrar.registerMethodImplementation(
      serviceName: serviceName,
      methodName: methodName,
      implementation: implementation,
    );

    _logger.debug(
      'Зарегистрирован унарный метод $serviceName.$methodName',
    );

    // Регистрируем низкоуровневый обработчик - это ключевой шаг для обеспечения
    // связи между контрактом и обработчиком вызова
    _registrar.registerMethod(
      serviceName: serviceName,
      methodName: methodName,
      handler: (RpcMethodContext context) async {
        try {
          _logger.debug(
            'Обработка запроса для метода $serviceName.$methodName',
          );

          // Если request - это Map и мы получили функцию fromJson, преобразуем объект
          final typedRequest = (context.payload is Map<String, dynamic>)
              ? requestParser(context.payload)
              : context.payload;

          // Получаем типизированный ответ от обработчика
          final response = await implementation.makeUnaryRequest(typedRequest);

          _logger.debug(
            'Получен ответ от обработчика для метода $serviceName.$methodName',
          );

          // Преобразуем ответ в формат для передачи (JSON для RpcMessage)
          final result = response is RpcMessage ? response.toJson() : response;

          return result;
        } catch (e, stack) {
          _logger.error(
            'Ошибка при обработке унарного метода $serviceName.$methodName: $e',
            error: {'error': e.toString()},
            stackTrace: stack,
          );
          rethrow;
        }
      },
    );
  }
}
