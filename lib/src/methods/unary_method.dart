// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_method.dart';

/// Класс для работы с унарным RPC методом (один запрос - один ответ)
final class UnaryRpcMethod<T extends IRpcSerializableMessage>
    extends RpcMethod<T> {
  /// Создает новый объект унарного RPC метода
  UnaryRpcMethod(
    IRpcEndpoint<T> endpoint,
    String serviceName,
    String methodName,
  ) : super(endpoint, serviceName, methodName);

  /// Вызывает унарный метод и возвращает результат
  ///
  /// [request] - запрос
  /// [metadata] - метаданные (опционально)
  /// [timeout] - таймаут (опционально)
  /// [responseParser] - функция преобразования JSON в объект ответа (опционально)
  Future<Response> call<Request extends T, Response extends T>({
    required Request request,
    required Response Function(Map<String, dynamic>) responseParser,
    Map<String, dynamic>? metadata,
    Duration? timeout,
  }) async {
    final result = await _core.invoke(
      serviceName,
      methodName,
      request is RpcMessage ? request.toJson() : request,
      metadata: metadata,
      timeout: timeout,
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
    required Future<Response> Function(Request) handler,
    required Request Function(Map<String, dynamic>) requestParser,
    required Response Function(Map<String, dynamic>) responseParser,
  }) {
    final contract = getMethodContract<Request, Response>(RpcMethodType.unary);
    final implementation = RpcMethodImplementation.unary(contract, handler);

    _registrar.registerMethodImplementation(
        serviceName, methodName, implementation);

    _registrar.registerMethod(
      serviceName,
      methodName,
      (RpcMethodContext context) async {
        try {
          // Если request - это Map и мы получили функцию fromJson, преобразуем объект
          final typedRequest = (context.payload is Map<String, dynamic>)
              ? requestParser(context.payload)
              : context.payload;

          // Получаем типизированный ответ от обработчика
          final response = await implementation.invoke(typedRequest);

          // Преобразуем ответ в формат для передачи (JSON для RpcMessage)
          final result = response is RpcMessage ? response.toJson() : response;

          return result;
        } catch (e) {
          rethrow;
        }
      },
    );
  }
}
