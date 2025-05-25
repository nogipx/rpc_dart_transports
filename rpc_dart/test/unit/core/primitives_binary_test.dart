// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:test/test.dart';
import 'package:rpc_dart/rpc_dart.dart';
import 'package:rpc_dart/src/primitives/_index.dart';

void main() {
  group('Бинарная сериализация примитивов', () {
    test('RpcBool - сериализация/десериализация', () {
      // true
      final boolTrue = RpcBool(true);
      final serializedTrue = boolTrue.serialize();
      expect(serializedTrue.length, 1);
      expect(serializedTrue[0], 1);
      final deserializedTrue = RpcBool.fromBytes(serializedTrue);
      expect(deserializedTrue.value, true);

      // false
      final boolFalse = RpcBool(false);
      final serializedFalse = boolFalse.serialize();
      expect(serializedFalse.length, 1);
      expect(serializedFalse[0], 0);
      final deserializedFalse = RpcBool.fromBytes(serializedFalse);
      expect(deserializedFalse.value, false);
    });

    test('RpcNull - сериализация/десериализация', () {
      final nullValue = RpcNull();
      final serialized = nullValue.serialize();
      expect(serialized.length, 0);
      final deserialized = RpcNull.fromBytes(serialized);
      expect(deserialized, nullValue);
    });

    test('RpcString - сериализация/десериализация', () {
      final values = [
        'Привет, мир!',
        'Hello, world!',
        '1234567890',
        '!@#\$%^&*()',
        '',
      ];

      for (final value in values) {
        final stringValue = RpcString(value);
        final serialized = stringValue.serialize();
        final deserialized = RpcString.fromBytes(serialized);
        expect(deserialized.value, value);
      }
    });

    test('RpcInt - сериализация/десериализация', () {
      final values = [
        0,
        1,
        -1,
        123456,
        -123456,
        2147483647, // max int32
        -2147483648, // min int32
      ];

      for (final value in values) {
        final intValue = RpcInt(value);
        final serialized = intValue.serialize();
        expect(serialized.length, 4); // 4 байта для int
        final deserialized = RpcInt.fromBytes(serialized);
        expect(deserialized.value, value);
      }
    });

    test('RpcDouble - сериализация/десериализация', () {
      final values = [
        0.0,
        1.0,
        -1.0,
        3.14159,
        -3.14159,
        1234.5678,
        -1234.5678,
        double.maxFinite / 2,
        double.minPositive * 100,
      ];

      for (final value in values) {
        final doubleValue = RpcDouble(value);
        final serialized = doubleValue.serialize();
        expect(serialized.length, 8); // 8 байтов для double
        final deserialized = RpcDouble.fromBytes(serialized);
        expect(deserialized.value, value);
      }
    });

    test('RpcNum - сериализация/десериализация целых чисел', () {
      final values = [
        0,
        1,
        -1,
        123456,
        -123456,
      ];

      for (final value in values) {
        final numValue = RpcNum(value);
        final serialized = numValue.serialize();
        expect(serialized.length, 5); // 1 байт тип + 4 байта значение
        expect(serialized[0], 0); // тип int
        final deserialized = RpcNum.fromBytes(serialized);
        expect(deserialized.value, value);
      }
    });

    test('RpcNum - сериализация/десериализация дробных чисел', () {
      final values = [
        0.5,
        3.14,
        -2.71,
        123.456,
        -987.654,
      ];

      for (final value in values) {
        final numValue = RpcNum(value);
        final serialized = numValue.serialize();
        expect(serialized.length, 9); // 1 байт тип + 8 байтов значение
        expect(serialized[0], 1); // тип double
        final deserialized = RpcNum.fromBytes(serialized);
        expect(deserialized.value, value);
      }
    });
  });
}
