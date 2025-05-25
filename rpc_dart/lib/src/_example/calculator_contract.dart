// import '../contracts/_index.dart';
// import 'dart:convert';

// /// Запрос на вычисление
// class CalculationRequest
//     implements IRpcJsonSerializable, IRpcSerializable, CborRpcSerializable {
//   final double a;
//   final double b;
//   final String operation;

//   CalculationRequest({
//     required this.a,
//     required this.b,
//     required this.operation,
//   });

//   /// Валидация операции
//   bool isValid() {
//     return ['add', 'subtract', 'multiply', 'divide'].contains(operation);
//   }

//   @override
//   Map<String, dynamic> toJson() => {
//         'a': a,
//         'b': b,
//         'operation': operation,
//       };

//   @override
//   Map<String, dynamic> toCbor() =>
//       toJson(); // Для CBOR используем те же данные что и для JSON

//   @override
//   Uint8List serialize() {
//     // В зависимости от запрошенного формата, сериализуем по-разному
//     if (getFormat() == RpcSerializationFormat.cbor) {
//       return CborCodec.encode(toCbor());
//     } else {
//       // Для JSON используем старый код
//       final jsonString = jsonEncode(toJson());
//       return Uint8List.fromList(utf8.encode(jsonString));
//     }
//   }

//   @override
//   RpcSerializationFormat getFormat() =>
//       RpcSerializationFormat.cbor; // По умолчанию используем CBOR

//   static CalculationRequest fromJson(Map<String, dynamic> json) {
//     return CalculationRequest(
//       a: json['a'] is int ? (json['a'] as int).toDouble() : json['a'],
//       b: json['b'] is int ? (json['b'] as int).toDouble() : json['b'],
//       operation: json['operation'],
//     );
//   }

//   /// Метод для создания из CBOR
//   static CalculationRequest fromCbor(Map<String, dynamic> cbor) {
//     // Для демонстрации - реализация та же, что и fromJson
//     return fromJson(cbor);
//   }

//   /// Удобный статический метод для десериализации из CBOR
//   static CalculationRequest fromBytes(Uint8List bytes) {
//     return CborRpcSerializable.fromBytes<CalculationRequest>(
//       bytes,
//       fromCbor,
//     );
//   }
// }

// /// Ответ на вычисление
// class CalculationResponse implements IRpcJsonSerializable, IRpcSerializable {
//   final double? result;
//   final bool success;
//   final String? errorMessage;

//   CalculationResponse({
//     this.result,
//     this.success = true,
//     this.errorMessage,
//   });

//   @override
//   Map<String, dynamic> toJson() => {
//         'result': result,
//         'success': success,
//         'errorMessage': errorMessage,
//       };

//   @override
//   Uint8List serialize() {
//     final jsonString = jsonEncode(toJson());
//     return Uint8List.fromList(utf8.encode(jsonString));
//   }

//   @override
//   RpcSerializationFormat getFormat() => RpcSerializationFormat.json;

//   static CalculationResponse fromJson(Map<String, dynamic> json) {
//     return CalculationResponse(
//       result: json['result'],
//       success: json['success'] ?? true,
//       errorMessage: json['errorMessage'],
//     );
//   }
// }

// /// Пример с бинарной сериализацией
// class BinaryCalculationRequest extends CalculationRequest {
//   BinaryCalculationRequest({
//     required super.a,
//     required super.b,
//     required super.operation,
//   });

//   @override
//   RpcSerializationFormat getFormat() => RpcSerializationFormat.binary;

//   static BinaryCalculationRequest fromJson(Map<String, dynamic> json) {
//     return BinaryCalculationRequest(
//       a: json['a'] is int ? (json['a'] as int).toDouble() : json['a'],
//       b: json['b'] is int ? (json['b'] as int).toDouble() : json['b'],
//       operation: json['operation'],
//     );
//   }

//   /// Статический метод для десериализации из бинарных данных
//   static BinaryCalculationRequest fromBuffer(Uint8List bytes) {
//     // В реальном примере здесь был бы код для распаковки бинарного формата
//     // Но в этом примере мы просто преобразуем через JSON
//     final jsonString = utf8.decode(bytes);
//     final json = jsonDecode(jsonString) as Map<String, dynamic>;
//     return fromJson(json);
//   }
// }

// /// Вспомогательный метод для десериализации ответа из бинарных данных
// CalculationResponse calculationResponseFromBuffer(Uint8List bytes) {
//   // В реальном примере здесь был бы код для распаковки бинарного формата
//   // Но в этом примере мы просто преобразуем через JSON
//   final jsonString = utf8.decode(bytes);
//   final json = jsonDecode(jsonString) as Map<String, dynamic>;
//   return CalculationResponse.fromJson(json);
// }
