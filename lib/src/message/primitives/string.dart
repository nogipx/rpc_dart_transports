part of '_index.dart';

/// Обертка для строкового значения
class RpcString extends RpcPrimitiveMessage<String> {
  const RpcString(super.value);

  /// Создает RpcString из JSON
  factory RpcString.fromJson(Map<String, dynamic> json) {
    try {
      final v = json['v'];
      if (v == null) return const RpcString('');
      if (v is String) return RpcString(v);
      return RpcString(v.toString());
    } catch (e) {
      return const RpcString('');
    }
  }

  @override
  Map<String, dynamic> toJson() => {'v': value};

  @override
  String toString() => toJson().toString();
}
