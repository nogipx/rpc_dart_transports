import 'package:rpc_dart/rpc_dart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'unary_models.freezed.dart';
part 'unary_models.g.dart';

/// Класс запроса с числовыми параметрами
@freezed
abstract class ComputeRequest
    with _$ComputeRequest
    implements IRpcSerializableMessage {
  const ComputeRequest._();

  @Implements<IRpcSerializableMessage>()
  const factory ComputeRequest({
    @Default(0) int value1,
    @Default(0) int value2,
  }) = _ComputeRequest;

  factory ComputeRequest.fromJson(Map<String, dynamic> json) =>
      _$ComputeRequestFromJson(json);
}

/// Класс ответа с результатом вычислений
@freezed
abstract class ComputeResult
    with _$ComputeResult
    implements IRpcSerializableMessage {
  const ComputeResult._();

  @Implements<IRpcSerializableMessage>()
  const factory ComputeResult({
    @Default(0) int sum,
    @Default(0) int difference,
    @Default(0) int product,
    double? quotient,
  }) = _ComputeResult;

  factory ComputeResult.fromJson(Map<String, dynamic> json) =>
      _$ComputeResultFromJson(json);
}
