part of '../_index.dart';

/// Сообщение транспортного уровня с поддержкой Stream ID.
///
/// Представляет различные типы сообщений, которые могут передаваться
/// через транспортный уровень, включая метаданные и полезную нагрузку.
/// Каждое сообщение привязано к конкретному HTTP/2 stream (RPC вызову).
final class RpcTransportMessage {
  /// Полезная нагрузка сообщения (данные)
  final Uint8List? payload;

  /// Связанные метаданные
  final RpcMetadata? metadata;

  /// Флаг, указывающий, что это последнее сообщение в потоке
  final bool isEndOfStream;

  /// Путь метода в формате /<ServiceName>/<MethodName>
  final String? methodPath;

  /// Уникальный идентификатор HTTP/2 stream для этого RPC вызова
  final int streamId;

  /// Флаг, указывающий, что сообщение содержит только метаданные
  bool get isMetadataOnly => metadata != null && payload == null;

  /// Создает сообщение транспортного уровня
  RpcTransportMessage({
    this.payload,
    this.metadata,
    this.isEndOfStream = false,
    this.methodPath,
    required this.streamId,
  });
}

/// Абстрактный интерфейс транспортного уровня с поддержкой мультиплексирования по Stream ID.
///
/// Определяет контракт для транспортных реализаций различных протоколов
/// (HTTP/2, WebSockets, изоляты и др.). Поддерживает мультиплексирование
/// по уникальным Stream ID согласно спецификации gRPC.
abstract class IRpcTransport {
  /// Создает новый HTTP/2 stream для RPC вызова.
  ///
  /// Возвращает уникальный Stream ID, который будет использоваться
  /// для всех сообщений этого RPC вызова.
  int createStream();

  /// Отправляет метаданные для конкретного stream.
  ///
  /// [streamId] Уникальный идентификатор HTTP/2 stream
  /// [metadata] Метаданные для отправки
  /// [endStream] Флаг завершения потока данных
  Future<void> sendMetadata(
    int streamId,
    RpcMetadata metadata, {
    bool endStream = false,
  });

  /// Отправляет сообщение для конкретного stream.
  ///
  /// [streamId] Уникальный идентификатор HTTP/2 stream
  /// [data] Байты для отправки
  /// [endStream] Флаг завершения потока данных
  Future<void> sendMessage(
    int streamId,
    Uint8List data, {
    bool endStream = false,
  });

  /// Поток всех входящих сообщений от удаленной стороны.
  ///
  /// Объединяет входящие метаданные и данные в единый поток RpcTransportMessage.
  /// Каждый элемент потока содержит информацию о Stream ID для маршрутизации.
  Stream<RpcTransportMessage> get incomingMessages;

  /// Создает отфильтрованный поток сообщений для конкретного stream.
  ///
  /// [streamId] Уникальный идентификатор HTTP/2 stream
  /// Возвращает поток сообщений только для указанного stream
  Stream<RpcTransportMessage> getMessagesForStream(int streamId) {
    return incomingMessages.where((message) => message.streamId == streamId);
  }

  /// Завершает отправку данных для конкретного stream.
  ///
  /// [streamId] Уникальный идентификатор HTTP/2 stream
  Future<void> finishSending(int streamId);

  /// Закрывает транспортное соединение.
  ///
  /// Освобождает все связанные ресурсы и закрывает базовое соединение.
  Future<void> close();
}
