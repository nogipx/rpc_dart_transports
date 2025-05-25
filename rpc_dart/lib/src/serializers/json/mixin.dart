part of '../_index.dart';

/// Миксин для автоматической сериализации JSON -> байты
/// Позволяет разработчикам использовать привычные toJson/fromJson методы
/// и автоматически получать binary сериализацию через JSON
mixin RpcJsonSerializable on IRpcSerializable {
  RpcLogger get _logger => RpcLogger('RpcJsonSerializable');

  @override
  Uint8List serialize() {
    try {
      final json = (this as dynamic).toJson();
      final jsonString = jsonEncode(json);
      return Uint8List.fromList(utf8.encode(jsonString));
    } on NoSuchMethodError catch (_) {
      _logger.error('Метод toJson() не найден');
      rethrow;
    }
  }

  /// Переопределяем метод для указания формата сериализации
  @override
  RpcCodecType codec() => RpcCodecType.json;

  /// Статический хелпер для десериализации из байтов через JSON
  static T fromBytes<T>(
    Uint8List bytes,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final jsonString = utf8.decode(bytes);
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return fromJson(json);
    } catch (e) {
      if (jsonString.startsWith('Instance of ')) {
        throw FormatException(
          'Получена строка представления объекта вместо JSON: $jsonString. '
          'Убедитесь, что объект правильно сериализуется в JSON перед отправкой.',
        );
      }
      rethrow;
    }
  }
}
