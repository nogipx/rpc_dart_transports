import 'dart:convert';
import 'calculator_contract.dart';

/// Пример использования CBOR с моделью CalculationRequest
void main() {
  print('Демонстрация CBOR с моделью CalculationRequest');
  print('=============================================');

  // Создаем запрос на вычисление
  final request = CalculationRequest(
    a: 10.5,
    b: 20.3,
    operation: 'multiply',
  );

  // Сериализуем с помощью встроенной поддержки CBOR
  final cborBytes = request.serialize();

  // Для сравнения создаем простую JSON сериализацию
  final jsonMap = {'a': 10.5, 'b': 20.3, 'operation': 'multiply'};
  final jsonString = jsonEncode(jsonMap);
  final jsonBytes = utf8.encode(jsonString);

  // Выводим сравнительную информацию
  print('Размер JSON: ${jsonBytes.length} байт');
  print('Размер CBOR: ${cborBytes.length} байт');
  print(
      'Экономия: ${jsonBytes.length - cborBytes.length} байт (${((jsonBytes.length - cborBytes.length) / jsonBytes.length * 100).toStringAsFixed(1)}%)');

  // Выводим JSON данные
  print('\nJSON данные:');
  print(jsonString);

  // Десериализуем из CBOR
  final decodedRequest = CalculationRequest.fromBytes(cborBytes);

  // Проверяем результат десериализации
  print('\nДесериализовано из CBOR:');
  print('a: ${decodedRequest.a}');
  print('b: ${decodedRequest.b}');
  print('operation: ${decodedRequest.operation}');
  print('isValid: ${decodedRequest.isValid()}');
}
