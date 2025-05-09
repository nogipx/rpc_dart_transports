import 'dart:async';
import 'dart:math';
import 'package:rpc_dart/rpc_dart.dart';

part '_method_implementation.dart';
part 'bidirectional_method.dart';
part 'client_streaming_method.dart';
part 'server_streaming_method.dart';
part 'unary_method.dart';

/// Базовый абстрактный класс для всех типов RPC методов
abstract base class RpcMethod<T extends RpcSerializableMessage> {
  /// Endpoint, с которым связан метод
  final RpcEndpoint<T> _endpoint;

  /// Название сервиса
  final String serviceName;

  /// Название метода
  final String methodName;

  /// Создает новый объект RPC метода
  RpcMethod(this._endpoint, this.serviceName, this.methodName);

  /// Генерирует уникальный идентификатор
  String generateUniqueId([String? prefix]) {
    final random = Random();
    return '${prefix != null ? '${prefix}_' : ''}${DateTime.now().toUtc().toIso8601String()}_${random.nextInt(1000000)}';
  }

  /// Получает контракт метода
  RpcMethodContract<Request, Response>
      getMethodContract<Request extends T, Response extends T>(
    RpcMethodType type,
  ) {
    // Получаем контракт сервиса
    final contract = _endpoint.getServiceContract(serviceName);
    if (contract == null) {
      throw Exception('Контракт сервиса $serviceName не найден');
    }

    // Ищем контракт метода
    final methodContract =
        contract.findMethodTyped<Request, Response>(methodName);
    if (methodContract == null) {
      // Если метод не найден, создаем временный контракт на основе параметров
      return RpcMethodContract<Request, Response>(
        methodName: methodName,
        methodType: type,
      );
    }

    return methodContract;
  }

  /// Доступ к endpoint'у (для наследников)
  RpcEndpoint<T> get endpoint => _endpoint;
}
