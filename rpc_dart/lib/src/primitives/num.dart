// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

part of '_index.dart';

/// Обертка для числового значения
class RpcNum extends RpcPrimitiveMessage<num> {
  const RpcNum(super.value);

  /// Создает RpcNum из бинарных данных
  static RpcNum fromBytes(Uint8List bytes) {
    return RpcNum(CborCodec.decode(bytes));
  }

  /// Сериализует в бинарный формат
  @override
  Uint8List serialize() {
    return CborCodec.encode(value);
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

  /// Создает RpcInt из бинарных данных
  static RpcInt fromBytes(Uint8List bytes) {
    return RpcInt(CborCodec.decode(bytes));
  }

  /// Сериализует в бинарный формат (4 байта)
  @override
  Uint8List serialize() {
    return CborCodec.encode(value);
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

  /// Создает RpcDouble из бинарных данных
  static RpcDouble fromBytes(Uint8List bytes) {
    return RpcDouble(CborCodec.decode(bytes));
  }

  /// Сериализует в бинарный формат (8 байт)
  @override
  Uint8List serialize() {
    return CborCodec.encode(value);
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
