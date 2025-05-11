// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'dart:typed_data';
import 'serializer.dart';
import 'msgpack/msgpack.dart' as msgpack;
import '../contracts/_contract.dart' show IRpcSerializableMessage;

/// Реализация сериализатора, использующего MessagePack
/// MessagePack - это бинарный формат сериализации, более компактный чем JSON
/// https://msgpack.org/
class MsgPackSerializer implements RpcSerializer {
  const MsgPackSerializer();

  @override
  Uint8List serialize(dynamic message) {
    // Подготовка объекта для сериализации
    final prepared = _prepareForSerialization(message);

    // Сериализуем подготовленный объект
    try {
      return msgpack.serialize(prepared);
    } catch (e) {
      print('MsgPackSerializer: ошибка при сериализации: $e');
      rethrow;
    }
  }

  /// Рекурсивно подготавливает объект для сериализации
  dynamic _prepareForSerialization(dynamic value) {
    if (value == null) {
      return null;
    }

    // Базовые типы не требуют преобразования
    if (value is num || value is String || value is bool) {
      return value;
    }

    // Обработка бинарных данных
    if (value is Uint8List) {
      return value;
    }

    // Обработка объектов, реализующих IRpcSerializableMessage
    if (value is IRpcSerializableMessage) {
      return _prepareForSerialization(value.toJson());
    }

    // Проверка на наличие метода toJson для других объектов
    if (value is! List && value is! Map) {
      try {
        final dynamic dynamicValue = value;
        final jsonData = dynamicValue.toJson();
        if (jsonData is Map) {
          return _prepareForSerialization(jsonData);
        }
      } catch (_) {
        // Игнорируем, если метод не существует
      }
    }

    // Рекурсивная обработка списков
    if (value is List) {
      return value.map((item) => _prepareForSerialization(item)).toList();
    }

    // Рекурсивная обработка карт
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final val = _prepareForSerialization(entry.value);
        result[key] = val;
      }
      return result;
    }

    // Возвращаем строковое представление для неизвестных типов
    return value.toString();
  }

  @override
  dynamic deserialize(Uint8List data) {
    try {
      final result = msgpack.deserialize(data);
      return _convertToJsonCompetible(result);
    } catch (e) {
      print('MsgPackSerializer: ошибка при десериализации = $e');
      rethrow;
    }
  }

  /// Преобразует данные после msgpack-десериализации в формат, совместимый с JSON
  dynamic _convertToJsonCompetible(dynamic value) {
    if (value == null) {
      return null;
    }

    // Обработка списков (проверка на бинарные данные)
    if (value is List) {
      // Если список содержит только байты (0-255), преобразуем в Uint8List
      if (_isListOfBytes(value)) {
        return Uint8List.fromList(value.cast<int>());
      }
      return value.map((item) => _convertToJsonCompetible(item)).toList();
    }

    // Обработка карт - ключевой момент: преобразование Map<dynamic, dynamic> в Map<String, dynamic>
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final val = _convertToJsonCompetible(entry.value);
        result[key] = val;
      }
      return result;
    }

    // Остальные типы остаются без изменений
    return value;
  }

  /// Проверяет, является ли список списком байтов (все значения от 0 до 255)
  bool _isListOfBytes(List list) {
    // Если список пуст или слишком большой, не считаем его бинарными данными
    if (list.isEmpty || list.length > 10000) {
      return false;
    }

    // Проверяем все элементы
    for (final item in list) {
      if (item is! int || item < 0 || item > 255) {
        return false;
      }
    }

    return true;
  }

  @override
  String get name => 'msgpack';
}
