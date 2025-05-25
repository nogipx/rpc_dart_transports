import 'dart:typed_data';
import '../contracts/_index.dart';
import 'calculator_contract.dart';

/// Пример использования CBOR сериализации
void main() {
  // Создаем сериализатор для CalculationRequest
  final serializer = RpcCborSerializer<CalculationRequest>(
    CalculationRequest.fromCbor,
  );

  // Создаем объект для сериализации
  final request = CalculationRequest(
    a: 10.5,
    b: 20.3,
    operation: 'multiply',
  );

  // Сериализуем в CBOR
  final bytes = serializer.serialize(request);

  // Выводим информацию о размере данных
  print('Сериализованные данные:');
  print('Размер данных (CBOR): ${bytes.length} байт');

  // Для сравнения, создаем JSON сериализатор
  final jsonSerializer = RpcJsonSerializer<CalculationRequest>(
    CalculationRequest.fromJson,
  );

  // Временно изменим формат на JSON для корректной сериализации
  final jsonRequest = CalculationRequest(
    a: 10.5,
    b: 20.3,
    operation: 'multiply',
  );

  // Сериализуем в JSON
  final jsonBytes = jsonSerializer.serialize(jsonRequest);
  print('Размер данных (JSON): ${jsonBytes.length} байт');
  print(
      'CBOR меньше JSON на ${jsonBytes.length - bytes.length} байт (${((jsonBytes.length - bytes.length) / jsonBytes.length * 100).toStringAsFixed(2)}%)');

  // Десериализуем обратно из CBOR
  final deserializedRequest = serializer.deserialize(bytes);

  // Проверяем результат
  print('\nДесериализованные данные:');
  print('a: ${deserializedRequest.a}');
  print('b: ${deserializedRequest.b}');
  print('operation: ${deserializedRequest.operation}');

  // Демонстрация прямого использования CborCodec
  print('\nПрямое использование CborCodec:');

  // Кодируем разные типы данных
  _printCborExample(10); // Int
  _printCborExample(-500); // Negative Int
  _printCborExample(3.14159); // Double
  _printCborExample(true); // Boolean
  _printCborExample(null); // Null
  _printCborExample('Привет, мир!'); // String с поддержкой UTF-8
  _printCborExample([1, 2, 3, 4]); // Array
  _printCborExample({'name': 'John', 'age': 30}); // Map

  // Вложенные структуры данных
  _printCborExample({
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
  });
}

/// Вспомогательная функция для демонстрации кодирования/декодирования
void _printCborExample(dynamic value) {
  // Кодируем значение в CBOR
  final encoded = CborCodec.encode(value);

  // Декодируем обратно
  final decoded = CborCodec.decode(encoded);

  // Выводим результат
  print('Значение: $value');
  print('Тип: ${value?.runtimeType}');
  print('Размер в CBOR: ${encoded.length} байт');
  print('Декодировано: $decoded');
  print('Тип после декодирования: ${decoded?.runtimeType}');
  print('---');
}
