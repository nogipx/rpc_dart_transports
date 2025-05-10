// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import '../contracts/_contract.dart';
import 'package:collection/collection.dart';

/// Базовый класс для всех примитивных типов сообщений
abstract class RpcPrimitiveMessage<T> implements IRpcSerializableMessage {
  final T value;

  const RpcPrimitiveMessage(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RpcPrimitiveMessage<T> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

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
}

/// Обертка для целочисленного значения
class RpcInt extends RpcPrimitiveMessage<int> {
  const RpcInt(super.value);

  /// Создает RpcInt из JSON
  factory RpcInt.fromJson(Map<String, dynamic> json) {
    try {
      final v = json['v'];
      if (v == null) return const RpcInt(0);
      if (v is int) return RpcInt(v);
      if (v is num) return RpcInt(v.toInt());
      return RpcInt(int.tryParse(v.toString()) ?? 0);
    } catch (e) {
      return const RpcInt(0);
    }
  }

  @override
  Map<String, dynamic> toJson() => {'v': value};
}

/// Обертка для булевого значения
class RpcBool extends RpcPrimitiveMessage<bool> {
  const RpcBool(super.value);

  /// Создает RpcBool из JSON
  factory RpcBool.fromJson(Map<String, dynamic> json) {
    try {
      final v = json['v'];
      if (v == null) return const RpcBool(false);
      if (v is bool) return RpcBool(v);

      // Преобразование числовых значений
      if (v is num) return RpcBool(v != 0);

      // Преобразование строковых значений
      final vStr = v.toString().toLowerCase().trim();
      if (vStr == 'true' || vStr == '1') return const RpcBool(true);
      if (vStr == 'false' || vStr == '0') return const RpcBool(false);

      // Для всех других случаев
      return const RpcBool(false);
    } catch (e) {
      return const RpcBool(false);
    }
  }

  @override
  Map<String, dynamic> toJson() => {'v': value};
}

/// Обертка для списка значений, использующая DelegatingList
class RpcList<E> extends DelegatingList<E> implements IRpcSerializableMessage {
  /// Создает RpcList из списка
  RpcList(List<E> list) : super(List<E>.from(list));

  /// Создает RpcList из JSON, предполагая что элементы уже правильного типа
  factory RpcList.fromJson(Map<String, dynamic> json) {
    try {
      final list = json['v'] as List?;
      if (list == null) {
        return RpcList<E>([]);
      }
      return RpcList<E>(list.cast<E>());
    } catch (e) {
      // Если что-то пошло не так, возвращаем пустой список
      return RpcList<E>([]);
    }
  }

  /// Создает RpcList из JSON с конвертером для элементов
  factory RpcList.withConverter(
    Map<String, dynamic> json,
    E Function(dynamic) itemFromJson,
  ) {
    try {
      final list = json['v'] as List?;
      if (list == null) {
        return RpcList<E>([]);
      }
      return RpcList<E>(list.map((item) => itemFromJson(item)).toList());
    } catch (e) {
      // Если что-то пошло не так, возвращаем пустой список
      return RpcList<E>([]);
    }
  }

  /// Создает RpcList из обычного списка
  static RpcList<T> from<T>(List<T> list) {
    return RpcList<T>(List<T>.from(list));
  }

  @override
  Map<String, dynamic> toJson() {
    final convertedList = map((item) {
      if (item is IRpcSerializableMessage) {
        return (item as IRpcSerializableMessage).toJson();
      }
      return item;
    }).toList();

    return {'v': convertedList};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RpcList<E>) return false;

    return const ListEquality().equals(this, other);
  }

  @override
  int get hashCode => const ListEquality().hash(this);
}

/// Обертка для словаря, использующая DelegatingMap
class RpcMap<K, V> extends DelegatingMap<K, V>
    implements IRpcSerializableMessage {
  /// Создает RpcMap из карты
  RpcMap(Map<K, V> map) : super(Map<K, V>.from(map));

  /// Создает RpcMap из обычной карты
  static RpcMap<K, V> from<K, V>(Map<K, V> map) {
    return RpcMap<K, V>(Map<K, V>.from(map));
  }

  /// Создает RpcMap из JSON c конвертером для элементов
  factory RpcMap.fromJsonWithConverter(
    Map<String, dynamic> json, {
    required K Function(dynamic) keyConverter,
    required V Function(dynamic) valueConverter,
  }) {
    try {
      final map = json['v'] as Map?;
      if (map == null) {
        return RpcMap<K, V>({});
      }

      final result = <K, V>{};
      map.forEach((key, value) {
        final convertedKey = keyConverter(key);
        final convertedValue = valueConverter(value);
        result[convertedKey] = convertedValue;
      });

      return RpcMap<K, V>(result);
    } catch (e) {
      return RpcMap<K, V>({});
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final convertedMap = <String, dynamic>{};

    forEach((key, item) {
      final String keyStr = key.toString();
      if (item is IRpcSerializableMessage) {
        convertedMap[keyStr] = (item as IRpcSerializableMessage).toJson();
      } else {
        convertedMap[keyStr] = item;
      }
    });

    return {'v': convertedMap};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RpcMap<K, V>) return false;

    return const MapEquality().equals(this, other);
  }

  @override
  int get hashCode => const MapEquality().hash(this);

  /// Создает карту с сериализуемыми значениями из JSON
  /// Этот метод специально для RpcMap<String, IRpcSerializableMessage>
  static RpcMap<String, IRpcSerializableMessage> fromJson(
      Map<String, dynamic>? json) {
    if (json == null) {
      return RpcMap<String, IRpcSerializableMessage>({});
    }

    final valueMap = json['v'];
    if (valueMap == null || valueMap is! Map) {
      return RpcMap<String, IRpcSerializableMessage>({});
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
          result[keyStr] = RpcMap<String, IRpcSerializableMessage>(nestedMap);
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

    return RpcMap<String, IRpcSerializableMessage>(result);
  }

  /// Предоставляет доступ к внутреннему словарю для удобного использования
  Map<K, V> get asMap => this;
}

/// Обертка для дробного числа
class RpcDouble extends RpcPrimitiveMessage<double> {
  const RpcDouble(super.value);

  /// Создает RpcDouble из JSON
  factory RpcDouble.fromJson(Map<String, dynamic> json) {
    try {
      final v = json['v'];
      if (v == null) return const RpcDouble(0.0);
      if (v is double) return RpcDouble(v);
      if (v is num) return RpcDouble(v.toDouble());
      return RpcDouble(double.tryParse(v.toString()) ?? 0.0);
    } catch (e) {
      return const RpcDouble(0.0);
    }
  }

  @override
  Map<String, dynamic> toJson() => {'v': value};
}

/// Обертка для числового значения
class RpcNum extends RpcPrimitiveMessage<num> {
  const RpcNum(super.value);

  /// Создает RpcNum из JSON
  factory RpcNum.fromJson(Map<String, dynamic> json) {
    try {
      final v = json['v'];
      if (v == null) return const RpcNum(0);
      if (v is num) return RpcNum(v);

      // Пробуем преобразовать в число
      final asDouble = double.tryParse(v.toString());
      if (asDouble != null) {
        // Если это целое число, преобразуем в int
        if (asDouble == asDouble.toInt()) {
          return RpcNum(asDouble.toInt());
        }
        return RpcNum(asDouble);
      }

      return const RpcNum(0);
    } catch (e) {
      return const RpcNum(0);
    }
  }

  @override
  Map<String, dynamic> toJson() => {'v': value};
}

/// Обертка для null
class RpcNull extends RpcPrimitiveMessage<void> {
  const RpcNull() : super(null);

  /// Создает RpcNull из JSON (в любом случае возвращает RpcNull)
  factory RpcNull.fromJson(Map<String, dynamic> json) {
    return const RpcNull();
  }

  @override
  Map<String, dynamic> toJson() => {'v': null};
}
