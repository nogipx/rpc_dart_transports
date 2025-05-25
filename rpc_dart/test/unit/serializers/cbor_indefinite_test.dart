import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:rpc_dart/src/serializers/cbor/cbor.dart';

/// Тесты на неопределенную длину (indefinite-length encoding) в CBOR
///
/// Эти тесты предназначены для проверки как декодирования существующих
/// indefinite-length структур, так и для будущей реализации их кодирования.
void main() {
  group('CBOR Indefinite Length Tests', () {
    /// Утилита для преобразования шестнадцатеричной строки в байты
    Uint8List hexToBytes(String hex) {
      final result = Uint8List((hex.length) ~/ 2);
      for (var i = 0; i < result.length; i++) {
        result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return result;
    }

    /// Утилита для отображения байтов в шестнадцатеричном формате
    String bytesToHex(Uint8List bytes) {
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    }

    /// Тесты декодирования indefinite-length структур из RFC 7049
    group('Decoding indefinite-length structures', () {
      test('Should fail to decode indefinite-length arrays', () {
        // 0x9f = indefinite-length array start, 0x01, 0x02, 0x03 = items, 0xff = break
        final indefiniteArray = hexToBytes('9f010203ff');

        expect(
            () => CborCodec.decode(indefiniteArray),
            throwsA(predicate((e) =>
                e is FormatException &&
                e.message.contains('Indefinite length not implemented'))));
      });

      test('Should fail to decode indefinite-length maps', () {
        // 0xbf = indefinite-length map start, then items, 0xff = break
        final indefiniteMap = hexToBytes('bf616101616202616303ff');

        expect(
            () => CborCodec.decode(indefiniteMap),
            throwsA(predicate((e) =>
                e is FormatException &&
                e.message.contains('Indefinite length not implemented'))));
      });

      test('Should fail to decode indefinite-length strings', () {
        // 0x7f = indefinite-length text string start, then chunks, 0xff = break
        final indefiniteString = hexToBytes('7f657374726561646d696e67ff');

        expect(
            () => CborCodec.decode(indefiniteString),
            throwsA(predicate((e) =>
                e is FormatException &&
                e.message.contains('Indefinite length not implemented'))));
      });
    });

    /// Подготовка к будущей реализации indefinite-length кодирования
    group('Future indefinite-length encoding', () {
      test('Example indefinite-length structures from RFC 7049', () {
        // Это примеры из RFC 7049 Appendix A - пока мы их не кодируем,
        // но можем использовать как спецификацию для будущей реализации

        // Indefinite-length array: [1, [2, 3], [4, 5]]
        // 9f - start indefinite-length array
        // 01 - unsigned(1)
        // 82 02 03 - array [2, 3]
        // 82 04 05 - array [4, 5]
        // ff - break
        final expectedIndefiniteArray = '9f018202038204059ff';

        // Indefinite-length map: {"a": 1, "b": [2, 3]}
        // bf - start indefinite-length map
        // 61 61 - text "a"
        // 01 - unsigned(1)
        // 61 62 - text "b"
        // 82 02 03 - array [2, 3]
        // ff - break
        final expectedIndefiniteMap = 'bf61610161628202036ff';

        // Indefinite-length string: "streaming"
        // 7f - start indefinite-length text string
        // 65 73747265 - text "stre"
        // 64 616d69 - text "ami"
        // 6e 67 - text "ng"
        // ff - break
        final expectedIndefiniteString = '7f657374726564616d696e67ff';
      });

      test('Indefinite-length array conversion example', () {
        // В этом тесте мы показываем, как можно было бы преобразовать
        // обычный массив в indefinite-length формат

        final array = [1, 2, 3, 4, 5];

        // Код для будущей реализации:
        // Шаг 1: Создаем BytesBuilder
        // final builder = BytesBuilder();

        // Шаг 2: Записываем начало массива неопределенной длины (0x9f)
        // builder.addByte(0x9f);

        // Шаг 3: Записываем каждый элемент
        // for (var item in array) {
        //   final encodedItem = CborCodec.encode(item);
        //   builder.add(encodedItem);
        // }

        // Шаг 4: Записываем break-байт (0xff)
        // builder.addByte(0xff);

        // Шаг 5: Получаем байты
        // final indefiniteBytes = builder.toBytes();

        // Ожидаемый результат: 9f0102030405ff
        // Мы пока не делаем это, но оставляем как комментарий для будущей реализации
      });
    });

    /// Тесты, показывающие use-cases, когда indefinite-length структуры полезны
    group('Use cases for indefinite-length encoding', () {
      test('Streaming JSON API conversion', () {
        // Пример use-case: преобразование потокового JSON API в CBOR
        // В реальном приложении данные могли бы приходить частями

        // Симуляция: получаем JSON по частям
        final jsonPart1 = '{"users":[{"id":1,"name":"John"},';
        final jsonPart2 = '{"id":2,"name":"Alice"},';
        final jsonPart3 = '{"id":3,"name":"Bob"}]}';

        // В будущей реализации мы могли бы создать indefinite-length map и array,
        // и добавлять элементы по мере их появления, без необходимости буферизовать весь JSON

        // Для сравнения - текущий подход с буферизацией:
        final fullJson = jsonPart1 + jsonPart2 + jsonPart3;
        final jsonData = jsonDecode(fullJson);
        final cborData = CborCodec.encode(jsonData);

        // Проверяем, что данные декодируются корректно
        final decodedData = CborCodec.decode(cborData);
        expect(decodedData['users'].length, equals(3));
        expect(decodedData['users'][0]['name'], equals('John'));
        expect(decodedData['users'][1]['name'], equals('Alice'));
        expect(decodedData['users'][2]['name'], equals('Bob'));
      });
    });
  });
}
