part of '_index.dart';

/// Основной интерфейс для всех RPC сообщений - ОБЯЗАТЕЛЬНЫЙ!
/// Все типы запросов и ответов должны реализовывать этот интерфейс
abstract interface class IRpcSerializable {
  Uint8List serialize();
}

/// Типы RPC методов
enum RpcMethodType {
  unary,
  serverStream,
  clientStream,
  bidirectional,
}

/// Регистрация метода в контракте
class RpcMethodRegistration {
  final String name;
  final RpcMethodType type;
  final Function handler;
  final String description;
  final Type requestType;
  final Type responseType;

  const RpcMethodRegistration({
    required this.name,
    required this.type,
    required this.handler,
    required this.description,
    required this.requestType,
    required this.responseType,
  });
}

/// Исключение для RpcEndpoint
class RpcException implements Exception {
  final String message;

  RpcException(this.message);

  @override
  String toString() => 'RpcException: $message';
}

/// Интерфейс для middleware
abstract class IRpcMiddleware {
  Future<dynamic> processRequest(
    String serviceName,
    String methodName,
    dynamic request,
  );

  Future<dynamic> processResponse(
    String serviceName,
    String methodName,
    dynamic response,
  );
}
