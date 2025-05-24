part of '_index.dart';

/// Базовый контракт сервиса (полностью дженериковый)
/// Пользователи могут передавать любые свои типы без ограничений!
abstract class RpcServiceContract {
  final String serviceName;
  final Map<String, RpcMethodRegistration> _methods = {};

  RpcServiceContract(this.serviceName);

  /// Декларативная регистрация методов (как в setup())
  void setup() {
    // Переопределяется в наследниках
  }

  /// Регистрирует унарный метод
  /// TRequest и TResponse должны реализовывать IRpcSerializableMessage!
  void addUnaryMethod<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required String methodName,
    required Future<TResponse> Function(TRequest) handler,
    String description = '',
    RpcSerializationFormat? serializationFormat,
  }) {
    _methods[methodName] = RpcMethodRegistration(
      name: methodName,
      type: RpcMethodType.unary,
      handler: handler,
      description: description,
      requestType: TRequest,
      responseType: TResponse,
      serializationFormat: serializationFormat ?? RpcSerializationFormat.json,
    );
  }

  /// Регистрирует серверный стрим
  /// TRequest и TResponse должны реализовывать IRpcSerializableMessage!
  void addServerStreamMethod<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required String methodName,
    required Stream<TResponse> Function(TRequest) handler,
    String description = '',
    RpcSerializationFormat? serializationFormat,
  }) {
    _methods[methodName] = RpcMethodRegistration(
      name: methodName,
      type: RpcMethodType.serverStream,
      handler: handler,
      description: description,
      requestType: TRequest,
      responseType: TResponse,
      serializationFormat: serializationFormat ?? RpcSerializationFormat.json,
    );
  }

  /// Регистрирует клиентский стрим
  /// TRequest и TResponse должны реализовывать IRpcSerializableMessage!
  void addClientStreamMethod<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required String methodName,
    required Future<TResponse> Function(Stream<TRequest>) handler,
    String description = '',
    RpcSerializationFormat? serializationFormat,
  }) {
    _methods[methodName] = RpcMethodRegistration(
      name: methodName,
      type: RpcMethodType.clientStream,
      handler: handler,
      description: description,
      requestType: TRequest,
      responseType: TResponse,
      serializationFormat: serializationFormat ?? RpcSerializationFormat.json,
    );
  }

  /// Регистрирует двунаправленный стрим
  /// TRequest и TResponse должны реализовывать IRpcSerializableMessage!
  void addBidirectionalMethod<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required String methodName,
    required Stream<TResponse> Function(Stream<TRequest>) handler,
    String description = '',
    RpcSerializationFormat? serializationFormat,
  }) {
    _methods[methodName] = RpcMethodRegistration(
      name: methodName,
      type: RpcMethodType.bidirectional,
      handler: handler,
      description: description,
      requestType: TRequest,
      responseType: TResponse,
      serializationFormat: serializationFormat ?? RpcSerializationFormat.json,
    );
  }

  /// Получает зарегистрированные методы
  Map<String, RpcMethodRegistration> get methods => Map.unmodifiable(_methods);
}
