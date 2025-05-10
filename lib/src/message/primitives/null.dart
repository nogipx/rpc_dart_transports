part of '_index.dart';

/// Обертка для null
class RpcNull extends RpcPrimitiveMessage<void> {
  const RpcNull() : super(null);

  /// Создает RpcNull из JSON (в любом случае возвращает RpcNull)
  factory RpcNull.fromJson(Map<String, dynamic> json) {
    return const RpcNull();
  }

  @override
  Map<String, dynamic> toJson() => {'v': null};

  @override
  String toString() => toJson().toString();
}
