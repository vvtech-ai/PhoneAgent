import 'task_records.dart';

/// Apply pending exit only, just like v65. Source rows are never mutated; a
/// recovery acknowledgement removes this overlay, not a guessed RUNNING state.
List<TaskRecord> projectPendingTaskErrors(
  List<TaskRecord> rows,
  Set<String> pending,
) => List.unmodifiable(
  rows.map((row) {
    if (row.kind != TaskRecordKind.conversation ||
        !pending.contains(row.sessionId)) {
      return row;
    }
    return row.copyWith(
      status: TaskStatus.executionError,
      rawStatus: 'EXECUTION_ERROR',
    );
  }),
);
