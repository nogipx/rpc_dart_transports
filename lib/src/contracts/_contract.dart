// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

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
abstract interface class RpcSerializableMessage {
  /// Преобразует сообщение в JSON
  Map<String, dynamic> toJson();
}

/// Базовый интерфейс для всех сервисных контрактов
abstract interface class IRpcServiceContract<T extends RpcSerializableMessage> {
  const IRpcServiceContract();

  /// Уникальное имя сервиса
  String get serviceName;

  /// Список всех доступных методов
  List<RpcMethodContract<T, T>> get methods;

  /// Находит метод по имени и типу
  RpcMethodContract<Request, Response>?
      findMethodTyped<Request extends T, Response extends T>(String methodName);

  dynamic getHandler(RpcMethodContract<T, T> method);

  dynamic getArgumentParser(RpcMethodContract<T, T> method);

  dynamic getResponseParser(RpcMethodContract<T, T> method);
}

/// Контракт метода сервиса
final class RpcMethodContract<Request extends RpcSerializableMessage,
    Response extends RpcSerializableMessage> {
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
