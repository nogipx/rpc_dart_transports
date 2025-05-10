part of '_index.dart';

/// Обертка для словаря, использующая DelegatingMap
class RpcMap extends DelegatingMap<String, IRpcSerializableMessage>
    implements IRpcSerializableMessage {
  /// Создает RpcMap из карты
  RpcMap(Map<String, IRpcSerializableMessage> map)
      : super(Map<String, IRpcSerializableMessage>.from(map));

  /// Создает RpcMap из обычной карты
  static RpcMap from(Map<String, dynamic> map) {
    final result = <String, IRpcSerializableMessage>{};

    map.forEach((key, value) {
      if (value is IRpcSerializableMessage) {
        result[key] = value;
      } else {
        throw ArgumentError(
            'Значение для ключа "$key" должно быть типа IRpcSerializableMessage, '
            'но получено ${value.runtimeType}. Используйте RpcInt, RpcString и другие '
            'явные обёртки для примитивных типов.');
      }
    });

    return RpcMap(result);
  }

  /// Создает RpcMap из JSON c конвертером для элементов
  factory RpcMap.fromJsonWithConverter(
    Map<String, dynamic> json, {
    required String Function(dynamic) keyConverter,
    required IRpcSerializableMessage Function(dynamic) valueConverter,
  }) {
    try {
      final map = json['v'] as Map?;
      if (map == null) {
        return RpcMap({});
      }

      final result = <String, IRpcSerializableMessage>{};
      map.forEach((key, value) {
        final convertedKey = keyConverter(key);
        final convertedValue = valueConverter(value);
        result[convertedKey] = convertedValue;
      });

      return RpcMap(result);
    } catch (e) {
      return RpcMap({});
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final convertedMap = <String, dynamic>{};

    forEach((key, item) {
      final String keyStr = key.toString();
      convertedMap[keyStr] = (item).toJson();
    });

    return {'v': convertedMap};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RpcMap) return false;

    return const MapEquality().equals(this, other);
  }

  @override
  int get hashCode => const MapEquality().hash(this);

  /// Предоставляет доступ к внутреннему словарю для удобного использования
  Map<String, IRpcSerializableMessage> get asMap => this;

  @override
  String toString() => toJson().toString();

  /// Создает карту с сериализуемыми значениями из JSON
  /// Этот метод специально для RpcMap<String, IRpcSerializableMessage>
  static RpcMap fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return RpcMap({});
    }

    final valueMap = json['v'];
    if (valueMap == null || valueMap is! Map) {
      return RpcMap({});
    }

    final result = <String, IRpcSerializableMessage>{};

    valueMap.forEach((key, value) {
      final keyStr = key.toString();

      if (value is Map<String, dynamic> && value.containsKey('v')) {
        final val = value['v'];

        if (val is int) {
          result[keyStr] = RpcInt.fromJson(value);
        } else if (val is double) {
          result[keyStr] = RpcDouble.fromJson(value);
        } else if (val is String) {
          result[keyStr] = RpcString.fromJson(value);
        } else if (val is bool) {
          result[keyStr] = RpcBool.fromJson(value);
        } else if (val is List) {
          // Обработка списков значений
          final listItems = <IRpcSerializableMessage>[];
          for (final item in val) {
            if (item is Map<String, dynamic> && item.containsKey('v')) {
              final itemValue = item['v'];
              if (itemValue is int) {
                listItems.add(RpcInt.fromJson(item));
              } else if (itemValue is double) {
                listItems.add(RpcDouble.fromJson(item));
              } else if (itemValue is String) {
                listItems.add(RpcString.fromJson(item));
              } else if (itemValue is bool) {
                listItems.add(RpcBool.fromJson(item));
              } else {
                listItems.add(RpcString(itemValue.toString()));
              }
            } else if (item is String) {
              listItems.add(RpcString(item));
            } else if (item is int) {
              listItems.add(RpcInt(item));
            } else if (item is double) {
              listItems.add(RpcDouble(item));
            } else if (item is bool) {
              listItems.add(RpcBool(item));
            } else if (item == null) {
              listItems.add(const RpcNull());
            } else {
              listItems.add(RpcString(item.toString()));
            }
          }
          result[keyStr] = RpcList(listItems);
        } else if (val is Map) {
          // Рекурсивно обрабатываем вложенные карты
          final nestedMap = <String, IRpcSerializableMessage>{};
          val.forEach((nestedKey, nestedValue) {
            final nestedKeyStr = nestedKey.toString();

            if (nestedValue is Map && nestedValue.containsKey('v')) {
              final nestedVal = nestedValue['v'];
              if (nestedVal is int) {
                nestedMap[nestedKeyStr] =
                    RpcInt.fromJson(nestedValue as Map<String, dynamic>);
              } else if (nestedVal is double) {
                nestedMap[nestedKeyStr] =
                    RpcDouble.fromJson(nestedValue as Map<String, dynamic>);
              } else if (nestedVal is String) {
                nestedMap[nestedKeyStr] =
                    RpcString.fromJson(nestedValue as Map<String, dynamic>);
              } else if (nestedVal is bool) {
                nestedMap[nestedKeyStr] =
                    RpcBool.fromJson(nestedValue as Map<String, dynamic>);
              } else {
                nestedMap[nestedKeyStr] = RpcString(nestedVal.toString());
              }
            } else {
              nestedMap[nestedKeyStr] = RpcString(nestedValue.toString());
            }
          });
          result[keyStr] = RpcMap(nestedMap);
        } else if (val == null) {
          result[keyStr] = const RpcNull();
        } else {
          result[keyStr] = RpcString(val.toString());
        }
      } else if (value is Map) {
        // Обрабатываем вложенные структуры без поля 'v'
        try {
          final nestedMap = RpcMap.fromJson({'v': value});
          result[keyStr] = nestedMap;
        } catch (e) {
          // Если вложенная структура некорректна, используем строковое представление
          result[keyStr] = RpcString(value.toString());
        }
      } else if (value == null) {
        // Обработка null значений
        result[keyStr] = const RpcNull();
      } else if (value is String) {
        result[keyStr] = RpcString(value);
      } else if (value is int) {
        result[keyStr] = RpcInt(value);
      } else if (value is double) {
        result[keyStr] = RpcDouble(value);
      } else if (value is bool) {
        result[keyStr] = RpcBool(value);
      } else {
        // Если структура совсем не та, что ожидалась, хотя бы создаем строку
        result[keyStr] = RpcString(value.toString());
      }
    });

    return RpcMap(result);
  }
}
