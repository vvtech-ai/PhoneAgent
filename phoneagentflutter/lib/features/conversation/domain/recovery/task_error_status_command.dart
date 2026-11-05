enum TaskErrorStatusReason {
  exited('execution_error_exit'),
  recovered('execution_error_recovered');

  const TaskErrorStatusReason(this.wire);
  final String wire;
}

class TaskErrorStatusCommand {
  TaskErrorStatusCommand(this.sessionId, this.reason, this.commandId) {
    if (!validId(sessionId) || !validId(commandId)) {
      throw const FormatException('Invalid task status identity');
    }
  }
  final String sessionId, commandId;
  final TaskErrorStatusReason reason;

  static bool validId(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{1,256}$').hasMatch(value);

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'reason': reason.wire,
    'commandId': commandId,
  };

  factory TaskErrorStatusCommand.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['sessionId'] is! String ||
        value['commandId'] is! String) {
      throw const FormatException('Invalid task status command');
    }
    final reason = TaskErrorStatusReason.values
        .where((r) => r.wire == value['reason'])
        .firstOrNull;
    if (reason == null) {
      throw const FormatException('Invalid task status reason');
    }
    return TaskErrorStatusCommand(
      value['sessionId'] as String,
      reason,
      value['commandId'] as String,
    );
  }
}

abstract interface class TaskErrorStatusStore {
  Future<List<TaskErrorStatusCommand>> read();
  Future<void> put(TaskErrorStatusCommand command);
  Future<void> removeIfCurrent(TaskErrorStatusCommand command);
}

abstract interface class TaskErrorStatusGateway {
  /// Returns the authoritative task status, including terminal suppression.
  Future<String> send(TaskErrorStatusCommand command);
}
