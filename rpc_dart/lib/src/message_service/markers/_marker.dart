part of '_index.dart';

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

  static bool checkIsServiceMessage(
    dynamic json, {
    RpcMarkerType? specificMarkerType,
  }) {
    final isJson = json is Map<String, dynamic>;
    final isServiceMessage = isJson && json['_isServiceMessage'] == true;
    final markerTypeMatch = specificMarkerType != null
        ? isJson && json['_markerType'] == specificMarkerType.name
        : true;
    return isServiceMessage && markerTypeMatch;
  }

  static bool checkIsEmptyServiceMessage(dynamic json) {
    if (json is Map && json['_empty'] == true) {
      return true;
    }
    return false;
  }
}
