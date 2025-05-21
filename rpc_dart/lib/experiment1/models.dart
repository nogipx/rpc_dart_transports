part of '_index.dart';

/// Представляет отдельный HTTP/2 заголовок.
///
/// HTTP/2 передает заголовки в бинарном виде через HPACK-сжатие, но
/// на уровне API они представлены в виде пар "имя-значение".
/// Специальные заголовки в HTTP/2 начинаются с двоеточия (например, :path).
class Header {
  /// Имя заголовка
  final String name;

  /// Значение заголовка
  final String value;

  /// Создает заголовок с указанным именем и значением
  const Header(this.name, this.value);
}

/// Метаданные запроса или ответа (набор HTTP/2 заголовков).
///
/// В gRPC метаданные передаются через HTTP/2 заголовки и трейлеры.
/// Этот класс обеспечивает удобный доступ к ним и содержит
/// фабричные методы для создания стандартных наборов заголовков.
class Metadata {
  /// Список заголовков, составляющих метаданные
  final List<Header> headers;

  /// Создает метаданные из списка заголовков
  Metadata(this.headers);

  /// Создает метаданные для клиентского запроса.
  ///
  /// Формирует необходимые HTTP/2 заголовки для инициализации gRPC вызова.
  /// [serviceName] Имя сервиса (например, "ChatService")
  /// [methodName] Имя метода (например, "Send")
  /// [host] Хост-заголовок (опционально)
  /// Возвращает метаданные, готовые для отправки при инициализации запроса.
  static Metadata forClientRequest(String serviceName, String methodName,
      {String host = ''}) {
    return Metadata([
      Header(':method', 'POST'),
      Header(':path', '/$serviceName/$methodName'),
      Header(':scheme', 'http'),
      Header(':authority', host),
      Header(
          GrpcConstants.CONTENT_TYPE_HEADER, GrpcConstants.GRPC_CONTENT_TYPE),
      Header('te', 'trailers'),
    ]);
  }

  /// Создает начальные метаданные для ответа сервера.
  ///
  /// Формирует HTTP/2 заголовки, которые сервер отправляет клиенту
  /// при получении запроса, до отправки каких-либо данных.
  /// Возвращает метаданные, готовые для отправки в начале ответа.
  static Metadata forServerInitialResponse() {
    return Metadata([
      Header(':status', '200'),
      Header(
          GrpcConstants.CONTENT_TYPE_HEADER, GrpcConstants.GRPC_CONTENT_TYPE),
    ]);
  }

  /// Создает метаданные для финального трейлера.
  ///
  /// Формирует заголовки-трейлеры, которые отправляются в конце потока
  /// и содержат статус выполнения операции gRPC.
  /// [statusCode] Код завершения gRPC (см. GrpcStatus)
  /// [message] Дополнительное сообщение (обычно при ошибке)
  /// Возвращает метаданные-трейлеры для завершения потока.
  static Metadata forTrailer(int statusCode, {String message = ''}) {
    final headers = [
      Header(GrpcConstants.GRPC_STATUS_HEADER, statusCode.toString()),
    ];

    if (message.isNotEmpty) {
      headers.add(Header(GrpcConstants.GRPC_MESSAGE_HEADER, message));
    }

    return Metadata(headers);
  }

  /// Находит значение заголовка по его имени.
  ///
  /// [name] Имя искомого заголовка
  /// Возвращает значение заголовка или null, если заголовок не найден.
  String? getHeaderValue(String name) {
    for (var header in headers) {
      if (header.name == name) {
        return header.value;
      }
    }
    return null;
  }
}

/// Обертка для gRPC сообщения с его метаданными.
///
/// Объединяет данные (payload) и метаданные (headers) в единый объект,
/// что позволяет обрабатывать разные типы данных в потоке сообщений:
/// - Сообщения с полезной нагрузкой
/// - Сообщения только с метаданными (например, трейлеры)
/// - Информацию о завершении потока
class GrpcMessage<T> {
  /// Полезная нагрузка сообщения (данные)
  final T? payload;

  /// Связанные метаданные (заголовки или трейлеры)
  final Metadata? metadata;

  /// Флаг, указывающий, что сообщение содержит только метаданные
  final bool isMetadataOnly;

  /// Флаг, указывающий, что это последнее сообщение в потоке
  final bool isEndOfStream;

  /// Создает сообщение с указанными параметрами
  GrpcMessage({
    this.payload,
    this.metadata,
    this.isMetadataOnly = false,
    this.isEndOfStream = false,
  });

  /// Создает сообщение только с полезной нагрузкой (данными).
  ///
  /// Удобный фабричный метод для создания обычных сообщений с данными.
  /// [payload] Полезная нагрузка для передачи
  /// Возвращает сообщение, содержащее только данные.
  static GrpcMessage<T> withPayload<T>(T payload) {
    return GrpcMessage<T>(payload: payload);
  }

  /// Создает сообщение только с метаданными (заголовками или трейлерами).
  ///
  /// Удобный фабричный метод для создания сообщений с метаданными.
  /// [metadata] Метаданные для передачи
  /// [isEndOfStream] Флаг конца потока (для трейлеров)
  /// Возвращает сообщение, содержащее только метаданные.
  static GrpcMessage<T> withMetadata<T>(Metadata metadata,
      {bool isEndOfStream = false}) {
    return GrpcMessage<T>(
      metadata: metadata,
      isMetadataOnly: true,
      isEndOfStream: isEndOfStream,
    );
  }
}

/// Утилитарный класс для работы с форматом сообщений gRPC.
///
/// Обеспечивает упаковку и распаковку сообщений в соответствии
/// со стандартом gRPC - добавление 5-байтного префикса к сериализованным данным
/// и извлечение информации из этого префикса.
///
/// Формат префикса:
/// - 1-й байт: флаг сжатия (0 или 1)
/// - 2-5-й байты: длина сообщения (uint32, big-endian)
class GrpcMessageFrame {
  /// Упаковывает сообщение в формат gRPC с 5-байтным префиксом.
  ///
  /// Добавляет к сериализованному сообщению стандартный 5-байтный префикс,
  /// содержащий информацию о сжатии и длине сообщения.
  ///
  /// [messageBytes] Байты сериализованного сообщения
  /// [compressed] Флаг, указывающий, сжато ли сообщение
  /// Возвращает полностью упакованное сообщение с префиксом
  static Uint8List encode(Uint8List messageBytes, {bool compressed = false}) {
    final result = List<int>.filled(
        GrpcConstants.MESSAGE_PREFIX_SIZE + messageBytes.length, 0);

    // Устанавливаем флаг сжатия
    result[GrpcConstants.COMPRESSION_FLAG_INDEX] =
        compressed ? GrpcConstants.COMPRESSED : GrpcConstants.NO_COMPRESSION;

    // Устанавливаем длину сообщения (big-endian)
    final length = messageBytes.length;
    result[GrpcConstants.MESSAGE_LENGTH_INDEX] = (length >> 24) & 0xFF;
    result[GrpcConstants.MESSAGE_LENGTH_INDEX + 1] = (length >> 16) & 0xFF;
    result[GrpcConstants.MESSAGE_LENGTH_INDEX + 2] = (length >> 8) & 0xFF;
    result[GrpcConstants.MESSAGE_LENGTH_INDEX + 3] = length & 0xFF;

    // Копируем данные сообщения
    for (int i = 0; i < messageBytes.length; i++) {
      result[GrpcConstants.MESSAGE_PREFIX_SIZE + i] = messageBytes[i];
    }

    return Uint8List.fromList(result);
  }

  /// Парсит заголовок сообщения, извлекая информацию о сжатии и длине.
  ///
  /// Анализирует 5-байтный префикс сообщения gRPC и извлекает
  /// информацию о сжатии и длине полезной нагрузки.
  ///
  /// [headerBytes] Байты, содержащие префикс сообщения (должно быть >= 5 байт)
  /// Возвращает структуру с информацией о сжатии и длине сообщения
  /// Выбрасывает Exception при неверной длине входных данных
  static MessageHeader parseHeader(Uint8List headerBytes) {
    if (headerBytes.length < GrpcConstants.MESSAGE_PREFIX_SIZE) {
      throw Exception('Неверная длина заголовка сообщения');
    }

    final isCompressed = headerBytes[GrpcConstants.COMPRESSION_FLAG_INDEX] ==
        GrpcConstants.COMPRESSED;

    final length = (headerBytes[GrpcConstants.MESSAGE_LENGTH_INDEX] << 24) |
        (headerBytes[GrpcConstants.MESSAGE_LENGTH_INDEX + 1] << 16) |
        (headerBytes[GrpcConstants.MESSAGE_LENGTH_INDEX + 2] << 8) |
        headerBytes[GrpcConstants.MESSAGE_LENGTH_INDEX + 3];

    return MessageHeader(isCompressed, length);
  }
}

/// Информация, извлеченная из 5-байтного префикса сообщения gRPC.
///
/// Хранит данные о сжатии и длине сообщения, полученные при
/// парсинге префикса сообщения.
class MessageHeader {
  /// Флаг, указывающий, сжато ли сообщение
  final bool isCompressed;

  /// Длина полезной нагрузки сообщения в байтах
  final int messageLength;

  /// Создает объект с информацией о заголовке сообщения
  MessageHeader(this.isCompressed, this.messageLength);
}
