part of '_index.dart';

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
