// ignore_for_file: constant_identifier_names

part of '_index.dart';

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
