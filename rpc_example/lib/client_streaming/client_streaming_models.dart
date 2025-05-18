import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rpc_dart/rpc_dart.dart';

part 'client_streaming_models.freezed.dart';
part 'client_streaming_models.g.dart';

/// Модель блока данных для загрузки файла
@freezed
abstract class DataBlock extends IRpcSerializableMessage with _$DataBlock {
  const DataBlock._();

  @Implements<IRpcSerializableMessage>()
  const factory DataBlock({
    @Default(0) int index,
    @Default([]) List<int> data,
    @Default('') String metadata,
  }) = _DataBlock;

  factory DataBlock.fromJson(Map<String, dynamic> json) => _$DataBlockFromJson(json);
}

/// Модель результата обработки блоков данных
@freezed
abstract class DataBlockResult extends IRpcSerializableMessage with _$DataBlockResult {
  const DataBlockResult._();

  @Implements<IRpcSerializableMessage>()
  const factory DataBlockResult({
    @Default(0) int blockCount,
    @Default(0) int totalSize,
    @Default('') String metadata,
    @Default('') String processingTime,
  }) = _DataBlockResult;

  factory DataBlockResult.fromJson(Map<String, dynamic> json) => _$DataBlockResultFromJson(json);
}
