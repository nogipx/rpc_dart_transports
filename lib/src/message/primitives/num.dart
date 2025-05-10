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

  @override
  Map<String, dynamic> toJson() => {'v': value};

  @override
  String toString() => toJson().toString();

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
    throw UnsupportedError('Operator ~/ is only supported for int operands');
  }

  RpcNum operator %(Object other) => RpcNum(value % _extractNum(other));
  RpcNum operator -() => RpcNum(-value);

  bool operator <(Object other) {
    if (other is RpcNum) return value < other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcNum с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  bool operator >(Object other) {
    if (other is RpcNum) return value > other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcNum с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  bool operator <=(Object other) {
    if (other is RpcNum) return value <= other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcNum с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  bool operator >=(Object other) {
    if (other is RpcNum) return value >= other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcNum с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  @override
  bool operator ==(Object other) {
    if (other is RpcNum) return value == other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcNum с примитивным типом запрещено. Используйте value для сравнения значений.');
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
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
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

  @override
  Map<String, dynamic> toJson() => {'v': value};

  @override
  String toString() => toJson().toString();

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
      throw UnsupportedError(
          'Сравнение RpcInt с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  bool operator >(Object other) {
    if (other is RpcInt) return value > other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcInt с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  bool operator <=(Object other) {
    if (other is RpcInt) return value <= other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcInt с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  bool operator >=(Object other) {
    if (other is RpcInt) return value >= other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcInt с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  @override
  bool operator ==(Object other) {
    if (other is RpcInt) return value == other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcInt с примитивным типом запрещено. Используйте value для сравнения значений.');
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
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
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
      return RpcDouble(double.tryParse(v.toString()) ?? 0.0);
    } catch (e) {
      return const RpcDouble(0.0);
    }
  }

  @override
  Map<String, dynamic> toJson() => {'v': value};

  @override
  String toString() => toJson().toString();

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
      throw UnsupportedError(
          'Сравнение RpcDouble с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  bool operator >(Object other) {
    if (other is RpcDouble) return value > other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcDouble с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  bool operator <=(Object other) {
    if (other is RpcDouble) return value <= other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcDouble с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  bool operator >=(Object other) {
    if (other is RpcDouble) return value >= other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcDouble с примитивным типом запрещено. Используйте value для сравнения значений.');
    }
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }

  @override
  bool operator ==(Object other) {
    if (other is RpcDouble) return value == other.value;
    if (other is num) {
      throw UnsupportedError(
          'Сравнение RpcDouble с примитивным типом запрещено. Используйте value для сравнения значений.');
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
    throw ArgumentError('Unsupported operand type: ${other.runtimeType}');
  }
}
