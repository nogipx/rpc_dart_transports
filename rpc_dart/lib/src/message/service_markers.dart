// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';

/// Перечисление возможных типов служебных маркеров
enum RpcMarkerType {
  /// Маркер завершения клиентского стрима
  clientStreamEnd,

  /// Маркер завершения серверного стрима
  serverStreamEnd,

  /// Маркер пинга
  ping,

  /// Маркер понга (ответ на пинг)
  pong,

  /// Маркер статуса операции
  status,

  /// Маркер заголовков (начальные метаданные)
  headers,

  /// Маркер трейлеров (завершающие метаданные)
  trailers,

  /// Маркер тайм-аута/предельного срока
  deadline,

  /// Маркер отмены операции
  cancel,

  /// Маркер управления потоком
  flowControl,

  /// Маркер сжатия данных
  compression,

  /// Маркер проверки состояния сервиса
  healthCheck,

  /// Маркер начала клиентского стриминга
  clientStreamingInit,

  /// Маркер инициализации двунаправленного стриминга
  bidirectional,

  /// Маркер закрытия канала связи
  channelClosed,
}

/// Базовый абстрактный класс для всех служебных маркеров RPC
/// Все служебные маркеры (окончание стрима, начало транзакции и т.д.)
/// должны расширять этот класс
abstract class RpcServiceMarker implements IRpcSerializableMessage {
  /// Тип маркера
  RpcMarkerType get markerType;

  /// Флаг, указывающий что это служебное сообщение
  final bool isServiceMessage = true;

  /// Конструктор базового класса
  const RpcServiceMarker();

  /// Преобразование в JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      '_markerType': markerType.name,
      '_isServiceMessage': isServiceMessage,
    };
  }

  /// Создает соответствующий экземпляр маркера из JSON
  /// Автоматически определяет тип маркера по полю _markerType
  static RpcServiceMarker fromJson(Map<String, dynamic> json) {
    // Обратная совместимость с клиентским стримингом в старом формате
    if (json.containsKey('_clientStreaming') && json.containsKey('_streamId')) {
      final streamId = json['_streamId'] as String;
      // Копируем все параметры кроме служебных
      final Map<String, dynamic> parameters = {};
      json.forEach((key, value) {
        if (!key.startsWith('_')) {
          parameters[key] = value;
        }
      });

      return RpcClientStreamingMarker(
        streamId: streamId,
        parameters: parameters.isNotEmpty ? parameters : null,
      );
    }

    if (!json.containsKey('_markerType') ||
        !json.containsKey('_isServiceMessage')) {
      throw FormatException(
          'Недопустимый формат JSON для маркера: отсутствуют обязательные поля');
    }

    final markerTypeName = json['_markerType'] as String;

    try {
      // Преобразуем строку в enum
      final markerType = RpcMarkerType.values.firstWhere(
        (type) => type.name == markerTypeName,
        orElse: () =>
            throw FormatException('Неизвестный тип маркера: $markerTypeName'),
      );

      // Выбираем соответствующий класс конкретного маркера
      switch (markerType) {
        case RpcMarkerType.clientStreamEnd:
          return RpcClientStreamEndMarker.fromJson(json);
        case RpcMarkerType.serverStreamEnd:
          return RpcServerStreamEndMarker.fromJson(json);
        case RpcMarkerType.ping:
          return RpcPingMarker.fromJson(json);
        case RpcMarkerType.pong:
          return RpcPongMarker.fromJson(json);
        case RpcMarkerType.status:
          return RpcStatusMarker.fromJson(json);
        case RpcMarkerType.deadline:
          return RpcDeadlineMarker.fromJson(json);
        case RpcMarkerType.cancel:
          return RpcCancelMarker.fromJson(json);
        case RpcMarkerType.clientStreamingInit:
          return RpcClientStreamingMarker.fromJson(json);
        case RpcMarkerType.headers:
          return RpcHeadersMarker.fromJson(json);
        case RpcMarkerType.trailers:
          return RpcTrailersMarker.fromJson(json);
        case RpcMarkerType.flowControl:
          return RpcFlowControlMarker.fromJson(json);
        case RpcMarkerType.compression:
          return RpcCompressionMarker.fromJson(json);
        case RpcMarkerType.healthCheck:
          return RpcHealthCheckMarker.fromJson(json);
        case RpcMarkerType.bidirectional:
          return RpcBidirectionalStreamingMarker.fromJson(json);
        case RpcMarkerType.channelClosed:
          return RpcChannelClosedMarker.fromJson(json);
      }
    } catch (e) {
      throw FormatException('Ошибка при создании маркера: $e');
    }
  }
}

/// Маркер завершения клиентского стрима
class RpcClientStreamEndMarker extends RpcServiceMarker {
  /// Конструктор
  const RpcClientStreamEndMarker();

  @override
  RpcMarkerType get markerType => RpcMarkerType.clientStreamEnd;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['_clientStreamEnd'] = true;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcClientStreamEndMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.clientStreamEnd.name ||
        json['_clientStreamEnd'] != true) {
      throw FormatException(
          'Неверный формат маркера завершения клиентского стрима');
    }
    return const RpcClientStreamEndMarker();
  }
}

/// Маркер завершения серверного стрима
class RpcServerStreamEndMarker extends RpcServiceMarker {
  /// Конструктор
  const RpcServerStreamEndMarker();

  @override
  RpcMarkerType get markerType => RpcMarkerType.serverStreamEnd;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['_serverStreamEnd'] = true;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcServerStreamEndMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.serverStreamEnd.name ||
        json['_serverStreamEnd'] != true) {
      throw FormatException(
          'Неверный формат маркера завершения серверного стрима');
    }
    return const RpcServerStreamEndMarker();
  }
}

/// Маркер пинга/проверки соединения
class RpcPingMarker extends RpcServiceMarker {
  /// Временная метка для расчета RTT
  final int timestamp;

  /// Конструктор
  RpcPingMarker({int? timestamp})
      : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  @override
  RpcMarkerType get markerType => RpcMarkerType.ping;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['timestamp'] = timestamp;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcPingMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.ping.name) {
      throw FormatException('Неверный формат маркера пинга');
    }
    return RpcPingMarker(timestamp: json['timestamp'] as int);
  }
}

/// Маркер подтверждения (понг)
class RpcPongMarker extends RpcServiceMarker {
  /// Временная метка из исходного пинга
  final int originalTimestamp;

  /// Временная метка ответа
  final int responseTimestamp;

  /// Конструктор
  RpcPongMarker({
    required this.originalTimestamp,
    int? responseTimestamp,
  }) : responseTimestamp =
            responseTimestamp ?? DateTime.now().millisecondsSinceEpoch;

  @override
  RpcMarkerType get markerType => RpcMarkerType.pong;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['originalTimestamp'] = originalTimestamp;
    baseJson['responseTimestamp'] = responseTimestamp;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcPongMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.pong.name) {
      throw FormatException('Неверный формат маркера пинга');
    }
    return RpcPongMarker(
      originalTimestamp: json['originalTimestamp'] as int,
      responseTimestamp: json['responseTimestamp'] as int,
    );
  }
}

/// Коды состояния операции в стиле gRPC
enum RpcStatusCode {
  /// Операция выполнена успешно
  ok(0),

  /// Операция отменена клиентом
  cancelled(1),

  /// Неизвестная ошибка
  unknown(2),

  /// Некорректный аргумент
  invalidArgument(3),

  /// Время ожидания истекло
  deadlineExceeded(4),

  /// Ресурс не найден
  notFound(5),

  /// Ресурс уже существует
  alreadyExists(6),

  /// Отказано в доступе
  permissionDenied(7),

  /// Недостаточно ресурсов
  resourceExhausted(8),

  /// Предварительное условие не выполнено
  failedPrecondition(9),

  /// Операция прервана
  aborted(10),

  /// Ресурс вне допустимого диапазона
  outOfRange(11),

  /// Функциональность не реализована
  unimplemented(12),

  /// Внутренняя ошибка сервера
  internal(13),

  /// Сервис недоступен
  unavailable(14),

  /// Ошибка аутентификации
  unauthenticated(16);

  /// Числовой код состояния
  final int code;

  /// Конструктор
  const RpcStatusCode(this.code);

  /// Создает RpcStatusCode из числового кода
  factory RpcStatusCode.fromCode(int code) {
    return RpcStatusCode.values.firstWhere(
      (status) => status.code == code,
      orElse: () => RpcStatusCode.unknown,
    );
  }
}

/// Маркер статуса операции в стиле gRPC
class RpcStatusMarker extends RpcServiceMarker {
  /// Код состояния
  final RpcStatusCode code;

  /// Сообщение с описанием
  final String message;

  /// Детали ошибки (опционально)
  final Map<String, dynamic>? details;

  /// Конструктор
  const RpcStatusMarker({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.status;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['code'] = code.code;
    baseJson['message'] = message;
    if (details != null) {
      baseJson['details'] = details;
    }
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcStatusMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.status.name) {
      throw FormatException('Неверный формат маркера статуса');
    }

    return RpcStatusMarker(
      code: RpcStatusCode.fromCode(json['code'] as int),
      message: json['message'] as String,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}

/// Маркер для управления тайм-аутами (deadline) в стиле gRPC
class RpcDeadlineMarker extends RpcServiceMarker {
  /// Время окончания в миллисекундах с начала эпохи
  final int deadlineTimestamp;

  /// Конструктор с явным указанием времени
  const RpcDeadlineMarker({
    required this.deadlineTimestamp,
  });

  /// Конструктор с указанием Duration от текущего момента
  factory RpcDeadlineMarker.fromDuration(Duration timeout) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return RpcDeadlineMarker(
      deadlineTimestamp: now + timeout.inMilliseconds,
    );
  }

  /// Проверяет, истек ли срок
  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= deadlineTimestamp;

  /// Возвращает оставшееся время
  Duration get remaining {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = deadlineTimestamp - now;
    if (remaining <= 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: remaining);
  }

  @override
  RpcMarkerType get markerType => RpcMarkerType.deadline;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['deadlineTimestamp'] = deadlineTimestamp;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcDeadlineMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.deadline.name) {
      throw FormatException('Неверный формат маркера deadline');
    }

    return RpcDeadlineMarker(
      deadlineTimestamp: json['deadlineTimestamp'] as int,
    );
  }
}

/// Маркер отмены операции в стиле gRPC
class RpcCancelMarker extends RpcServiceMarker {
  /// Идентификатор операции для отмены
  final String operationId;

  /// Причина отмены (опционально)
  final String? reason;

  /// Дополнительные данные (опционально)
  final Map<String, dynamic>? details;

  /// Конструктор
  const RpcCancelMarker({
    required this.operationId,
    this.reason,
    this.details,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.cancel;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['operationId'] = operationId;
    if (reason != null) {
      baseJson['reason'] = reason;
    }
    if (details != null) {
      baseJson['details'] = details;
    }
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcCancelMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.cancel.name) {
      throw FormatException('Неверный формат маркера отмены');
    }

    return RpcCancelMarker(
      operationId: json['operationId'] as String,
      reason: json['reason'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}

/// Маркер инициализации клиентского стриминга
class RpcClientStreamingMarker extends RpcServiceMarker {
  /// Идентификатор потока
  final String streamId;

  /// Дополнительные параметры (опционально)
  final Map<String, dynamic>? parameters;

  /// Конструктор
  const RpcClientStreamingMarker({
    required this.streamId,
    this.parameters,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.clientStreamingInit;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['_clientStreaming'] = true; // для обратной совместимости
    baseJson['_streamId'] = streamId;

    // Добавляем дополнительные параметры, если они есть
    if (parameters != null) {
      baseJson.addAll(parameters!);
    }

    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcClientStreamingMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.clientStreamingInit.name ||
        json['_clientStreaming'] != true ||
        json['_streamId'] == null) {
      throw FormatException(
          'Неверный формат маркера инициализации клиентского стриминга');
    }

    // Копируем все параметры кроме служебных
    final Map<String, dynamic> parameters = {};
    json.forEach((key, value) {
      if (!key.startsWith('_')) {
        parameters[key] = value;
      }
    });

    return RpcClientStreamingMarker(
      streamId: json['_streamId'] as String,
      parameters: parameters.isNotEmpty ? parameters : null,
    );
  }
}

/// Маркер заголовков (начальные метаданные)
class RpcHeadersMarker extends RpcServiceMarker {
  /// Метаданные запроса
  final Map<String, dynamic> headers;

  /// Конструктор
  const RpcHeadersMarker({
    required this.headers,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.headers;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['headers'] = headers;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcHeadersMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.headers.name) {
      throw FormatException('Неверный формат маркера заголовков');
    }

    return RpcHeadersMarker(
      headers: json['headers'] as Map<String, dynamic>,
    );
  }
}

/// Маркер трейлеров (завершающие метаданные)
class RpcTrailersMarker extends RpcServiceMarker {
  /// Завершающие метаданные
  final Map<String, dynamic> trailers;

  /// Конструктор
  const RpcTrailersMarker({
    required this.trailers,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.trailers;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['trailers'] = trailers;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcTrailersMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.trailers.name) {
      throw FormatException('Неверный формат маркера трейлеров');
    }

    return RpcTrailersMarker(
      trailers: json['trailers'] as Map<String, dynamic>,
    );
  }
}

/// Маркер управления потоком для реализации контроля за скоростью передачи
class RpcFlowControlMarker extends RpcServiceMarker {
  /// Максимальное количество сообщений, которое можно отправить
  final int windowSize;

  /// Флаг приостановки/возобновления потока (true - возобновить, false - приостановить)
  final bool allowData;

  /// Конструктор
  const RpcFlowControlMarker({
    required this.windowSize,
    this.allowData = true,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.flowControl;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['windowSize'] = windowSize;
    baseJson['allowData'] = allowData;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcFlowControlMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.flowControl.name) {
      throw FormatException('Неверный формат маркера управления потоком');
    }

    return RpcFlowControlMarker(
      windowSize: json['windowSize'] as int,
      allowData: json['allowData'] as bool? ?? true,
    );
  }
}

/// Типы сжатия данных
enum RpcCompressionType {
  /// Без сжатия
  none,

  /// Сжатие GZIP
  gzip,

  /// Сжатие Snappy
  snappy,

  /// Сжатие Deflate
  deflate,

  /// Сжатие Brotli
  brotli,

  /// Сжатие Zstandard
  zstd,
}

/// Маркер для указания используемого метода сжатия
class RpcCompressionMarker extends RpcServiceMarker {
  /// Тип используемого сжатия
  final RpcCompressionType compressionType;

  /// Уровень сжатия (для алгоритмов с настраиваемым уровнем)
  final int? compressionLevel;

  /// Включено ли сжатие (позволяет временно отключить)
  final bool enabled;

  /// Конструктор
  const RpcCompressionMarker({
    required this.compressionType,
    this.compressionLevel,
    this.enabled = true,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.compression;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['compressionType'] = compressionType.name;
    if (compressionLevel != null) {
      baseJson['compressionLevel'] = compressionLevel;
    }
    baseJson['enabled'] = enabled;
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcCompressionMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.compression.name) {
      throw FormatException('Неверный формат маркера сжатия');
    }

    final compressionTypeName = json['compressionType'] as String;
    final compressionType = RpcCompressionType.values.firstWhere(
      (type) => type.name == compressionTypeName,
      orElse: () => RpcCompressionType.none,
    );

    return RpcCompressionMarker(
      compressionType: compressionType,
      compressionLevel: json['compressionLevel'] as int?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// Состояние сервиса для проверок health check
enum RpcServiceHealthStatus {
  /// Сервис работает нормально
  serving,

  /// Сервис не обслуживает запросы
  notServing,

  /// Сервис в процессе запуска
  starting,

  /// Статус сервиса неизвестен
  unknown,
}

/// Маркер для проверки состояния сервиса (health check)
class RpcHealthCheckMarker extends RpcServiceMarker {
  /// Имя сервиса для проверки
  final String serviceName;

  /// Статус сервиса (опционально, для ответа)
  final RpcServiceHealthStatus? status;

  /// Конструктор
  const RpcHealthCheckMarker({
    required this.serviceName,
    this.status,
  });

  /// Конструктор для создания ответа на проверку здоровья
  factory RpcHealthCheckMarker.response({
    required String serviceName,
    required RpcServiceHealthStatus status,
  }) {
    return RpcHealthCheckMarker(
      serviceName: serviceName,
      status: status,
    );
  }

  @override
  RpcMarkerType get markerType => RpcMarkerType.healthCheck;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['serviceName'] = serviceName;
    if (status != null) {
      baseJson['status'] = status!.name;
    }
    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcHealthCheckMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.healthCheck.name) {
      throw FormatException('Неверный формат маркера проверки состояния');
    }

    final statusName = json['status'] as String?;
    RpcServiceHealthStatus? status;

    if (statusName != null) {
      status = RpcServiceHealthStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => RpcServiceHealthStatus.unknown,
      );
    }

    return RpcHealthCheckMarker(
      serviceName: json['serviceName'] as String,
      status: status,
    );
  }
}

/// Маркер инициализации двунаправленного стриминга
class RpcBidirectionalStreamingMarker extends RpcServiceMarker {
  /// Идентификатор потока
  final String streamId;

  /// Дополнительные параметры (опционально)
  final Map<String, dynamic>? parameters;

  /// Конструктор
  const RpcBidirectionalStreamingMarker({
    required this.streamId,
    this.parameters,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.bidirectional;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['_bidirectional'] = true; // для обратной совместимости
    baseJson['_streamId'] = streamId;

    // Добавляем дополнительные параметры, если они есть
    if (parameters != null) {
      baseJson.addAll(parameters!);
    }

    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcBidirectionalStreamingMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.bidirectional.name ||
        json['_bidirectional'] != true ||
        json['_streamId'] == null) {
      throw FormatException(
          'Неверный формат маркера инициализации двунаправленного стриминга');
    }

    // Копируем все параметры кроме служебных
    final Map<String, dynamic> parameters = {};
    json.forEach((key, value) {
      if (!key.startsWith('_')) {
        parameters[key] = value;
      }
    });

    return RpcBidirectionalStreamingMarker(
      streamId: json['_streamId'] as String,
      parameters: parameters.isNotEmpty ? parameters : null,
    );
  }
}

/// Маркер закрытия канала связи
class RpcChannelClosedMarker extends RpcServiceMarker {
  /// Идентификатор потока (опционально)
  final String? streamId;

  /// Причина закрытия (опционально)
  final String? reason;

  /// Конструктор
  const RpcChannelClosedMarker({
    this.streamId,
    this.reason,
  });

  @override
  RpcMarkerType get markerType => RpcMarkerType.channelClosed;

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['_channelClosed'] = true; // для обратной совместимости

    if (streamId != null) {
      baseJson['_streamId'] = streamId;
    }

    if (reason != null) {
      baseJson['reason'] = reason;
    }

    return baseJson;
  }

  /// Фабричный метод для создания из JSON
  factory RpcChannelClosedMarker.fromJson(Map<String, dynamic> json) {
    if (json['_markerType'] != RpcMarkerType.channelClosed.name ||
        json['_channelClosed'] != true) {
      throw FormatException('Неверный формат маркера закрытия канала');
    }

    return RpcChannelClosedMarker(
      streamId: json['_streamId'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

/// Расширение для IRpcTransport, добавляющее методы для работы с маркерами
extension RpcMarkerTransportExtension on IRpcTransport {
  /// Отправляет служебный маркер
  Future<void> sendServiceMarker(
    RpcServiceMarker marker, {
    IRpcSerializer serializer = const MsgPackSerializer(),
  }) async {
    final json = marker.toJson();
    final data = serializer.serialize(json);
    await send(data);
  }

  /// Отправляет успешный статус OK
  Future<void> sendOkStatus([String message = 'OK']) async {
    await sendStatus(
      code: RpcStatusCode.ok,
      message: message,
    );
  }

  /// Отправляет маркер статуса
  Future<void> sendStatus({
    required RpcStatusCode code,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    final marker = RpcStatusMarker(
      code: code,
      message: message,
      details: details,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер отмены операции
  Future<void> cancelOperation({
    required String operationId,
    String? reason,
    Map<String, dynamic>? details,
  }) async {
    final marker = RpcCancelMarker(
      operationId: operationId,
      reason: reason,
      details: details,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер установки тайм-аута
  Future<void> setDeadline(Duration timeout) async {
    final marker = RpcDeadlineMarker.fromDuration(timeout);
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер завершения клиентского потока
  Future<void> endClientStream() async {
    const marker = RpcClientStreamEndMarker();
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер завершения серверного потока
  Future<void> endServerStream() async {
    const marker = RpcServerStreamEndMarker();
    await sendServiceMarker(marker);
  }

  /// Отправляет пинг для проверки соединения
  Future<void> sendPing() async {
    final marker = RpcPingMarker();
    await sendServiceMarker(marker);
  }

  /// Отправляет понг в ответ на пинг
  Future<void> sendPong(RpcPingMarker pingMarker) async {
    final marker = RpcPongMarker(originalTimestamp: pingMarker.timestamp);
    await sendServiceMarker(marker);
  }

  /// Отправляет заголовки (метаданные)
  Future<void> sendHeaders(Map<String, dynamic> headers) async {
    final marker = RpcHeadersMarker(headers: headers);
    await sendServiceMarker(marker);
  }

  /// Отправляет трейлеры (завершающие метаданные)
  Future<void> sendTrailers(Map<String, dynamic> trailers) async {
    final marker = RpcTrailersMarker(trailers: trailers);
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер управления потоком
  Future<void> sendFlowControl({
    required int windowSize,
    bool allowData = true,
  }) async {
    final marker = RpcFlowControlMarker(
      windowSize: windowSize,
      allowData: allowData,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет запрос на проверку состояния сервиса
  Future<void> checkServiceHealth(String serviceName) async {
    final marker = RpcHealthCheckMarker(serviceName: serviceName);
    await sendServiceMarker(marker);
  }

  /// Отправляет ответ о состоянии сервиса
  Future<void> reportServiceHealth({
    required String serviceName,
    required RpcServiceHealthStatus status,
  }) async {
    final marker = RpcHealthCheckMarker.response(
      serviceName: serviceName,
      status: status,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет информацию о сжатии
  Future<void> setCompression({
    required RpcCompressionType compressionType,
    int? compressionLevel,
    bool enabled = true,
  }) async {
    final marker = RpcCompressionMarker(
      compressionType: compressionType,
      compressionLevel: compressionLevel,
      enabled: enabled,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер инициализации двунаправленного стриминга
  Future<void> initBidirectionalStreaming({
    required String streamId,
    Map<String, dynamic>? parameters,
  }) async {
    final marker = RpcBidirectionalStreamingMarker(
      streamId: streamId,
      parameters: parameters,
    );
    await sendServiceMarker(marker);
  }

  /// Отправляет маркер закрытия канала
  Future<void> closeChannel({
    String? streamId,
    String? reason,
  }) async {
    final marker = RpcChannelClosedMarker(
      streamId: streamId,
      reason: reason,
    );
    await sendServiceMarker(marker);
  }
}

/// Класс для обработки различных служебных маркеров
class RpcMarkerHandler {
  /// Обработчик для маркеров завершения клиентского стрима
  final void Function(RpcClientStreamEndMarker)? onClientStreamEnd;

  /// Обработчик для маркеров завершения серверного стрима
  final void Function(RpcServerStreamEndMarker)? onServerStreamEnd;

  /// Обработчик для пинг-запросов
  final void Function(RpcPingMarker)? onPing;

  /// Обработчик для понг-ответов
  final void Function(RpcPongMarker)? onPong;

  /// Обработчик для статусов
  final void Function(RpcStatusMarker)? onStatus;

  /// Обработчик для заголовков
  final void Function(RpcHeadersMarker)? onHeaders;

  /// Обработчик для трейлеров
  final void Function(RpcTrailersMarker)? onTrailers;

  /// Обработчик для маркеров тайм-аутов
  final void Function(RpcDeadlineMarker)? onDeadline;

  /// Обработчик для маркеров отмены
  final void Function(RpcCancelMarker)? onCancel;

  /// Обработчик для маркеров управления потоком
  final void Function(RpcFlowControlMarker)? onFlowControl;

  /// Обработчик для маркеров сжатия
  final void Function(RpcCompressionMarker)? onCompression;

  /// Обработчик для маркеров проверки состояния
  final void Function(RpcHealthCheckMarker)? onHealthCheck;

  /// Обработчик для маркеров инициализации стриминга
  final void Function(RpcClientStreamingMarker)? onClientStreamingInit;

  /// Обработчик для маркеров инициализации двунаправленного стриминга
  final void Function(RpcBidirectionalStreamingMarker)? onBidirectionalInit;

  /// Обработчик для маркеров закрытия канала связи
  final void Function(RpcChannelClosedMarker)? onChannelClosed;

  /// Универсальный обработчик для любых маркеров (вызывается всегда)
  final void Function(RpcServiceMarker)? onAnyMarker;

  /// Конструктор
  const RpcMarkerHandler({
    this.onClientStreamEnd,
    this.onServerStreamEnd,
    this.onPing,
    this.onPong,
    this.onStatus,
    this.onHeaders,
    this.onTrailers,
    this.onDeadline,
    this.onCancel,
    this.onFlowControl,
    this.onCompression,
    this.onHealthCheck,
    this.onClientStreamingInit,
    this.onBidirectionalInit,
    this.onChannelClosed,
    this.onAnyMarker,
  });

  /// Обрабатывает маркер в соответствии с его типом
  void handleMarker(RpcServiceMarker marker) {
    // Всегда вызываем универсальный обработчик, если он есть
    onAnyMarker?.call(marker);

    // Вызываем специфичный обработчик в зависимости от типа маркера
    switch (marker.markerType) {
      case RpcMarkerType.clientStreamEnd:
        onClientStreamEnd?.call(marker as RpcClientStreamEndMarker);
        break;
      case RpcMarkerType.serverStreamEnd:
        onServerStreamEnd?.call(marker as RpcServerStreamEndMarker);
        break;
      case RpcMarkerType.ping:
        onPing?.call(marker as RpcPingMarker);
        break;
      case RpcMarkerType.pong:
        onPong?.call(marker as RpcPongMarker);
        break;
      case RpcMarkerType.status:
        onStatus?.call(marker as RpcStatusMarker);
        break;
      case RpcMarkerType.headers:
        onHeaders?.call(marker as RpcHeadersMarker);
        break;
      case RpcMarkerType.trailers:
        onTrailers?.call(marker as RpcTrailersMarker);
        break;
      case RpcMarkerType.deadline:
        onDeadline?.call(marker as RpcDeadlineMarker);
        break;
      case RpcMarkerType.cancel:
        onCancel?.call(marker as RpcCancelMarker);
        break;
      case RpcMarkerType.flowControl:
        onFlowControl?.call(marker as RpcFlowControlMarker);
        break;
      case RpcMarkerType.compression:
        onCompression?.call(marker as RpcCompressionMarker);
        break;
      case RpcMarkerType.healthCheck:
        onHealthCheck?.call(marker as RpcHealthCheckMarker);
        break;
      case RpcMarkerType.clientStreamingInit:
        onClientStreamingInit?.call(marker as RpcClientStreamingMarker);
        break;
      case RpcMarkerType.bidirectional:
        onBidirectionalInit?.call(marker as RpcBidirectionalStreamingMarker);
        break;
      case RpcMarkerType.channelClosed:
        onChannelClosed?.call(marker as RpcChannelClosedMarker);
        break;
    }
  }

  /// Проверяет, является ли объект служебным маркером
  static bool isServiceMarker(dynamic obj) {
    if (obj is Map<String, dynamic>) {
      // Проверка на стандартный маркер с флагом
      if (obj.containsKey('_isServiceMessage') &&
          obj['_isServiceMessage'] == true) {
        return true;
      }

      // Проверка на старые форматы маркеров
      if (obj.containsKey('_clientStreaming') && obj.containsKey('_streamId')) {
        return true;
      }

      if (obj.containsKey('_bidirectional') && obj.containsKey('_streamId')) {
        return true;
      }

      if (obj.containsKey('_clientStreamEnd') &&
          obj['_clientStreamEnd'] == true) {
        return true;
      }

      if (obj.containsKey('_serverStreamEnd') &&
          obj['_serverStreamEnd'] == true) {
        return true;
      }

      if (obj.containsKey('_channelClosed') && obj['_channelClosed'] == true) {
        return true;
      }

      return false;
    }
    return obj is RpcServiceMarker;
  }

  /// Создает маркер из JSON-объекта, если это маркер
  /// Возвращает null, если объект не является маркером
  static RpcServiceMarker? tryParseMarker(dynamic obj) {
    if (obj is RpcServiceMarker) {
      return obj;
    }

    if (obj is Map<String, dynamic>) {
      // Проверка на специальную форму клиентского стриминга
      if (obj.containsKey('_clientStreaming') && obj.containsKey('_streamId')) {
        final streamId = obj['_streamId'] as String;
        return RpcClientStreamingMarker(
          streamId: streamId,
          parameters: Map.from(obj)
            ..removeWhere((key, _) => key.startsWith('_')),
        );
      }

      // Проверка на специальную форму двунаправленного стриминга
      if (obj.containsKey('_bidirectional') && obj.containsKey('_streamId')) {
        final streamId = obj['_streamId'] as String;
        return RpcBidirectionalStreamingMarker(
          streamId: streamId,
          parameters: Map.from(obj)
            ..removeWhere((key, _) => key.startsWith('_')),
        );
      }

      // Проверка на маркер завершения клиентского стрима
      if (obj.containsKey('_clientStreamEnd') &&
          obj['_clientStreamEnd'] == true) {
        return const RpcClientStreamEndMarker();
      }

      // Проверка на маркер завершения серверного стрима
      if (obj.containsKey('_serverStreamEnd') &&
          obj['_serverStreamEnd'] == true) {
        return const RpcServerStreamEndMarker();
      }

      // Проверка на маркер закрытия канала
      if (obj.containsKey('_channelClosed') && obj['_channelClosed'] == true) {
        return RpcChannelClosedMarker(
          streamId: obj['_streamId'] as String?,
          reason: obj['reason'] as String?,
        );
      }

      // Проверка на обычный маркер
      if (obj.containsKey('_isServiceMessage') &&
          obj['_isServiceMessage'] == true) {
        try {
          return RpcServiceMarker.fromJson(obj);
        } catch (e) {
          // Если разбор маркера не удался, возвращаем null
          return null;
        }
      }
    }

    return null;
  }
}

/// Исключение, связанное со статусом RPC
class RpcStatusException implements Exception {
  /// Код статуса
  final RpcStatusCode code;

  /// Сообщение об ошибке
  final String message;

  /// Дополнительные детали
  final Map<String, dynamic>? details;

  /// Создает исключение со статусом RPC
  const RpcStatusException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('RpcStatusException: [${code.name}] $message');
    if (details != null && details!.isNotEmpty) {
      buffer.write(' (details: $details)');
    }
    return buffer.toString();
  }

  /// Создает маркер статуса из этого исключения
  RpcStatusMarker toMarker() {
    return RpcStatusMarker(
      code: code,
      message: message,
      details: details,
    );
  }

  /// Создает исключение из маркера статуса
  factory RpcStatusException.fromMarker(RpcStatusMarker marker) {
    return RpcStatusException(
      code: marker.code,
      message: marker.message,
      details: marker.details,
    );
  }
}
