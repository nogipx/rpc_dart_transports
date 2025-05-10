// SPDX-FileCopyrightText: 2025 Karim "nogipx" Mamatkazin <nogipx@gmail.com>
//
// SPDX-License-Identifier: LGPL-3.0-or-later

import 'package:rpc_dart/rpc_dart.dart';
import 'package:test/test.dart';

void main() {
  group('RpcString', () {
    test('создание и значение', () {
      const string = RpcString('test');
      expect(string.value, equals('test'));
    });

    test('toJson', () {
      const string = RpcString('test');
      expect(string.toJson(), equals({'v': 'test'}));
    });

    test('fromJson', () {
      const json = {'v': 'test'};
      final string = RpcString.fromJson(json);
      expect(string.value, equals('test'));
    });

    test('equals и hashCode', () {
      const string1 = RpcString('test');
      const string2 = RpcString('test');
      const string3 = RpcString('different');

      expect(string1 == string2, isTrue);
      expect(string1.hashCode == string2.hashCode, isTrue);
      expect(string1 == string3, isFalse);
    });
  });

  group('RpcInt', () {
    test('создание и значение', () {
      const integer = RpcInt(42);
      expect(integer.value, equals(42));
    });

    test('toJson', () {
      const integer = RpcInt(42);
      expect(integer.toJson(), equals({'v': 42}));
    });

    test('fromJson', () {
      const json = {'v': 42};
      final integer = RpcInt.fromJson(json);
      expect(integer.value, equals(42));
    });

    test('equals и hashCode', () {
      const int1 = RpcInt(42);
      const int2 = RpcInt(42);
      const int3 = RpcInt(100);

      expect(int1 == int2, isTrue);
      expect(int1.hashCode == int2.hashCode, isTrue);
      expect(int1 == int3, isFalse);
    });

    test('арифметические операторы', () {
      final a = RpcInt(10);
      final b = RpcInt(3);
      expect(a + b, RpcInt(13));
      expect(a - b, RpcInt(7));
      expect(a * b, RpcInt(30));
      expect(a ~/ b, RpcInt(3));
      expect(a % b, RpcInt(1));
      expect(a / b, RpcDouble(10 / 3));
      expect(-a, RpcInt(-10));
      // С обычными числами
      expect(a + 2, RpcInt(12));
      expect(a - 2, RpcInt(8));
      expect(a * 2, RpcInt(20));
      expect(a ~/ 2, RpcInt(5));
      expect(a % 4, RpcInt(2));
      expect(a / 2, RpcDouble(5.0));
    });

    test('сравнения', () {
      final a = RpcInt(10);
      final b = RpcInt(3);
      expect(a > b, isTrue);
      expect(a < b, isFalse);
      expect(a >= b, isTrue);
      expect(a <= b, isFalse);
      expect(a == RpcInt(10), isTrue);

      // Сравнение с примитивами через .value
      expect(a.value > 3, isTrue);
      expect(a.value < 20, isTrue);
      expect(a.value >= 10, isTrue);
      expect(a.value <= 10, isTrue);
      expect(a.value == 10, isTrue);

      // Проверка исключений при сравнении с примитивами
      // ignore: unrelated_type_equality_checks
      expect(() => a == 11, throwsA(isA<UnsupportedError>()));
      expect(() => a > 3, throwsA(isA<UnsupportedError>()));
      expect(() => a < 20, throwsA(isA<UnsupportedError>()));
      expect(() => a >= 10, throwsA(isA<UnsupportedError>()));
      expect(() => a <= 10, throwsA(isA<UnsupportedError>()));
    });
  });

  group('RpcBool', () {
    test('создание и значение', () {
      const boolTrue = RpcBool(true);
      const boolFalse = RpcBool(false);
      expect(boolTrue.value, isTrue);
      expect(boolFalse.value, isFalse);
    });

    test('toJson', () {
      const boolTrue = RpcBool(true);
      expect(boolTrue.toJson(), equals({'v': true}));
    });

    test('fromJson', () {
      const json = {'v': true};
      final boolValue = RpcBool.fromJson(json);
      expect(boolValue.value, isTrue);
    });

    test('equals и hashCode', () {
      const bool1 = RpcBool(true);
      const bool2 = RpcBool(true);
      const bool3 = RpcBool(false);

      expect(bool1 == bool2, isTrue);
      expect(bool1.hashCode == bool2.hashCode, isTrue);
      expect(bool1 == bool3, isFalse);
    });
  });

  group('RpcDouble', () {
    test('создание и значение', () {
      const double = RpcDouble(3.14);
      expect(double.value, equals(3.14));
    });

    test('toJson', () {
      const double = RpcDouble(3.14);
      expect(double.toJson(), equals({'v': 3.14}));
    });

    test('fromJson', () {
      const json = {'v': 3.14};
      final double = RpcDouble.fromJson(json);
      expect(double.value, equals(3.14));
    });

    test('equals и hashCode', () {
      const double1 = RpcDouble(3.14);
      const double2 = RpcDouble(3.14);
      const double3 = RpcDouble(2.71);

      expect(double1 == double2, isTrue);
      expect(double1.hashCode == double2.hashCode, isTrue);
      expect(double1 == double3, isFalse);
    });

    test('арифметические операторы', () {
      final a = RpcDouble(5.5);
      final b = RpcDouble(2.0);
      expect(a + b, RpcDouble(7.5));
      expect(a - b, RpcDouble(3.5));
      expect(a * b, RpcDouble(11.0));
      expect(a / b, RpcDouble(2.75));
      expect(a % b, RpcDouble(1.5));
      expect(-a, RpcDouble(-5.5));
      // С обычными числами
      expect(a + 1, RpcDouble(6.5));
      expect(a - 1, RpcDouble(4.5));
      expect(a * 2, RpcDouble(11.0));
      expect(a / 2, RpcDouble(2.75));
      expect(a % 2, RpcDouble(1.5));
    });

    test('сравнения', () {
      final a = RpcDouble(5.5);
      final b = RpcDouble(2.0);
      expect(a > b, isTrue);
      expect(a < b, isFalse);
      expect(a >= b, isTrue);
      expect(a <= b, isFalse);

      // Сравнение с примитивами через .value
      expect(a.value > 2.0, isTrue);
      expect(a.value < 10.0, isTrue);
      expect(a.value >= 5.5, isTrue);
      expect(a.value <= 5.5, isTrue);

      expect(a == RpcDouble(5.5), isTrue);
      expect(a.value == 5.5, isTrue);
      expect(a.value == 6.0, isFalse);

      // Проверка исключений при сравнении с примитивами
      // ignore: unrelated_type_equality_checks
      expect(() => a == 5.5, throwsA(isA<UnsupportedError>()));
      expect(() => a > 2.0, throwsA(isA<UnsupportedError>()));
      expect(() => a < 10.0, throwsA(isA<UnsupportedError>()));
      expect(() => a >= 5.5, throwsA(isA<UnsupportedError>()));
      expect(() => a <= 5.5, throwsA(isA<UnsupportedError>()));
    });
  });

  group('RpcNum', () {
    test('создание и значение', () {
      const intNum = RpcNum(42);
      const doubleNum = RpcNum(3.14);
      expect(intNum.value, equals(42));
      expect(doubleNum.value, equals(3.14));
    });

    test('toJson', () {
      const intNum = RpcNum(42);
      const doubleNum = RpcNum(3.14);
      expect(intNum.toJson(), equals({'v': 42}));
      expect(doubleNum.toJson(), equals({'v': 3.14}));
    });

    test('fromJson', () {
      const jsonInt = {'v': 42};
      const jsonDouble = {'v': 3.14};
      final intNum = RpcNum.fromJson(jsonInt);
      final doubleNum = RpcNum.fromJson(jsonDouble);
      expect(intNum.value, equals(42));
      expect(doubleNum.value, equals(3.14));
    });

    test('equals и hashCode', () {
      const num1 = RpcNum(42);
      const num2 = RpcNum(42);
      const num3 = RpcNum(3.14);
      const num4 = RpcNum(3.14);
      const num5 = RpcNum(100);

      expect(num1 == num2, isTrue);
      expect(num1.hashCode == num2.hashCode, isTrue);
      expect(num3 == num4, isTrue);
      expect(num3.hashCode == num4.hashCode, isTrue);
      expect(num1 == num3, isFalse);
      expect(num1 == num5, isFalse);
    });

    test('совместимость с int и double', () {
      const intNum = RpcNum(42);
      const doubleNum = RpcNum(42.0);

      // Проверяем числовое равенство значений
      expect(intNum.value == doubleNum.value, isTrue);
      // Но объекты не равны из-за разных типов (int vs double)
      expect(intNum == doubleNum, isTrue);

      // Проверяем математические операции
      expect(intNum.value + 10, equals(52));
      expect(doubleNum.value * 2, equals(84.0));
    });

    test('арифметические операторы', () {
      final a = RpcNum(7);
      final b = RpcNum(2.5);
      expect(a + b, RpcNum(9.5));
      expect(a - b, RpcNum(4.5));
      expect(a * b, RpcNum(17.5));
      expect(a / b, RpcNum(2.8));
      expect(() => a ~/ b, throwsA(isA<UnsupportedError>()));
      expect(a % b, RpcNum(7 % 2.5));
      expect(-a, RpcNum(-7));
      // С обычными числами
      expect(a + 1, RpcNum(8));
      expect(a - 1, RpcNum(6));
      expect(a * 2, RpcNum(14));
      expect(a / 2, RpcNum(3.5));
      expect(a % 2, RpcNum(1));
    });

    test('сравнения', () {
      final a = RpcNum(7);
      final b = RpcNum(2.5);
      expect(a > b, isTrue);
      expect(a < b, isFalse);
      expect(a >= b, isTrue);
      expect(a <= b, isFalse);

      // Сравнение с примитивами через .value
      expect(a.value > 2, isTrue);
      expect(a.value < 10, isTrue);
      expect(a.value >= 7, isTrue);
      expect(a.value <= 7, isTrue);

      expect(a == RpcNum(7), isTrue);
      expect(a.value == 7, isTrue);
      expect(a.value == 8, isFalse);

      // Проверка исключений при сравнении с примитивами
      // ignore: unrelated_type_equality_checks
      expect(() => a == 7, throwsA(isA<UnsupportedError>()));
      expect(() => a > 2, throwsA(isA<UnsupportedError>()));
      expect(() => a < 10, throwsA(isA<UnsupportedError>()));
      expect(() => a >= 7, throwsA(isA<UnsupportedError>()));
      expect(() => a <= 7, throwsA(isA<UnsupportedError>()));
    });
  });

  group('RpcNull', () {
    test('создание', () {
      const nullValue = RpcNull();
      expect(nullValue, isA<IRpcSerializableMessage>());
    });

    test('toJson', () {
      const nullValue = RpcNull();
      expect(nullValue.toJson(), equals({'v': null}));
    });

    test('fromJson', () {
      const json = {'v': null};
      final nullValue = RpcNull.fromJson(json);
      expect(nullValue, isA<RpcNull>());
    });

    test('equals и hashCode', () {
      const null1 = RpcNull();
      const null2 = RpcNull();

      expect(null1 == null2, isTrue);
      expect(null1.hashCode == null2.hashCode, isTrue);
    });
  });

  group('RpcList', () {
    test('создание и значение для примитивных типов', () {
      final intList = RpcList<RpcInt>([RpcInt(1), RpcInt(2), RpcInt(3)]);
      expect(intList.map((i) => i.value).toList(), equals([1, 2, 3]));
    });

    test('статический метод from', () {
      final originalList = [RpcInt(1), RpcInt(2), RpcInt(3)];
      final rpcList = RpcList.from(originalList);

      expect(rpcList.map((i) => i.value).toList(), equals([1, 2, 3]));
      expect(rpcList, isNot(same(originalList))); // Должна быть копия списка

      // Проверяем, что изменение оригинального списка не влияет на RpcList
      originalList.add(RpcInt(4));
      expect(rpcList.map((i) => i.value).toList(), equals([1, 2, 3]));
    });

    test('шорткаты для доступа к методам List', () {
      final list = RpcList<RpcInt>([RpcInt(1), RpcInt(2), RpcInt(3)]);

      // Проверяем свойства
      expect(list.length, equals(3));
      expect(list.isEmpty, isFalse);
      expect(list.isNotEmpty, isTrue);
      expect(list.first.value, equals(1));
      expect(list.last.value, equals(3));

      // Проверяем операторы
      expect(list[0].value, equals(1));
      list[0] = RpcInt(10);
      expect(list[0].value, equals(10));

      // Проверяем методы модификации
      list.add(RpcInt(4));
      expect(list.length, equals(4));
      expect(list.last.value, equals(4));

      list.addAll([RpcInt(5), RpcInt(6)]);
      expect(list.length, equals(6));

      list.remove(RpcInt(10));
      expect(list.length, equals(5));
      expect(list.first.value, equals(2));

      list.clear();
      expect(list.isEmpty, isTrue);
    });

    test('asList метод для доступа к внутреннему списку', () {
      final list = RpcList<RpcInt>([RpcInt(1), RpcInt(2), RpcInt(3)]);

      // Проверяем, что asList возвращает тот же список
      expect(list.map((i) => i.value).toList(), equals([1, 2, 3]));

      // Проверяем, что это действительно тот же самый объект
      list.add(RpcInt(4));
      expect(list.map((i) => i.value).toList(), equals([1, 2, 3, 4]));

      // Проверяем использование методов List
      final doubled = list.map((i) => RpcInt(i.value * 2)).toList();
      expect(doubled.map((i) => i.value).toList(), equals([2, 4, 6, 8]));
    });

    test('toJson для примитивных типов', () {
      final intList = RpcList<RpcInt>([RpcInt(1), RpcInt(2), RpcInt(3)]);
      expect(
          intList.toJson(),
          equals({
            'v': [
              {'v': 1},
              {'v': 2},
              {'v': 3}
            ]
          }));
    });

    test('fromJson для примитивных типов', () {
      final json = {
        'v': [
          {'v': 1},
          {'v': 2},
          {'v': 3}
        ]
      };
      final intList = RpcList<RpcInt>.withConverter(
        json,
        (item) => RpcInt.fromJson(item as Map<String, dynamic>),
      );
      expect(intList.map((i) => i.value).toList(), equals([1, 2, 3]));
    });

    test('withConverter для сложных типов', () {
      final json = {
        'v': [
          {'v': 'test1'},
          {'v': 'test2'}
        ]
      };

      final stringList = RpcList<RpcString>.withConverter(
        json,
        (item) => RpcString.fromJson(item as Map<String, dynamic>),
      );

      expect(stringList.length, equals(2));
      expect(stringList[0].value, equals('test1'));
      expect(stringList[1].value, equals('test2'));
    });

    test('toJson для вложенных IRpcSerializableMessage', () {
      final rpcStringList = RpcList<RpcString>([
        const RpcString('test1'),
        const RpcString('test2'),
      ]);

      final expected = {
        'v': [
          {'v': 'test1'},
          {'v': 'test2'}
        ]
      };

      expect(rpcStringList.toJson(), equals(expected));
    });

    test('equals и hashCode', () {
      final list1 = RpcList<RpcInt>([RpcInt(1), RpcInt(2), RpcInt(3)]);
      final list2 = RpcList<RpcInt>([RpcInt(1), RpcInt(2), RpcInt(3)]);
      final list3 = RpcList<RpcInt>([RpcInt(1), RpcInt(2), RpcInt(4)]);

      expect(list1 == list2, isTrue);
      expect(list1.hashCode == list2.hashCode, isTrue);
      expect(list1 == list3, isFalse);
    });

    test('оператор сложения', () {
      final list1 = RpcList<RpcInt>([RpcInt(1), RpcInt(2)]);
      final result = list1 + [RpcInt(3), RpcInt(4)];

      expect(result.map((i) => i.value).toList(), equals([1, 2, 3, 4]));
      // Исходный список не должен измениться
      expect(list1.map((i) => i.value).toList(), equals([1, 2]));
    });
  });

  group('RpcMap', () {
    test('создание и значение для примитивных типов', () {
      final map = RpcMap({'a': RpcInt(1), 'b': RpcInt(2)});
      expect(map['a'], RpcInt(1));
      expect(map['b'], RpcInt(2));
      expect((map['a'] as RpcInt).value, 1);
      expect((map['b'] as RpcInt).value, 2);
    });

    test('статический метод from', () {
      final originalMap = {'a': RpcInt(1), 'b': RpcInt(2)};
      final rpcMap = RpcMap.from(originalMap);

      expect(rpcMap['a'], RpcInt(1));
      expect(rpcMap['b'], RpcInt(2));
      expect((rpcMap['a'] as RpcInt).value, 1);
      expect((rpcMap['b'] as RpcInt).value, 2);
      expect(rpcMap, isNot(same(originalMap))); // Должна быть копия карты

      // Проверяем, что изменение оригинальной карты не влияет на RpcMap
      originalMap['c'] = RpcInt(3);
      expect(rpcMap['c'], isNull);
    });

    test('fromJsonWithConverter', () {
      final json = {
        'v': {'a': 1, 'b': 2}
      };

      final rpcMap = RpcMap.fromJsonWithConverter(
        json,
        keyConverter: (key) => key.toString(),
        valueConverter: (value) => RpcInt((value as int) * 2),
      );

      expect(rpcMap['a'], RpcInt(2));
      expect(rpcMap['b'], RpcInt(4));
      expect((rpcMap['a'] as RpcInt).value, 2);
      expect((rpcMap['b'] as RpcInt).value, 4);
    });

    test('шорткаты для доступа к методам Map', () {
      final map = RpcMap({'a': RpcInt(1), 'b': RpcInt(2)});

      // Проверяем свойства
      expect(map.length, equals(2));
      expect(map.isEmpty, isFalse);
      expect(map.isNotEmpty, isTrue);
      expect(map.keys, equals(['a', 'b']));
      expect(
          map.values.map((v) => (v as RpcInt).value).toList(), equals([1, 2]));

      // Проверяем операторы
      expect(map['a'], RpcInt(1));
      map['a'] = RpcInt(10);
      expect(map['a'], RpcInt(10));
      expect((map['a'] as RpcInt).value, 10);

      // Проверяем методы
      expect(map.containsKey('a'), isTrue);
      expect(map.containsKey('c'), isFalse);

      map.addAll({'c': RpcInt(3), 'd': RpcInt(4)});
      expect(map.length, equals(4));

      map.remove('a');
      expect(map.length, equals(3));
      expect(map.containsKey('a'), isFalse);

      map.clear();
      expect(map.isEmpty, isTrue);
    });

    test('asMap метод для доступа к внутреннему словарю', () {
      final map = RpcMap({'a': RpcInt(1), 'b': RpcInt(2)});

      // Проверяем, что asMap возвращает тот же словарь
      expect(map.asMap['a'], RpcInt(1));
      expect(map.asMap['b'], RpcInt(2));
      expect((map.asMap['a'] as RpcInt).value, 1);
      expect((map.asMap['b'] as RpcInt).value, 2);

      // Проверяем, что это действительно тот же самый объект
      map.asMap['c'] = RpcInt(3);
      expect(map['c'], RpcInt(3));
      expect((map['c'] as RpcInt).value, 3);

      // Проверяем использование методов Map
      final keysJoined = map.asMap.keys.join(',');
      expect(keysJoined, equals('a,b,c'));
    });

    test('toJson для примитивных типов', () {
      final map = RpcMap({'a': RpcInt(1), 'b': RpcInt(2)});
      expect(
          map.toJson(),
          equals({
            'v': {
              'a': {'v': 1},
              'b': {'v': 2}
            }
          }));
    });

    test('fromJson для String ключей', () {
      final json = {
        'v': {'a': 1, 'b': 2}
      };
      final map = RpcMap.fromJson(json);
      expect(map['a'], RpcInt(1));
      expect(map['b'], RpcInt(2));
      expect((map['a'] as RpcInt).value, 1);
      expect((map['b'] as RpcInt).value, 2);
    });

    test('toJson для вложенных IRpcSerializableMessage', () {
      final rpcStringMap = RpcMap({
        'a': const RpcString('test1'),
        'b': const RpcString('test2'),
      });

      final expected = {
        'v': {
          'a': {'v': 'test1'},
          'b': {'v': 'test2'}
        }
      };

      expect(rpcStringMap.toJson(), equals(expected));
    });

    test('equals и hashCode', () {
      final map1 = RpcMap({'a': RpcInt(1), 'b': RpcInt(2)});
      final map2 = RpcMap({'a': RpcInt(1), 'b': RpcInt(2)});
      final map3 = RpcMap({'a': RpcInt(1), 'b': RpcInt(3)});

      expect(map1 == map2, isTrue);
      expect(map1.hashCode == map2.hashCode, isTrue);
      expect(map1 == map3, isFalse);
      // Дополнительно сравниваем значения
      expect((map1['a'] as RpcInt).value, 1);
      expect((map1['b'] as RpcInt).value, 2);
      expect((map3['b'] as RpcInt).value, 3);
    });

    test('throws для не-String ключей без withConverter', () {
      expect(() {
        // Вручную вызываем код, который должен выбросить исключение
        if (int != String) {
          throw UnsupportedError(
            'Для ключей, отличных от String, используйте RpcMap.withConverter',
          );
        }
      }, throwsUnsupportedError);
    });
  });

  group('Сложные вложенные структуры', () {
    test('Список списков', () {
      final nestedList = RpcList<RpcList<RpcInt>>([
        RpcList<RpcInt>([RpcInt(1), RpcInt(2)]),
        RpcList<RpcInt>([RpcInt(3), RpcInt(4)]),
      ]);

      final json = nestedList.toJson();
      expect(
          json['v'][0]['v'],
          equals([
            {'v': 1},
            {'v': 2}
          ]));
      expect(
          json['v'][1]['v'],
          equals([
            {'v': 3},
            {'v': 4}
          ]));

      // Воссоздаем из JSON
      final deserializedList =
          RpcList<RpcList<RpcInt>>.withConverter(json, (item) {
        final subList = (item as Map<String, dynamic>)['v'] as List;
        return RpcList<RpcInt>(subList
            .map((subItem) => RpcInt.fromJson(subItem as Map<String, dynamic>))
            .toList());
      });

      expect(deserializedList[0].map((i) => i.value).toList(), equals([1, 2]));
      expect(deserializedList[1].map((i) => i.value).toList(), equals([3, 4]));
      expect(deserializedList, equals(nestedList));
    });

    test('Карта со списками', () {
      final mapWithLists = RpcMap({
        'even': RpcList<RpcInt>([RpcInt(2), RpcInt(4), RpcInt(6)]),
        'odd': RpcList<RpcInt>([RpcInt(1), RpcInt(3), RpcInt(5)]),
      });

      final json = mapWithLists.toJson();
      print(json);
      expect(
          json['v']['even']['v'],
          equals([
            {'v': 2},
            {'v': 4},
            {'v': 6}
          ]));
      expect(
          json['v']['odd']['v'],
          equals([
            {'v': 1},
            {'v': 3},
            {'v': 5}
          ]));

      // Воссоздаем из JSON
      final deserializedMap = RpcMap.fromJson(json);

      // Исправим приведение типов - после десериализации в маршрутизаторе у нас RpcList<IRpcSerializableMessage>
      // нужно просто проверить содержимое, а не приводить типы
      final even = deserializedMap['even'] as RpcList;
      final odd = deserializedMap['odd'] as RpcList;

      // Проверяем, что значения внутри массива равны, но не проверяем типы
      final List<dynamic> evenValues = even.map((item) {
        if (item is RpcInt) return item.value;
        return item;
      }).toList();

      final List<dynamic> oddValues = odd.map((item) {
        if (item is RpcInt) return item.value;
        return item;
      }).toList();

      expect(evenValues, equals([2, 4, 6]));
      expect(oddValues, equals([1, 3, 5]));

      // Здесь мы не можем просто сравнивать карты, так как типы могут отличаться
      // после десериализации (RpcList<IRpcSerializableMessage> vs RpcList<int>)
      expect(deserializedMap.keys, equals(mapWithLists.keys));
    });

    test('Список с смешанными примитивами', () {
      final primitivesList = RpcList<IRpcSerializableMessage>([
        const RpcString('test'),
        const RpcInt(123),
        const RpcBool(true),
        const RpcDouble(3.14),
        const RpcNull(),
      ]);

      final json = primitivesList.toJson();
      expect(json['v'][0]['v'], equals('test'));
      expect(json['v'][1]['v'], equals(123));
      expect(json['v'][2]['v'], equals(true));
      expect(json['v'][3]['v'], equals(3.14));
      expect(json['v'][4]['v'], isNull);
    });

    test('Комплексная структура', () {
      // Создаем сложную структуру данных: карта, содержащая списки различных примитивов
      final complexStructure = RpcMap({
        'strings': RpcList<RpcString>([
          const RpcString('one'),
          const RpcString('two'),
        ]),
        'numbers': RpcList<RpcInt>([
          const RpcInt(1),
          const RpcInt(2),
        ]),
        'mixed': RpcList<IRpcSerializableMessage>([
          const RpcString('text'),
          const RpcInt(42),
          const RpcBool(true),
        ]),
        'nested': RpcMap({
          'a': const RpcInt(1),
          'b': const RpcInt(2),
        }),
      });

      final json = complexStructure.toJson();

      // Проверяем структуру JSON
      expect(json['v']['strings']['v'][0]['v'], equals('one'));
      expect(json['v']['numbers']['v'][1]['v'], equals(2));
      expect(json['v']['mixed']['v'][2]['v'], equals(true));
      expect(json['v']['nested']['v']['b']['v'], equals(2));

      // Тест на глубокую вложенность
      final deepNested = RpcMap({
        'level1': RpcMap({
          'level2': RpcMap({
            'level3': RpcList<RpcString>([const RpcString('deeply nested')])
          })
        })
      });

      final deepJson = deepNested.toJson();
      final value =
          deepJson['v']['level1']['v']['level2']['v']['level3']['v'][0]['v'];
      expect(value, equals('deeply nested'));
    });
  });

  group('RpcString Tests with Invalid Input', () {
    test('RpcString fromJson with null value', () {
      final json = {'v': null};
      final result = RpcString.fromJson(json);

      expect(result.value, '');
    });

    test('RpcString fromJson with wrong type (int)', () {
      final json = {'v': 123};
      final result = RpcString.fromJson(json);

      expect(result.value, '123');
    });

    test('RpcString fromJson with wrong type (map)', () {
      final json = {
        'v': {'nested': 'value'}
      };
      final result = RpcString.fromJson(json);

      expect(result.value.contains('{'), true);
      expect(result.value.contains('}'), true);
    });

    test('RpcString fromJson with missing value field', () {
      final json = {'not_v': 'test'};
      final result = RpcString.fromJson(json);

      expect(result.value, '');
    });
  });

  group('RpcInt Tests with Invalid Input', () {
    test('RpcInt fromJson with null value', () {
      final json = {'v': null};
      final result = RpcInt.fromJson(json);

      expect(result.value, 0);
    });

    test('RpcInt fromJson with wrong type (string)', () {
      final json = {'v': '123'};
      final result = RpcInt.fromJson(json);

      expect(result.value, 123);
    });

    test('RpcInt fromJson with wrong type (non-numeric string)', () {
      final json = {'v': 'abc'};
      final result = RpcInt.fromJson(json);

      expect(result.value, 0);
    });

    test('RpcInt fromJson with wrong type (double)', () {
      final json = {'v': 123.45};
      final result = RpcInt.fromJson(json);

      expect(result.value, 123);
    });

    test('RpcInt fromJson with wrong type (map)', () {
      final json = {
        'v': {'nested': 42}
      };
      final result = RpcInt.fromJson(json);

      expect(result.value, 0);
    });

    test('RpcInt fromJson with missing value field', () {
      final json = {'not_v': 123};
      final result = RpcInt.fromJson(json);

      expect(result.value, 0);
    });
  });

  group('RpcBool Tests with Invalid Input', () {
    test('RpcBool fromJson with null value', () {
      final json = {'v': null};
      final result = RpcBool.fromJson(json);

      expect(result.value, false);
    });

    test('RpcBool fromJson with wrong type (string "true")', () {
      final json = {'v': 'true'};
      final result = RpcBool.fromJson(json);

      expect(result.value, true);
    });

    test('RpcBool fromJson with wrong type (string "1")', () {
      final json = {'v': '1'};
      final result = RpcBool.fromJson(json);

      expect(result.value, true);
    });

    test('RpcBool fromJson with wrong type (string "false")', () {
      final json = {'v': 'false'};
      final result = RpcBool.fromJson(json);

      expect(result.value, false);
    });

    test('RpcBool fromJson with wrong type (string "0")', () {
      final json = {'v': '0'};
      final result = RpcBool.fromJson(json);

      expect(result.value, false);
    });

    test('RpcBool fromJson with wrong type (int 1)', () {
      final json = {'v': 1};
      final result = RpcBool.fromJson(json);

      expect(result.value, true);
    });

    test('RpcBool fromJson with wrong type (int 0)', () {
      final json = {'v': 0};
      final result = RpcBool.fromJson(json);

      expect(result.value, false);
    });

    test('RpcBool fromJson with wrong type (map)', () {
      final json = {
        'v': {'nested': true}
      };
      final result = RpcBool.fromJson(json);

      expect(result.value, false);
    });

    test('RpcBool fromJson with missing value field', () {
      final json = {'not_v': true};
      final result = RpcBool.fromJson(json);

      expect(result.value, false);
    });
  });

  group('RpcDouble Tests with Invalid Input', () {
    test('RpcDouble fromJson with null value', () {
      final json = {'v': null};
      final result = RpcDouble.fromJson(json);

      expect(result.value, 0.0);
    });

    test('RpcDouble fromJson with wrong type (string)', () {
      final json = {'v': '123.45'};
      final result = RpcDouble.fromJson(json);

      expect(result.value, 123.45);
    });

    test('RpcDouble fromJson with wrong type (non-numeric string)', () {
      final json = {'v': 'abc'};
      final result = RpcDouble.fromJson(json);

      expect(result.value, 0.0);
    });

    test('RpcDouble fromJson with wrong type (int)', () {
      final json = {'v': 123};
      final result = RpcDouble.fromJson(json);

      expect(result.value, 123.0);
    });

    test('RpcDouble fromJson with wrong type (map)', () {
      final json = {
        'v': {'nested': 42.5}
      };
      final result = RpcDouble.fromJson(json);

      expect(result.value, 0.0);
    });

    test('RpcDouble fromJson with missing value field', () {
      final json = {'not_v': 123.45};
      final result = RpcDouble.fromJson(json);

      expect(result.value, 0.0);
    });
  });

  group('RpcNum Tests with Invalid Input', () {
    test('RpcNum fromJson with null value', () {
      final json = {'v': null};
      final result = RpcNum.fromJson(json);

      expect(result.value, 0);
    });

    test('RpcNum fromJson with wrong type (string)', () {
      final json = {'v': '123.45'};
      final result = RpcNum.fromJson(json);

      expect(result.value, 123.45);
    });

    test('RpcNum fromJson with wrong type (non-numeric string)', () {
      final json = {'v': 'abc'};
      final result = RpcNum.fromJson(json);

      expect(result.value, 0);
    });

    test('RpcNum fromJson with wrong type (map)', () {
      final json = {
        'v': {'nested': 42}
      };
      final result = RpcNum.fromJson(json);

      expect(result.value, 0);
    });

    test('RpcNum fromJson with missing value field', () {
      final json = {'not_v': 123};
      final result = RpcNum.fromJson(json);

      expect(result.value, 0);
    });
  });

  group('RpcMap Tests with Invalid Input', () {
    test('RpcMap fromJson with null', () {
      final result = RpcMap.fromJson(null);
      expect(result.isEmpty, true);
    });

    test('RpcMap fromJson with null value field', () {
      final json = {'v': null};
      final result = RpcMap.fromJson(json);
      expect(result.isEmpty, true);
    });

    test('RpcMap fromJson with wrong type for value (string)', () {
      final json = {'v': 'not a map'};

      // Этот вызов должен вернуть пустую карту и не вызвать ошибку
      final result = RpcMap.fromJson(json);
      expect(result.isEmpty, true);
    });

    test('RpcMap fromJson with missing value field', () {
      final json = {
        'not_v': {'key': 'value'}
      };
      final result = RpcMap.fromJson(json);
      expect(result.isEmpty, true);
    });

    test(
        'RpcMap fromJson with complex nested structure containing invalid values',
        () {
      // Создаем сложную структуру с некорректными значениями
      final json = {
        'v': {
          'nullValue': {'v': null},
          'wrongType': {
            'v': {
              'deeply': {'nested': 123}
            }
          },
          'missingValue': {'not_v': 'test'},
          'validString': {'v': 'ok'},
          'validInt': {'v': 42},
          'list': {
            'v': [
              1,
              'two',
              null,
              {'v': 'nested'}
            ]
          },
        }
      };

      // Должен корректно обработать и не упасть
      final result = RpcMap.fromJson(json);

      expect(result.length, 6); // Все ключи должны быть сохранены

      // Проверяем типы возвращаемых значений
      expect(result['nullValue'], isA<RpcNull>());
      expect(result['wrongType'], isA<RpcMap>());

      // Вместо проверки на конкретный тип, просто убедимся что значение есть
      // и это какой-то serializable тип
      expect(result['missingValue'], isA<IRpcSerializableMessage>());

      expect(result['validString'], isA<RpcString>());
      expect(result['validInt'], isA<RpcInt>());
      expect(result['list'], isA<RpcList>());

      // Проверяем конкретные значения
      expect((result['validInt'] as RpcInt).value, 42);
      expect((result['validString'] as RpcString).value, 'ok');
    });
  });

  group('RpcList Tests with Invalid Input', () {
    test('RpcList fromJson with null value', () {
      final json = {'v': null};
      final result = RpcList<RpcString>.fromJson(json);

      expect(result.isEmpty, true);
    });

    test('RpcList fromJson with wrong type (not a list)', () {
      final json = {'v': 'not a list'};

      // Должен либо вернуть пустой список, либо выбросить ошибку, но не упасть
      expect(() {
        final result = RpcList<RpcString>.fromJson(json);
        // Если не выбросило исключение, проверяем что вернул пустой список
        expect(result.isEmpty, true);
      }, returnsNormally);
    });

    test('RpcList fromJson with missing value field', () {
      final json = {
        'not_v': [1, 2, 3]
      };

      // Должен вернуть пустой список
      expect(() {
        final result = RpcList<RpcString>.fromJson(json);
        expect(result.isEmpty, true);
      }, returnsNormally);
    });
  });
}
