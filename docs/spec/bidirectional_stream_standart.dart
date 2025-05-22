// ignore_for_file: constant_identifier_names

import 'dart:async';

/// # Реализация двунаправленного стрима gRPC
///
/// Данная спецификация описывает полную и независимую от технологий реализацию
/// двунаправленного стриминга (Bidirectional Streaming) в gRPC.
///
/// ## Общий принцип работы
///
/// Двунаправленный стрим позволяет клиенту и серверу обмениваться потоками сообщений
/// независимо друг от друга, где каждая сторона может отправлять сообщения в произвольном
/// порядке и времени. Это достигается через следующие компоненты:
///
/// 1. HTTP/2 соединение с мультиплексированием потоков
/// 2. Стандартизированный формат сообщений с 5-байтным префиксом
/// 3. Асинхронные потоки для чтения/записи в обоих направлениях
/// 4. Правильная обработка заголовков и трейлеров (метаданных)
///
/// Для полного описания см. файл bidirectional_stream_docs.dart

/// Интерфейс для кодирования и декодирования сообщений.
///
/// Позволяет абстрагироваться от конкретного формата сериализации (JSON, Protocol Buffers,
/// MessagePack и др.). Реализации должны обеспечивать корректное преобразование объектов
/// в байты и обратно.
abstract class MessageCodec<T> {
  /// Сериализует объект типа T в последовательность байтов.
  ///
  /// [message] Объект для сериализации.
  /// Возвращает байтовое представление объекта.
  List<int> serialize(T message);

  /// Десериализует последовательность байтов в объект типа T.
  ///
  /// [bytes] Байты для десериализации.
  /// Возвращает объект, воссозданный из байтов.
  T deserialize(List<int> bytes);
}

/// Константы протокола gRPC.
///
/// Содержит все фиксированные значения, используемые в протоколе gRPC,
/// что обеспечивает единообразие и устраняет "магические числа" в коде.
class GrpcConstants {
  /// Размер префикса сообщения в байтах (1 байт флаг + 4 байта длина)
  static const int MESSAGE_PREFIX_SIZE = 5;

  /// Позиция флага сжатия в префиксе
  static const int COMPRESSION_FLAG_INDEX = 0;

  /// Позиция начала поля длины сообщения в префиксе
  static const int MESSAGE_LENGTH_INDEX = 1;

  /// Если сообщение не сжато, используется это значение
  static const int NO_COMPRESSION = 0;

  /// Если сообщение сжато, используется это значение
  static const int COMPRESSED = 1;

  /// HTTP заголовок, содержащий статус gRPC
  static const String GRPC_STATUS_HEADER = 'grpc-status';

  /// HTTP заголовок, содержащий сообщение об ошибке
  static const String GRPC_MESSAGE_HEADER = 'grpc-message';

  /// HTTP заголовок для типа контента
  static const String CONTENT_TYPE_HEADER = 'content-type';

  /// Тип контента для gRPC
  static const String GRPC_CONTENT_TYPE = 'application/grpc';
}

/// Стандартные коды состояний gRPC.
///
/// Определяет все возможные статусы завершения операций gRPC.
/// Ключевые статусы:
/// - OK (0): успешное выполнение
/// - CANCELLED (1): операция была отменена
/// - DEADLINE_EXCEEDED (4): превышено время ожидания
/// - INTERNAL (13): внутренняя ошибка сервера
/// - UNAVAILABLE (14): сервис недоступен
class GrpcStatus {
  /// Успешное выполнение
  static const int OK = 0;

  /// Операция отменена
  static const int CANCELLED = 1;

  /// Неизвестная ошибка
  static const int UNKNOWN = 2;

  /// Неверный аргумент
  static const int INVALID_ARGUMENT = 3;

  /// Превышено время ожидания
  static const int DEADLINE_EXCEEDED = 4;

  /// Ресурс не найден
  static const int NOT_FOUND = 5;

  /// Ресурс уже существует
  static const int ALREADY_EXISTS = 6;

  /// Отказано в доступе
  static const int PERMISSION_DENIED = 7;

  /// Ресурс исчерпан
  static const int RESOURCE_EXHAUSTED = 8;

  /// Предусловие не выполнено
  static const int FAILED_PRECONDITION = 9;

  /// Операция прервана
  static const int ABORTED = 10;

  /// Выход за пределы диапазона
  static const int OUT_OF_RANGE = 11;

  /// Не реализовано
  static const int UNIMPLEMENTED = 12;

  /// Внутренняя ошибка
  static const int INTERNAL = 13;

  /// Сервис недоступен
  static const int UNAVAILABLE = 14;

  /// Потеря данных
  static const int DATA_LOSS = 15;

  /// Не аутентифицирован
  static const int UNAUTHENTICATED = 16;
}

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
  static List<int> encode(List<int> messageBytes, {bool compressed = false}) {
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

    return result;
  }

  /// Парсит заголовок сообщения, извлекая информацию о сжатии и длине.
  ///
  /// Анализирует 5-байтный префикс сообщения gRPC и извлекает
  /// информацию о сжатии и длине полезной нагрузки.
  ///
  /// [headerBytes] Байты, содержащие префикс сообщения (должно быть >= 5 байт)
  /// Возвращает структуру с информацией о сжатии и длине сообщения
  /// Выбрасывает Exception при неверной длине входных данных
  static MessageHeader parseHeader(List<int> headerBytes) {
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

/// Состояние процесса парсинга входящих данных потока gRPC.
///
/// Управляет буферизацией и состоянием парсинга при обработке
/// фрагментированных сообщений gRPC. Сообщения могут приходить
/// по частям или несколько сообщений в одном фрагменте.
class MessageParserState {
  /// Текущий накопительный буфер данных
  List<int> buffer = [];

  /// Ожидаемая длина текущего сообщения (null, если заголовок еще не прочитан)
  int? expectedMessageLength;

  /// Флаг сжатия для текущего обрабатываемого сообщения
  bool isCompressed = false;

  /// Сбрасывает состояние для обработки следующего сообщения.
  ///
  /// Вызывается после успешного извлечения полного сообщения
  /// для подготовки к обработке следующего.
  void reset() {
    expectedMessageLength = null;
    isCompressed = false;
  }
}

/// Абстрактный интерфейс транспортного уровня для HTTP/2.
///
/// Определяет контракт для взаимодействия с HTTP/2 соединением.
/// Конкретные реализации должны работать с выбранной HTTP/2 библиотекой
/// и обеспечивать отправку/получение заголовков и данных через
/// мультиплексированные потоки HTTP/2.
///
/// Этот интерфейс абстрагирует детали HTTP/2 от бизнес-логики gRPC.
abstract class Http2Transport {
  /// Отправляет заголовки HTTP/2 HEADERS.
  ///
  /// Используется для отправки:
  /// - Начальных заголовков запроса (клиент)
  /// - Начальных заголовков ответа (сервер)
  /// - Трейлеров (финальные метаданные)
  ///
  /// [headers] Метаданные для отправки в виде заголовков
  /// [endStream] Флаг завершения потока (для трейлеров обычно true)
  void sendHeaders(Metadata headers, {bool endStream = false});

  /// Отправляет данные через HTTP/2 DATA фрейм.
  ///
  /// Используется для передачи сообщений, упакованных с 5-байтным префиксом.
  /// При достижении лимита размера фрейма HTTP/2, сообщение может быть
  /// разделено на несколько DATA фреймов автоматически.
  ///
  /// [data] Байты для отправки
  /// [endStream] Флаг завершения потока (обычно false для сообщений)
  void sendData(List<int> data, {bool endStream = false});

  /// Поток входящих сообщений от удаленной стороны.
  ///
  /// Объединяет входящие HEADERS и DATA фреймы в единый поток GrpcMessage.
  /// Каждый элемент потока может быть:
  /// - Сообщение с данными (DATA фрейм)
  /// - Сообщение с метаданными (HEADERS фрейм)
  /// - Сообщение с флагом завершения (END_STREAM)
  Stream<GrpcMessage<List<int>>> get incomingMessages;

  /// Завершает отправку данных, устанавливая END_STREAM.
  ///
  /// Используется для сигнализации о завершении отправки сообщений.
  /// После вызова этого метода нельзя отправлять новые сообщения.
  void finishSending();

  /// Закрывает транспортное соединение.
  ///
  /// Освобождает все связанные ресурсы и закрывает базовое
  /// HTTP/2 соединение, если это уместно.
  void close();

  /// Фабричный метод для создания нового клиентского транспорта.
  ///
  /// Устанавливает HTTP/2 соединение с указанным хостом и портом.
  /// Возвращает готовый к использованию транспорт.
  ///
  /// [host] Хост для подключения
  /// [port] Порт для подключения
  /// [useTls] Использовать ли TLS (HTTPS)
  /// Выбрасывает UnimplementedError, т.к. это абстрактный метод
  static Http2Transport connect(String host, int port, {bool useTls = false}) {
    throw UnimplementedError(
        'Это абстрактный метод, который должен быть реализован в конкретной имплементации');
  }
}

/// Парсер для обработки фрагментированных сообщений gRPC.
///
/// Отвечает за правильную сборку полных сообщений из фрагментированных
/// потоков данных, поступающих через HTTP/2 DATA фреймы. Решает проблему
/// несовпадения границ HTTP/2 фреймов и сообщений gRPC.
class GrpcMessageParser {
  /// Внутреннее состояние парсера
  final MessageParserState _state = MessageParserState();

  /// Обрабатывает входящий фрагмент данных и извлекает полные сообщения.
  ///
  /// Накапливает входящие данные в буфере и извлекает из него полные сообщения,
  /// используя информацию о длине из 5-байтного префикса. Может извлечь
  /// несколько сообщений из одного фрагмента или продолжить накопление
  /// для получения полного сообщения.
  ///
  /// [data] Новый фрагмент входящих данных
  /// Возвращает список полных сообщений, извлеченных из данных
  List<List<int>> processIncomingData(List<int> data) {
    final result = <List<int>>[];

    // Добавляем данные в буфер
    _state.buffer.addAll(data);

    // Обрабатываем буфер, пока можем извлекать сообщения
    while (_state.buffer.length >= GrpcConstants.MESSAGE_PREFIX_SIZE) {
      // Если мы еще не знаем длину сообщения, извлекаем ее из заголовка
      if (_state.expectedMessageLength == null) {
        final header = GrpcMessageFrame.parseHeader(_state.buffer);
        _state.isCompressed = header.isCompressed;
        _state.expectedMessageLength = header.messageLength;

        // Удаляем заголовок из буфера
        _state.buffer =
            _state.buffer.sublist(GrpcConstants.MESSAGE_PREFIX_SIZE);
      }

      // Если у нас достаточно данных для полного сообщения
      if (_state.buffer.length >= _state.expectedMessageLength!) {
        // Извлекаем сообщение
        final messageBytes =
            _state.buffer.sublist(0, _state.expectedMessageLength!);
        result.add(messageBytes);

        // Обновляем буфер, удаляя обработанное сообщение
        _state.buffer = _state.buffer.sublist(_state.expectedMessageLength!);

        // Сбрасываем состояние для следующего сообщения
        _state.reset();
      } else {
        // Недостаточно данных для полного сообщения, нужно ждать
        break;
      }
    }

    return result;
  }
}

/// Клиентская реализация двунаправленного стрима gRPC.
///
/// Обеспечивает полную реализацию клиентской стороны двунаправленного
/// стриминга (Bidirectional Streaming RPC). Позволяет клиенту отправлять
/// поток запросов серверу и одновременно получать поток ответов.
///
/// Особенности:
/// - Асинхронный обмен сообщениями в обоих направлениях
/// - Потоковый интерфейс для отправки и получения (через Stream)
/// - Автоматическая сериализация/десериализация сообщений
/// - Корректная обработка заголовков и трейлеров gRPC
class BidirectionalStreamClient<TRequest, TResponse> {
  /// Базовый HTTP/2 транспорт для обмена данными
  final Http2Transport _transport;

  /// Кодек для сериализации исходящих запросов
  final MessageCodec<TRequest> _requestCodec;

  /// Кодек для десериализации входящих ответов
  final MessageCodec<TResponse> _responseCodec;

  /// Контроллер потока исходящих запросов
  final StreamController<TRequest> _requestController =
      StreamController<TRequest>();

  /// Контроллер потока входящих ответов
  final StreamController<GrpcMessage<TResponse>> _responseController =
      StreamController<GrpcMessage<TResponse>>();

  /// Парсер для обработки фрагментированных сообщений
  final GrpcMessageParser _parser = GrpcMessageParser();

  /// Поток для отправки запросов (для внутреннего использования)
  Stream<TRequest> get requestStream => _requestController.stream;

  /// Поток входящих ответов от сервера.
  ///
  /// Предоставляет доступ к потоку ответов, получаемых от сервера.
  /// Каждый элемент может быть:
  /// - Сообщение с полезной нагрузкой (payload)
  /// - Сообщение с метаданными (metadata)
  ///
  /// Поток завершается при получении трейлера с END_STREAM
  /// или при возникновении ошибки.
  Stream<GrpcMessage<TResponse>> get responses => _responseController.stream;

  /// Создает новый клиентский двунаправленный стрим.
  ///
  /// [_transport] Транспортный уровень HTTP/2
  /// [_requestCodec] Кодек для сериализации запросов
  /// [_responseCodec] Кодек для десериализации ответов
  BidirectionalStreamClient(
      this._transport, this._requestCodec, this._responseCodec) {
    _setupStreams();
  }

  /// Настраивает потоки данных между приложением и транспортом.
  ///
  /// Создает два пайплайна:
  /// 1. От приложения к сети: сериализация и отправка запросов
  /// 2. От сети к приложению: получение, парсинг и десериализация ответов
  void _setupStreams() {
    // Настраиваем отправку запросов
    _requestController.stream.listen((request) {
      final serialized = _requestCodec.serialize(request);
      final framedMessage = GrpcMessageFrame.encode(serialized);
      _transport.sendData(framedMessage);
    }, onDone: () {
      _transport.finishSending();
    });

    // Настраиваем прием ответов
    _transport.incomingMessages.listen((message) {
      if (message.isMetadataOnly) {
        // Обрабатываем метаданные
        final statusCode =
            message.metadata?.getHeaderValue(GrpcConstants.GRPC_STATUS_HEADER);

        if (statusCode != null) {
          // Это трейлер, проверяем статус
          final code = int.parse(statusCode);
          if (code != GrpcStatus.OK) {
            final errorMessage = message.metadata
                    ?.getHeaderValue(GrpcConstants.GRPC_MESSAGE_HEADER) ??
                '';
            _responseController
                .addError(Exception('gRPC error $code: $errorMessage'));
          }

          if (message.isEndOfStream) {
            _responseController.close();
          }
        }

        // Передаем метаданные в поток ответов
        _responseController.add(GrpcMessage<TResponse>(
          metadata: message.metadata,
          isMetadataOnly: true,
          isEndOfStream: message.isEndOfStream,
        ));
      } else if (message.payload != null) {
        // Обрабатываем сообщения
        final messageBytes = message.payload as List<int>;
        final messages = _parser.processIncomingData(messageBytes);

        for (var msgBytes in messages) {
          final response = _responseCodec.deserialize(msgBytes);
          _responseController.add(GrpcMessage.withPayload(response));
        }
      }
    }, onError: (error) {
      _responseController.addError(error);
      _responseController.close();
    }, onDone: () {
      if (!_responseController.isClosed) {
        _responseController.close();
      }
    });
  }

  /// Отправляет запрос серверу.
  ///
  /// Сериализует объект запроса и отправляет его серверу через транспорт.
  /// Запросы можно отправлять в любом порядке и в любое время,
  /// пока не вызван метод finishSending().
  ///
  /// [request] Объект запроса для отправки
  void send(TRequest request) {
    if (!_requestController.isClosed) {
      _requestController.add(request);
    }
  }

  /// Завершает отправку запросов.
  ///
  /// Сигнализирует серверу, что клиент закончил отправку запросов.
  /// После вызова этого метода новые запросы отправлять нельзя,
  /// но можно продолжать получать ответы от сервера.
  void finishSending() {
    if (!_requestController.isClosed) {
      _requestController.close();
    }
  }

  /// Закрывает стрим.
  ///
  /// Полностью завершает двунаправленный стрим, освобождая все ресурсы.
  /// - Завершает отправку запросов
  /// - Закрывает транспортное соединение
  /// - Отменяет все подписки на события
  void close() {
    finishSending();
    _transport.close();
  }

  /// Фабричный метод для создания и инициализации стрима.
  ///
  /// Создает транспортное соединение с сервером и инициализирует
  /// двунаправленный стрим с указанным сервисом и методом.
  ///
  /// [host] Хост сервера
  /// [port] Порт сервера
  /// [serviceName] Имя сервиса
  /// [methodName] Имя метода
  /// [requestCodec] Кодек для запросов
  /// [responseCodec] Кодек для ответов
  /// [useTls] Использовать ли TLS/HTTPS
  /// Возвращает готовый к использованию двунаправленный стрим
  static Future<BidirectionalStreamClient<TRequest, TResponse>>
      create<TRequest, TResponse>(
          String host,
          int port,
          String serviceName,
          String methodName,
          MessageCodec<TRequest> requestCodec,
          MessageCodec<TResponse> responseCodec,
          {bool useTls = false}) async {
    // Создаем транспорт
    final transport = Http2Transport.connect(host, port, useTls: useTls);

    // Отправляем начальные заголовки
    final headers =
        Metadata.forClientRequest(serviceName, methodName, host: '$host:$port');
    transport.sendHeaders(headers);

    // Создаем и возвращаем стрим
    return BidirectionalStreamClient<TRequest, TResponse>(
      transport,
      requestCodec,
      responseCodec,
    );
  }
}

/// Серверная реализация двунаправленного стрима gRPC.
///
/// Обеспечивает полную реализацию серверной стороны двунаправленного
/// стриминга gRPC. Обрабатывает входящие запросы от клиента и позволяет
/// отправлять ответы асинхронно, независимо от получения запросов.
///
/// Ключевые возможности:
/// - Асинхронная обработка потока входящих запросов
/// - Асинхронная отправка потока ответов
/// - Автоматическая сериализация/десериализация сообщений
/// - Управление статусами и ошибками gRPC
class BidirectionalStreamServer<TRequest, TResponse> {
  /// Базовый HTTP/2 транспорт для обмена данными
  final Http2Transport _transport;

  /// Кодек для десериализации входящих запросов
  final MessageCodec<TRequest> _requestCodec;

  /// Кодек для сериализации исходящих ответов
  final MessageCodec<TResponse> _responseCodec;

  /// Контроллер потока входящих запросов
  final StreamController<TRequest> _requestController =
      StreamController<TRequest>();

  /// Контроллер потока исходящих ответов
  final StreamController<TResponse> _responseController =
      StreamController<TResponse>();

  /// Парсер для обработки фрагментированных сообщений
  final GrpcMessageParser _parser = GrpcMessageParser();

  /// Флаг, указывающий, были ли отправлены начальные заголовки
  bool _headersSent = false;

  /// Поток входящих запросов от клиента.
  ///
  /// Предоставляет доступ к потоку запросов, получаемых от клиента.
  /// Бизнес-логика может подписаться на этот поток для обработки запросов.
  /// Поток завершается, когда клиент завершает свою часть стрима.
  Stream<TRequest> get requests => _requestController.stream;

  /// Создает новый серверный двунаправленный стрим.
  ///
  /// [_transport] Транспортный уровень HTTP/2
  /// [_requestCodec] Кодек для десериализации запросов
  /// [_responseCodec] Кодек для сериализации ответов
  BidirectionalStreamServer(
      this._transport, this._requestCodec, this._responseCodec) {
    _setupStreams();
  }

  /// Настраивает потоки данных для обработки запросов и отправки ответов.
  ///
  /// 1. Инициализирует отправку начальных заголовков клиенту
  /// 2. Настраивает пайплайн для отправки ответов
  /// 3. Настраивает обработку входящих сообщений от клиента
  void _setupStreams() {
    // Отправляем начальные заголовки
    final initialHeaders = Metadata.forServerInitialResponse();
    _transport.sendHeaders(initialHeaders);
    _headersSent = true;

    // Настраиваем отправку ответов
    _responseController.stream.listen((response) {
      final serialized = _responseCodec.serialize(response);
      final framedMessage = GrpcMessageFrame.encode(serialized);
      _transport.sendData(framedMessage);
    }, onDone: () {
      // Отправляем трейлер при завершении отправки ответов
      final trailers = Metadata.forTrailer(GrpcStatus.OK);
      _transport.sendHeaders(trailers, endStream: true);
    });

    // Настраиваем прием запросов
    _transport.incomingMessages.listen((message) {
      if (!message.isMetadataOnly && message.payload != null) {
        // Обрабатываем сообщения
        final messageBytes = message.payload as List<int>;
        final messages = _parser.processIncomingData(messageBytes);

        for (var msgBytes in messages) {
          final request = _requestCodec.deserialize(msgBytes);
          _requestController.add(request);
        }
      }

      // Если это конец потока запросов, закрываем контроллер
      if (message.isEndOfStream) {
        _requestController.close();
      }
    }, onError: (error) {
      _requestController.addError(error);
      _requestController.close();
      sendError(GrpcStatus.INTERNAL, 'Внутренняя ошибка: $error');
    }, onDone: () {
      if (!_requestController.isClosed) {
        _requestController.close();
      }
    });
  }

  /// Отправляет ответ клиенту.
  ///
  /// Сериализует объект ответа и отправляет его клиенту.
  /// Ответы можно отправлять в любом порядке и в любое время,
  /// пока не вызван метод finishSending().
  ///
  /// [response] Объект ответа для отправки
  void send(TResponse response) {
    if (!_responseController.isClosed) {
      _responseController.add(response);
    }
  }

  /// Отправляет сообщение об ошибке клиенту.
  ///
  /// Завершает поток с указанным кодом ошибки gRPC и текстовым сообщением.
  /// После вызова этого метода стрим завершается и новые ответы
  /// отправлять невозможно.
  ///
  /// [statusCode] Код ошибки gRPC (см. GrpcStatus)
  /// [message] Текстовое сообщение с описанием ошибки
  void sendError(int statusCode, String message) {
    if (!_responseController.isClosed) {
      _responseController.close();
    }

    final trailers = Metadata.forTrailer(statusCode, message: message);
    _transport.sendHeaders(trailers, endStream: true);
  }

  /// Завершает отправку ответов.
  ///
  /// Сигнализирует клиенту, что сервер закончил отправку ответов.
  /// Автоматически отправляет трейлер с успешным статусом.
  /// После вызова этого метода новые ответы отправлять нельзя.
  void finishSending() {
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }

  /// Закрывает стрим и освобождает ресурсы.
  ///
  /// Полностью завершает двунаправленный стрим:
  /// - Завершает отправку ответов
  /// - Закрывает транспортное соединение
  /// - Отменяет все подписки
  void close() {
    finishSending();
    _transport.close();
  }
}

/// Фабрика для создания обработчиков двунаправленных стримов.
///
/// Абстрактный интерфейс, который должны реализовать обработчики
/// бизнес-логики для преобразования потока запросов в поток ответов.
/// Это основной контракт для обработки двунаправленных стримов на сервере.
abstract class BidirectionalStreamHandlerFactory<TRequest, TResponse> {
  /// Обрабатывает поток запросов и создает поток ответов.
  ///
  /// Преобразует входящий поток запросов в исходящий поток ответов
  /// в соответствии с бизнес-логикой. Реализации могут обрабатывать
  /// запросы как последовательно, так и асинхронно.
  ///
  /// [requests] Входящий поток запросов от клиента
  /// Возвращает поток ответов для отправки клиенту
  Stream<TResponse> handle(Stream<TRequest> requests);
}

/// Сервер gRPC для обработки RPC вызовов.
///
/// Абстрактный интерфейс сервера gRPC, реализации которого должны
/// обеспечивать прослушивание TCP-порта, обработку HTTP/2 соединений
/// и маршрутизацию вызовов к соответствующим обработчикам сервисов.
abstract class GrpcServer {
  /// Запускает сервер на указанном порту.
  ///
  /// Начинает прослушивание входящих соединений на указанном TCP-порту
  /// и обработку gRPC запросов.
  ///
  /// [port] Порт для прослушивания
  /// Возвращает Future, который завершается при успешном запуске
  Future<void> start(int port);

  /// Регистрирует сервис с обработчиком.
  ///
  /// Добавляет обработчик для указанного метода сервиса,
  /// чтобы сервер мог маршрутизировать входящие запросы
  /// к соответствующей бизнес-логике.
  ///
  /// [serviceName] Имя сервиса (часть пути RPC)
  /// [methodName] Имя метода (часть пути RPC)
  /// [handlerFactory] Фабрика для создания обработчиков запросов
  /// [requestCodec] Кодек для десериализации запросов
  /// [responseCodec] Кодек для сериализации ответов
  void registerService<TRequest, TResponse>(
      String serviceName,
      String methodName,
      BidirectionalStreamHandlerFactory<TRequest, TResponse> handlerFactory,
      MessageCodec<TRequest> requestCodec,
      MessageCodec<TResponse> responseCodec);

  /// Останавливает сервер.
  ///
  /// Прекращает прослушивание входящих соединений и
  /// завершает все активные соединения. Освобождает ресурсы.
  ///
  /// Возвращает Future, который завершается при успешной остановке
  Future<void> stop();
}
