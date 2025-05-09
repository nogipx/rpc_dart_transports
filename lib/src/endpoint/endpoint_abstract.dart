part of '_index.dart';

/// Абстрактный базовый класс для RPC-конечных точек
///
/// Этот класс определяет общий публичный интерфейс для всех RPC-конечных точек.
/// Для типизированной реализации используйте [RpcEndpoint].
abstract interface class _RpcEndpoint<T extends RpcSerializableMessage> {
  /// Транспорт для отправки/получения сообщений
  RpcTransport get transport;

  /// Сериализатор для преобразования сообщений
  RpcSerializer get serializer;

  /// Добавляет middleware для обработки запросов и ответов
  void addMiddleware(RpcMiddleware middleware);

  /// Регистрирует обработчик метода
  void registerMethod(
    String serviceName,
    String methodName,
    Future<dynamic> Function(RpcMethodContext) handler,
  );

  /// Вызывает удаленный метод и возвращает результат
  Future<dynamic> invoke(
    String serviceName,
    String methodName,
    dynamic request, {
    Duration? timeout,
    Map<String, dynamic>? metadata,
  });

  /// Открывает поток данных от удаленной стороны
  Stream<dynamic> openStream(
    String serviceName,
    String methodName, {
    dynamic request,
    Map<String, dynamic>? metadata,
    String? streamId,
  });

  /// Отправляет данные в поток
  Future<void> sendStreamData(
    String streamId,
    dynamic data, {
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });

  /// Отправляет сигнал об ошибке в поток
  Future<void> sendStreamError(
    String streamId,
    String error, {
    Map<String, dynamic>? metadata,
  });

  /// Закрывает поток
  Future<void> closeStream(
    String streamId, {
    Map<String, dynamic>? metadata,
    String? serviceName,
    String? methodName,
  });

  /// Создает объект унарного метода для указанного сервиса и метода
  UnaryRpcMethod<T> unary(
    String serviceName,
    String methodName,
  );

  /// Создает объект серверного стриминг метода для указанного сервиса и метода
  ServerStreamingRpcMethod<T> serverStreaming(
    String serviceName,
    String methodName,
  );

  /// Создает объект клиентского стриминг метода для указанного сервиса и метода
  ClientStreamingRpcMethod<T> clientStreaming(
    String serviceName,
    String methodName,
  );

  /// Создает объект двунаправленного стриминг метода для указанного сервиса и метода
  BidirectionalRpcMethod<T> bidirectional(
    String serviceName,
    String methodName,
  );

  /// Проверяет, активна ли конечная точка
  bool get isActive;

  /// Закрывает конечную точку
  Future<void> close();
}
