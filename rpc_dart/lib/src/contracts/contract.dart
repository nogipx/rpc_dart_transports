part of '_index.dart';

/// Базовый интерфейс для всех контрактов
abstract interface class IRpcContract {
  /// Имя сервиса
  String get serviceName;
}

/// Серверный контракт сервиса
/// Регистрирует и обрабатывает методы
abstract class RpcResponderContract implements IRpcContract {
  @override
  final String serviceName;
  final Map<String, RpcMethodRegistration> _methods = {};

  RpcResponderContract(this.serviceName);

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
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    String description = '',
  }) {
    _methods[methodName] = RpcMethodRegistration<TRequest, TResponse>(
      name: methodName,
      type: RpcMethodType.unaryRequest,
      handler: handler,
      description: description,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );
  }

  /// Регистрирует серверный стрим
  /// TRequest и TResponse должны реализовывать IRpcSerializable!
  void addServerStreamMethod<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required String methodName,
    required Stream<TResponse> Function(TRequest) handler,
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    String description = '',
  }) {
    _methods[methodName] = RpcMethodRegistration<TRequest, TResponse>(
      name: methodName,
      type: RpcMethodType.serverStream,
      handler: handler,
      description: description,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );
  }

  /// Регистрирует клиентский стрим
  /// TRequest и TResponse должны реализовывать IRpcSerializable!
  void addClientStreamMethod<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required String methodName,
    required Future<TResponse> Function(Stream<TRequest>) handler,
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    String description = '',
  }) {
    _methods[methodName] = RpcMethodRegistration<TRequest, TResponse>(
      name: methodName,
      type: RpcMethodType.clientStream,
      handler: handler,
      description: description,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );
  }

  /// Регистрирует двунаправленный стрим
  /// TRequest и TResponse должны реализовывать IRpcSerializable!
  void addBidirectionalMethod<TRequest extends IRpcSerializable,
      TResponse extends IRpcSerializable>({
    required String methodName,
    required Stream<TResponse> Function(Stream<TRequest>) handler,
    required IRpcCodec<TRequest> requestCodec,
    required IRpcCodec<TResponse> responseCodec,
    String description = '',
  }) {
    _methods[methodName] = RpcMethodRegistration<TRequest, TResponse>(
      name: methodName,
      type: RpcMethodType.bidirectionalStream,
      handler: handler,
      description: description,
      requestCodec: requestCodec,
      responseCodec: responseCodec,
    );
  }

  /// Получает зарегистрированные методы
  Map<String, RpcMethodRegistration> get methods => Map.unmodifiable(_methods);
}

/// Клиентский контракт сервиса
/// Только вызывает методы, не регистрирует их
abstract class RpcCallerContract implements IRpcContract {
  @override
  final String serviceName;
  final RpcCallerEndpoint _endpoint;

  RpcCallerContract(this.serviceName, this._endpoint);

  /// Получает endpoint, используемый для отправки запросов
  RpcCallerEndpoint get endpoint => _endpoint;
}
