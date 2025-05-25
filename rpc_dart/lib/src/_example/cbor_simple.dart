import 'dart:convert';
import 'dart:typed_data';
import '../contracts/_index.dart';

/// Простой пример использования CBOR кодека напрямую
void main() {
  print('Демонстрация CBOR кодека');
  print('=======================');

  // Кодирование простых типов данных
  final values = [
    10, // Int
    -500, // Negative Int
    3.14159, // Double
    true, // Boolean
    null, // Null
    'Привет, мир!', // String с поддержкой UTF-8
    [1, 2, 3, 4], // Array
    {'name': 'John', 'age': 30}, // Map
    // Вложенные структуры
    {
      'user': {
        'name': 'Анна',
        'contacts': {
          'email': 'anna@example.com',
          'phone': '+7 999 123-4567',
        },
        'tags': ['admin', 'developer'],
      },
      'active': true,
      'lastLogin': 1624275125,
    },
  ];

  print('Кодирование различных типов данных:');
  for (final value in values) {
    // Кодируем значение в CBOR
    final encoded = CborCodec.encode(value);

    // Декодируем обратно
    final decoded = CborCodec.decode(encoded);

    // Выводим результат
    print('\nЗначение: $value');
    print('Тип: ${value?.runtimeType}');
    print('Размер в CBOR: ${encoded.length} байт');
    print('Декодировано: $decoded');
    print('Тип после декодирования: ${decoded?.runtimeType}');

    // Сравниваем с JSON для демонстрации эффективности
    final jsonString = value != null ? value.toString() : 'null';
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
    print('Размер в JSON (приблизительно): ${jsonBytes.length} байт');
    print(
        'Экономия: ${jsonBytes.length - encoded.length} байт (${((jsonBytes.length - encoded.length) / jsonBytes.length * 100).toStringAsFixed(1)}%)');
  }
}
