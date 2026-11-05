import 'task_records.dart';
import 'task_reference.dart';
export 'task_reference.dart';

class TaskPage {
  const TaskPage({
    required this.pinnedItems,
    required this.items,
    required this.nextOffset,
    required this.hasMore,
    required this.hasUnread,
  });
  final List<TaskRecord> pinnedItems, items;
  final int nextOffset;
  final bool hasMore, hasUnread;
}

/// Production port. Legacy source loading remains for old offline previews.
abstract interface class PagedTaskRepository implements TaskRepository {
  Future<TaskPage> loadPage({int offset = 0, int limit = 15});
  Future<void> pin(TaskRef ref, bool pinned);
  Future<void> hide(TaskRef ref);
  Future<void> markRead(TaskRef ref);
  Future<void> clearUnread();
}

/// Current SDK pin endpoint returns the authoritative target item.
abstract interface class TaskPinRepository {
  Future<TaskRecord> updatePin(TaskRef ref, bool pinned);
}
