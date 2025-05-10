import 'package:rpc_dart/rpc_dart.dart';

/// Запрос на выполнение задачи
class TaskRequest implements IRpcSerializableMessage {
  final String taskId;
  final String taskName;
  final int steps;

  TaskRequest({required this.taskId, required this.taskName, required this.steps});

  @override
  Map<String, dynamic> toJson() => {'taskId': taskId, 'taskName': taskName, 'steps': steps};

  static TaskRequest fromJson(Map<String, dynamic> json) {
    return TaskRequest(
      taskId: json['taskId'] as String,
      taskName: json['taskName'] as String,
      steps: json['steps'] as int,
    );
  }
}

/// Сообщение о прогрессе
class ProgressMessage implements IRpcSerializableMessage {
  final String taskId;
  final int progress;
  final String status;
  final String message;

  ProgressMessage({
    required this.taskId,
    required this.progress,
    required this.status,
    required this.message,
  });

  @override
  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'progress': progress,
    'status': status,
    'message': message,
  };

  static ProgressMessage fromJson(Map<String, dynamic> json) {
    return ProgressMessage(
      taskId: json['taskId'] as String,
      progress: json['progress'] as int,
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }
}

/// Сообщение с результатом
class ResultMessage implements IRpcSerializableMessage {
  final int step;
  final String data;

  ResultMessage({required this.step, required this.data});

  @override
  Map<String, dynamic> toJson() => {'step': step, 'data': data};

  static ResultMessage fromJson(Map<String, dynamic> json) {
    return ResultMessage(step: json['step'] as int, data: json['data'] as String);
  }
}
