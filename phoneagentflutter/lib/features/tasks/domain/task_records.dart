import 'task_reference.dart';

enum TaskRecordKind { conversation, call, translation, legacyTask }

enum TaskStatus { completed, incomplete, running, executionError }

enum TaskSource { conversations, calls, legacyTasks }

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.rawStatus,
    this.sessionId,
    this.taskId,
    this.callId,
    this.scene = '',
    this.sceneTitle = '',
    this.summary = '',
    this.timestamp = '',
    this.startedAt = '',
    this.phoneNumber = '',
    this.dialogue = '',
    this.durationMillis,
    this.ref,
    this.pinnedAt,
    this.unreadResult = false,
    this.canDelete = false,
    this.deleteBlockCode,
  });
  final String id,
      title,
      rawStatus,
      scene,
      sceneTitle,
      summary,
      timestamp,
      startedAt,
      phoneNumber,
      dialogue;
  final String? sessionId, taskId, callId;
  final TaskRecordKind kind;
  final TaskStatus status;
  final int? durationMillis;
  final TaskRef? ref;
  final String? pinnedAt, deleteBlockCode;
  final bool unreadResult, canDelete;
  bool get canRestore =>
      kind == TaskRecordKind.conversation && sessionId != null;
  int get sortTime => DateTime.tryParse(timestamp)?.millisecondsSinceEpoch ?? 0;
  TaskRecord copyWith({
    TaskStatus? status,
    String? rawStatus,
    String? pinnedAt,
    bool clearPin = false,
    bool? unreadResult,
    String? title,
    String? sceneTitle,
    String? summary,
    int? durationMillis,
  }) => TaskRecord(
    id: id,
    kind: kind,
    title: title ?? this.title,
    status: status ?? this.status,
    rawStatus: rawStatus ?? this.rawStatus,
    sessionId: sessionId,
    taskId: taskId,
    callId: callId,
    scene: scene,
    sceneTitle: sceneTitle ?? this.sceneTitle,
    summary: summary ?? this.summary,
    timestamp: timestamp,
    startedAt: startedAt,
    phoneNumber: phoneNumber,
    dialogue: dialogue,
    durationMillis: durationMillis ?? this.durationMillis,
    ref: ref,
    pinnedAt: clearPin ? null : pinnedAt ?? this.pinnedAt,
    unreadResult: unreadResult ?? this.unreadResult,
    canDelete: canDelete,
    deleteBlockCode: deleteBlockCode,
  );
}

class TaskCatalog {
  const TaskCatalog(this.records, {this.failedSources = const {}});
  final List<TaskRecord> records;
  final Set<TaskSource> failedSources;
}

abstract interface class TaskRepository {
  Future<List<TaskRecord>> load(TaskSource source);
}

/// Conversations and calls are distinct rows. Only legacy task fallback is
/// suppressed when a durable call already covers its taskId (v65).
List<TaskRecord> mergeTaskRecords(Map<TaskSource, List<TaskRecord>> sources) {
  final calls = sources[TaskSource.calls] ?? const <TaskRecord>[];
  final covered = calls.map((r) => r.taskId).whereType<String>().toSet();
  final rows = <String, TaskRecord>{};
  for (final source in TaskSource.values) {
    for (final row in sources[source] ?? const <TaskRecord>[]) {
      if (source == TaskSource.legacyTasks && covered.contains(row.taskId)) {
        continue;
      }
      rows[row.id] = row;
    }
  }
  final indexed = rows.values.indexed.toList();
  indexed.sort((a, b) {
    final time = b.$2.sortTime.compareTo(a.$2.sortTime);
    return time != 0 ? time : a.$1.compareTo(b.$1);
  });
  return List.unmodifiable(indexed.map((r) => r.$2));
}
