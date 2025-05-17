part of '_index.dart';

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
