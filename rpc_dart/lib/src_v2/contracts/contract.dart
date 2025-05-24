part of '_index.dart';

/// Базовый интерфейс для всех контрактов
abstract interface class IRpcContract {
  /// Имя сервиса
  String get serviceName;
}

/// Серверный контракт сервиса
/// Регистрирует и обрабатывает методы
abstract class RpcServerContract implements IRpcContract {
  @override
  final String serviceName;
  final Map<String, RpcMethodRegistration> _methods = {};

  RpcServerContract(this.serviceName);

  /// Декларативная регистрация методов
  void setup() {
    // Переопределяется в наследниках
  }

  /// Регистрирует унарный метод
  /// TRequest и TResponse должны реализовывать IRpcSerializable!
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
  /// TRequest и TResponse должны реализовывать IRpcSerializable!
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
  /// TRequest и TResponse должны реализовывать IRpcSerializable!
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
  /// TRequest и TResponse должны реализовывать IRpcSerializable!
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

/// Клиентский контракт сервиса
/// Только вызывает методы, не регистрирует их
abstract class RpcClientContract implements IRpcContract {
  @override
  final String serviceName;
  final RpcClientEndpoint _endpoint;

  RpcClientContract(this.serviceName, this._endpoint);

  /// Получает endpoint, используемый для отправки запросов
  RpcClientEndpoint get endpoint => _endpoint;
}
