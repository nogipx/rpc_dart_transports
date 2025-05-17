part of '_index.dart';

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
