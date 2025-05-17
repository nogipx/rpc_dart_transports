part of '_index.dart';

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
