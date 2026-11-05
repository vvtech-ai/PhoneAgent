import '../../domain/task_reference.dart';

enum TaskOperation { pin, unpin, delete }

/// One completed operation, never a persistent task-list message.
class TaskOperationFeedback {
  TaskOperationFeedback(
    this.operation,
    this.target, {
    required this.succeeded,
    this.deleteBlocked = false,
  });
  final TaskOperation operation;
  final TaskRef target;
  final bool succeeded, deleteBlocked;

  String get message {
    if (deleteBlocked) return '正在通话的任务不能删除，请通话结束后重试';
    return switch ((operation, succeeded)) {
      (TaskOperation.pin, true) => '置顶成功',
      (TaskOperation.unpin, true) => '取消置顶成功',
      (TaskOperation.delete, true) => '任务删除成功',
      (TaskOperation.pin, false) => '置顶失败，请重试',
      (TaskOperation.unpin, false) => '取消置顶失败，请重试',
      (TaskOperation.delete, false) => '任务删除失败，请稍后重试',
    };
  }
}
