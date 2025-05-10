// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'typedefs.dart';

/// Типы методов в контракте
enum RpcMethodType {
  /// Обычный RPC-метод (запрос-ответ)
  unary,

  /// Метод, возвращающий поток данных
  serverStreaming,

  /// Метод с потоком запросов
  clientStreaming,

  /// Двунаправленный поток
  bidirectional,

  /// Метод-заглушка
  stub,
}

/// Интерфейс для типизированных сообщений
abstract interface class IRpcSerializableMessage {
  /// Преобразует сообщение в JSON
  Map<String, dynamic> toJson();
}

/// Базовый интерфейс для всех сервисных контрактов
abstract interface class IRpcServiceContract<
    T extends IRpcSerializableMessage> {
  const IRpcServiceContract();

  /// Уникальное имя сервиса
  String get serviceName;

  /// Список всех доступных методов
  List<RpcMethodContract<T, T>> get methods;

  /// Находит метод по имени и типу
  RpcMethodContract<Request, Response>?
      findMethodTyped<Request extends T, Response extends T>(String methodName);

  /// Метод для регистрации методов в контракте.
  /// Необходимо переопределить в классе-наследнике.
  void setup();

  dynamic getHandler(RpcMethodContract<T, T> method);

  dynamic getArgumentParser(RpcMethodContract<T, T> method);

  dynamic getResponseParser(RpcMethodContract<T, T> method);

  /// Добавляет унарный метод в контракт
  void addUnaryMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodUnaryHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  });

  /// Добавляет серверный стриминговый метод в контракт
  void addServerStreamingMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodServerStreamHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  });

  /// Добавляет клиентский стриминговый метод в контракт
  void addClientStreamingMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodClientStreamHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  });

  /// Добавляет двунаправленный стриминговый метод в контракт
  void addBidirectionalStreamingMethod<Request extends T, Response extends T>({
    required String methodName,
    required RpcMethodBidirectionalHandler<Request, Response> handler,
    required RpcMethodArgumentParser<Request> argumentParser,
    required RpcMethodResponseParser<Response> responseParser,
  });
}

/// Контракт метода сервиса
final class RpcMethodContract<Request extends IRpcSerializableMessage,
    Response extends IRpcSerializableMessage> {
  /// Имя метода
  final String methodName;

  /// Тип метода
  final RpcMethodType methodType;

  /// Конструктор
  const RpcMethodContract({
    required this.methodName,
    required this.methodType,
  });

  /// Проверяет, что объект соответствует типу запроса
  bool validateRequest(dynamic request) {
    // Если generic-тип Request является dynamic, то все валидно
    if (identical(Request, dynamic)) return true;

    // Проверка типа в рантайме
    return request is Request;
  }

  /// Проверяет, что объект соответствует типу ответа
  bool validateResponse(dynamic response) {
    // Если generic-тип Response является dynamic, то все валидно
    if (identical(Response, dynamic)) return true;

    // Проверка типа в рантайме
    return response is Response;
  }

  @override
  String toString() =>
      'MethodContract<$Request, $Response>($methodName, $methodType)';
}
