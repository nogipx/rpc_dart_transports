/// Контекст вызова метода
///
/// Содержит информацию о вызове метода, включая ID сообщения,
/// метаданные и полезную нагрузку
final class RpcMethodContext {
  /// Уникальный идентификатор сообщения
  final String messageId;

  /// Метаданные сообщения
  final Map<String, dynamic>? metadata;

  /// Полезная нагрузка (тело запроса)
  final dynamic payload;

  /// Имя сервиса
  final String? serviceName;

  /// Имя метода
  final String? methodName;

  /// Создает новый контекст вызова метода
  const RpcMethodContext({
    required this.messageId,
    this.metadata,
    required this.payload,
    this.serviceName,
    this.methodName,
  });

  /// Создает строковое представление контекста
  @override
  String toString() => 'MethodContext(messageId: $messageId, '
      'serviceName: $serviceName, methodName: $methodName)';
}
