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

  /// Находит метод по имени
  ///
  /// Возвращает контракт метода или null, если метод не найден
  ///
  /// ПРИМЕЧАНИЕ: Для безопасной типизации метода используйте метод
  /// [getMethodHandler], [getMethodArgumentParser] и [getMethodResponseParser]
  /// вместо прямого приведения типов.
  RpcMethodContract<Request, Response>?
      findMethod<Request extends T, Response extends T>(
    String methodName,
  );

  /// Получает обработчик для метода с конкретными типами
  ///
  /// [methodName] - имя метода
  /// Возвращает типизированный обработчик или null, если метод не найден или не соответствует типам
  dynamic getMethodHandler<Request extends T, Response extends T>(
    String methodName,
  );

  /// Получает функцию парсинга аргументов для метода с конкретными типами
  ///
  /// [methodName] - имя метода
  /// Возвращает типизированную функцию парсинга или null, если метод не найден или не соответствует типам
  RpcMethodArgumentParser<Request>? getMethodArgumentParser<Request extends T>(
    String methodName,
  );

  /// Получает функцию парсинга ответов для метода с конкретными типами
  ///
  /// [methodName] - имя метода
  /// Возвращает типизированную функцию парсинга или null, если метод не найден или не соответствует типам
  RpcMethodResponseParser<Response>?
      getMethodResponseParser<Response extends T>(
    String methodName,
  );

  /// Метод для регистрации методов в контракте.
  /// Необходимо переопределить в классе-наследнике.
  void setup();

  /// Добавляет унарный метод в контракт
  void addUnaryRequestMethod<Request extends T, Response extends T>({
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

  /// Дополнительные метаданные метода
  final Map<String, dynamic>? metadata;

  /// Конструктор
  const RpcMethodContract({
    required this.methodName,
    required this.methodType,
    this.metadata,
  });

  /// Проверяет, что объект соответствует типу запроса
  bool validateRequest(dynamic request) {
    // Если объект null, проверяем является ли тип nullable
    if (request == null) {
      return false; // Не разрешаем null
    }

    // Проверка типа в рантайме
    return request is Request;
  }

  /// Проверяет, что объект соответствует типу ответа
  bool validateResponse(dynamic response) {
    // Если объект null, проверяем является ли тип nullable
    if (response == null) {
      return false; // Не разрешаем null
    }

    // Проверка типа в рантайме
    return response is Response;
  }

  @override
  String toString() =>
      'MethodContract<$Request, $Response>($methodName, $methodType)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RpcMethodContract &&
        other.methodName == methodName &&
        other.methodType == methodType;
  }

  @override
  int get hashCode => methodName.hashCode ^ methodType.hashCode;
}
