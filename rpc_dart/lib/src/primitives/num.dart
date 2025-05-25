// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

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

  /// Создает RpcNum из бинарных данных
  static RpcNum fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return const RpcNum(0);

    // Первый байт - тип: 0 = int, 1 = double
    final type = bytes[0];

    if (type == 0) {
      // Int (4 байта)
      if (bytes.length < 5) return const RpcNum(0);

      final buffer = ByteData.sublistView(bytes, 1, 5);
      final intValue = buffer.getInt32(0, Endian.little);
      return RpcNum(intValue);
    } else {
      // Double (8 байтов)
      if (bytes.length < 9) return const RpcNum(0);

      final buffer = ByteData.sublistView(bytes, 1, 9);
      final doubleValue = buffer.getFloat64(0, Endian.little);
      return RpcNum(doubleValue);
    }
  }

  /// Сериализует в бинарный формат
  @override
  Uint8List serialize() {
    if (value is int) {
      // Для целого числа (тип 0 + 4 байта)
      final result = Uint8List(5);
      result[0] = 0; // тип int

      final buffer = ByteData.view(result.buffer);
      buffer.setInt32(1, value as int, Endian.little);

      return result;
    } else {
      // Для дробного числа (тип 1 + 8 байтов)
      final result = Uint8List(9);
      result[0] = 1; // тип double

      final buffer = ByteData.view(result.buffer);
      buffer.setFloat64(1, value.toDouble(), Endian.little);

      return result;
    }
  }

  @override
  String toString() => value.toString();

  // Арифметические операторы
  RpcNum operator +(Object other) => RpcNum(value + _extractNum(other));
  RpcNum operator -(Object other) => RpcNum(value - _extractNum(other));
  RpcNum operator *(Object other) => RpcNum(value * _extractNum(other));
  RpcNum operator /(Object other) => RpcNum(value / _extractNum(other));
  RpcNum operator ~/(Object other) {
    final a = value;
    final b = _extractNum(other);
    if (a is int && b is int) {
      return RpcNum(a ~/ b);
    }
    throw _comparisonException(type: 'RpcNum', op: '~/');
  }

  RpcNum operator %(Object other) => RpcNum(value % _extractNum(other));
  RpcNum operator -() => RpcNum(-value);

  bool operator <(Object other) {
    if (other is RpcNum) return value < other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcNum', op: '<');
    }
    throw _unsupportedOperand(type: 'RpcNum', op: '<', other: other);
  }

  bool operator >(Object other) {
    if (other is RpcNum) return value > other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcNum', op: '>');
    }
    throw _unsupportedOperand(type: 'RpcNum', op: '>', other: other);
  }

  bool operator <=(Object other) {
    if (other is RpcNum) return value <= other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcNum', op: '<=');
    }
    throw _unsupportedOperand(type: 'RpcNum', op: '<=', other: other);
  }

  bool operator >=(Object other) {
    if (other is RpcNum) return value >= other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcNum', op: '>=');
    }
    throw _unsupportedOperand(type: 'RpcNum', op: '>=', other: other);
  }

  @override
  bool operator ==(Object other) {
    if (other is RpcNum) return value == other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcNum', op: '==');
    }
    return false;
  }

  @override
  int get hashCode => value.hashCode;

  num _extractNum(Object other) {
    if (other is RpcNum) return other.value;
    if (other is RpcInt) return other.value;
    if (other is RpcDouble) return other.value;
    if (other is num) return other;
    throw _unsupportedOperand(type: 'RpcNum', op: 'extract', other: other);
  }
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

  /// Создает RpcInt из бинарных данных
  static RpcInt fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return const RpcInt(0);

    // 4 байта для int
    if (bytes.length < 4) return const RpcInt(0);

    final buffer = ByteData.sublistView(bytes);
    final intValue = buffer.getInt32(0, Endian.little);
    return RpcInt(intValue);
  }

  /// Сериализует в бинарный формат (4 байта)
  @override
  Uint8List serialize() {
    final result = Uint8List(4);
    final buffer = ByteData.view(result.buffer);
    buffer.setInt32(0, value, Endian.little);
    return result;
  }

  @override
  String toString() => value.toString();

  // Арифметические операторы
  RpcInt operator +(Object other) => RpcInt(value + _extractInt(other));
  RpcInt operator -(Object other) => RpcInt(value - _extractInt(other));
  RpcInt operator *(Object other) => RpcInt(value * _extractInt(other));
  RpcInt operator ~/(Object other) => RpcInt(value ~/ _extractInt(other));
  RpcInt operator %(Object other) => RpcInt(value % _extractInt(other));
  RpcDouble operator /(Object other) => RpcDouble(value / _extractInt(other));
  RpcInt operator -() => RpcInt(-value);

  bool operator <(Object other) {
    if (other is RpcInt) return value < other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcInt', op: '<');
    }
    throw _unsupportedOperand(type: 'RpcInt', op: '<', other: other);
  }

  bool operator >(Object other) {
    if (other is RpcInt) return value > other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcInt', op: '>');
    }
    throw _unsupportedOperand(type: 'RpcInt', op: '>', other: other);
  }

  bool operator <=(Object other) {
    if (other is RpcInt) return value <= other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcInt', op: '<=');
    }
    throw _unsupportedOperand(type: 'RpcInt', op: '<=', other: other);
  }

  bool operator >=(Object other) {
    if (other is RpcInt) return value >= other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcInt', op: '>=');
    }
    throw _unsupportedOperand(type: 'RpcInt', op: '>=', other: other);
  }

  @override
  bool operator ==(Object other) {
    if (other is RpcInt) return value == other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcInt', op: '==');
    }
    return false;
  }

  @override
  int get hashCode => value.hashCode;

  int _extractInt(Object other) {
    if (other is RpcInt) return other.value;
    if (other is RpcNum) return other.value.toInt();
    if (other is RpcDouble) return other.value.toInt();
    if (other is int) return other;
    if (other is num) return other.toInt();
    throw _unsupportedOperand(type: 'RpcInt', op: 'extract', other: other);
  }
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

      // Пробуем преобразовать в double
      final asDouble = double.tryParse(v.toString());
      if (asDouble != null) {
        return RpcDouble(asDouble);
      }

      return const RpcDouble(0.0);
    } catch (e) {
      return const RpcDouble(0.0);
    }
  }

  /// Создает RpcDouble из бинарных данных
  static RpcDouble fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return const RpcDouble(0.0);

    // 8 байтов для double
    if (bytes.length < 8) return const RpcDouble(0.0);

    final buffer = ByteData.sublistView(bytes);
    final doubleValue = buffer.getFloat64(0, Endian.little);
    return RpcDouble(doubleValue);
  }

  /// Сериализует в бинарный формат (8 байт)
  @override
  Uint8List serialize() {
    final result = Uint8List(8);
    final buffer = ByteData.view(result.buffer);
    buffer.setFloat64(0, value, Endian.little);
    return result;
  }

  @override
  String toString() => value.toString();

  // Арифметические операторы
  RpcDouble operator +(Object other) =>
      RpcDouble(value + _extractDouble(other));
  RpcDouble operator -(Object other) =>
      RpcDouble(value - _extractDouble(other));
  RpcDouble operator *(Object other) =>
      RpcDouble(value * _extractDouble(other));
  RpcDouble operator /(Object other) =>
      RpcDouble(value / _extractDouble(other));
  RpcDouble operator %(Object other) =>
      RpcDouble(value % _extractDouble(other));
  RpcDouble operator -() => RpcDouble(-value);

  bool operator <(Object other) {
    if (other is RpcDouble) return value < other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcDouble', op: '<');
    }
    throw _unsupportedOperand(type: 'RpcDouble', op: '<', other: other);
  }

  bool operator >(Object other) {
    if (other is RpcDouble) return value > other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcDouble', op: '>');
    }
    throw _unsupportedOperand(type: 'RpcDouble', op: '>', other: other);
  }

  bool operator <=(Object other) {
    if (other is RpcDouble) return value <= other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcDouble', op: '<=');
    }
    throw _unsupportedOperand(type: 'RpcDouble', op: '<=', other: other);
  }

  bool operator >=(Object other) {
    if (other is RpcDouble) return value >= other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcDouble', op: '>=');
    }
    throw _unsupportedOperand(type: 'RpcDouble', op: '>=', other: other);
  }

  @override
  bool operator ==(Object other) {
    if (other is RpcDouble) return value == other.value;
    if (other is num) {
      throw _comparisonException(type: 'RpcDouble', op: '==');
    }
    return false;
  }

  @override
  int get hashCode => value.hashCode;

  double _extractDouble(Object other) {
    if (other is RpcDouble) return other.value;
    if (other is RpcNum) return other.value.toDouble();
    if (other is RpcInt) return other.value.toDouble();
    if (other is double) return other;
    if (other is num) return other.toDouble();
    throw _unsupportedOperand(type: 'RpcDouble', op: 'extract', other: other);
  }
}
