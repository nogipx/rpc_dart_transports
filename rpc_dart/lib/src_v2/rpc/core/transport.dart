part of '../_index.dart';

/// Интерфейс для кодирования и декодирования сообщений.
///
/// Позволяет абстрагироваться от конкретного формата сериализации (JSON, Protocol Buffers,
/// MessagePack и др.). Реализации должны обеспечивать корректное преобразование объектов
/// в байты и обратно.
abstract class IRpcSerializer<T> {
  /// Сериализует объект типа T в последовательность байтов.
  ///
  /// [message] Объект для сериализации.
  /// Возвращает байтовое представление объекта.
  Uint8List serialize(T message);

  /// Десериализует последовательность байтов в объект типа T.
  ///
  /// [bytes] Байты для десериализации.
  /// Возвращает объект, воссозданный из байтов.
  T deserialize(Uint8List bytes);
}

/// Сообщение транспортного уровня с поддержкой Stream ID.
///
/// Представляет различные типы сообщений, которые могут передаваться
/// через транспортный уровень, включая метаданные и полезную нагрузку.
/// Каждое сообщение привязано к конкретному HTTP/2 stream (RPC вызову).
final class RpcTransportMessage<T> {
  /// Полезная нагрузка сообщения (данные)
  final T? payload;

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
  Stream<RpcTransportMessage<Uint8List>> get incomingMessages;

  /// Создает отфильтрованный поток сообщений для конкретного stream.
  ///
  /// [streamId] Уникальный идентификатор HTTP/2 stream
  /// Возвращает поток сообщений только для указанного stream
  Stream<RpcTransportMessage<Uint8List>> getMessagesForStream(int streamId) {
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

/// Базовый класс для создания мультиплексирующих транспортов по Stream ID.
///
/// Обеспечивает стандартную логику маршрутизации сообщений по Stream ID
/// и может быть расширен конкретными реализациями транспортов.
abstract class RpcMultiplexingTransport implements IRpcTransport {
  /// Контроллер для маршрутизации входящих сообщений по stream
  final StreamController<RpcTransportMessage<Uint8List>> _incomingController =
      StreamController<RpcTransportMessage<Uint8List>>.broadcast();

  /// Счетчик для генерации уникальных Stream ID
  int _nextStreamId = 1;

  /// Активные streams и их состояния
  final Map<int, bool> _activeStreams = <int, bool>{};

  @override
  Stream<RpcTransportMessage<Uint8List>> get incomingMessages =>
      _incomingController.stream;

  @override
  int createStream() {
    final streamId = _nextStreamId;
    _nextStreamId +=
        2; // HTTP/2: клиент использует нечетные ID, сервер - четные
    _activeStreams[streamId] = true;
    return streamId;
  }

  /// Добавляет входящее сообщение в поток с указанием Stream ID
  ///
  /// [message] Сообщение для добавления
  /// [streamId] Уникальный идентификатор HTTP/2 stream
  void addIncomingMessage(
      RpcTransportMessage<Uint8List> message, int streamId) {
    if (!_incomingController.isClosed) {
      final messageWithStreamId = RpcTransportMessage<Uint8List>(
        payload: message.payload,
        metadata: message.metadata,
        isEndOfStream: message.isEndOfStream,
        methodPath: message.methodPath,
        streamId: streamId,
      );
      _incomingController.add(messageWithStreamId);
    }
  }

  /// Проверяет, активен ли stream
  bool isStreamActive(int streamId) {
    return _activeStreams.containsKey(streamId);
  }

  /// Закрывает конкретный stream
  void closeStream(int streamId) {
    _activeStreams.remove(streamId);
  }

  @override
  Future<void> close() async {
    _activeStreams.clear();
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
  }
}
