import '_index.dart' show RpcMethodContract;

/// Базовый интерфейс для всех сервисных контрактов
abstract interface class RpcServiceContract<T> {
  const RpcServiceContract();

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
