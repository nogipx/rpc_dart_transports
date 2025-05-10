import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rpc_dart/rpc_dart.dart';

part 'server_streaming_models.freezed.dart';
part 'server_streaming_models.g.dart';

/// Запрос на выполнение задачи
@freezed
abstract class TaskRequest with _$TaskRequest implements IRpcSerializableMessage {
  const TaskRequest._();

  @Implements<IRpcSerializableMessage>()
  const factory TaskRequest({
    @Default('') String taskId,
    @Default('') String taskName,
    @Default(5) int steps,
  }) = _TaskRequest;

  factory TaskRequest.fromJson(Map<String, dynamic> json) => _$TaskRequestFromJson(json);
}

/// Сообщение о прогрессе выполнения задачи
@freezed
abstract class ProgressMessage with _$ProgressMessage implements IRpcSerializableMessage {
  const ProgressMessage._();

  @Implements<IRpcSerializableMessage>()
  const factory ProgressMessage({
    @Default('') String taskId,
    @Default(0) int progress,
    @Default('') String status,
    @Default('') String message,
  }) = _ProgressMessage;

  factory ProgressMessage.fromJson(Map<String, dynamic> json) => _$ProgressMessageFromJson(json);
}
