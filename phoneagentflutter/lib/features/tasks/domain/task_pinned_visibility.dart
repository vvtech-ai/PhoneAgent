import 'task_records.dart';

class TaskPinnedVisibility {
  TaskPinnedVisibility(Iterable<TaskRecord> rows, bool collapsed) {
    visible = List.unmodifiable(
      rows.where(
        (row) => row.pinnedAt == null || !collapsed || row.unreadResult,
      ),
    );
    hiddenCount = collapsed
        ? rows.where((row) => row.pinnedAt != null && !row.unreadResult).length
        : 0;
  }
  late final List<TaskRecord> visible;
  late final int hiddenCount;
}

abstract interface class TaskPinnedPreferenceRepository {
  String get scopeKey;
  Future<bool> read();
  Future<void> save(bool collapsed);
}
