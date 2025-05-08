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

/// Контракт метода сервиса
final class RpcMethodContract<Request, Response> {
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
