import 'task_page.dart';
import 'task_records.dart';

/// Adjusts the existing loaded window; it does not fetch or own task state.
class TaskPageMutation {
  static TaskPage hide(TaskPage page, TaskRef target) {
    final pins = page.pinnedItems.where((row) => row.ref != target).toList();
    final normal = page.items.where((row) => row.ref != target).toList();
    final removed = page.items.length - normal.length;
    return TaskPage(
      pinnedItems: pins,
      items: normal,
      nextOffset: (page.nextOffset - removed).clamp(0, page.nextOffset),
      hasMore: page.hasMore,
      hasUnread:
          [...pins, ...normal].any((row) => row.unreadResult) ||
          (page.hasMore && page.hasUnread),
    );
  }

  static TaskPage pin(
    TaskPage page,
    TaskRecord target, {
    int? nextOffset,
    bool restoreTarget = false,
  }) {
    bool same(TaskRecord row) =>
        (row.ref?.key ?? row.id) == (target.ref?.key ?? target.id);
    final wasNormal = page.items.any(same);
    final wasPinned = page.pinnedItems.any(same);
    if (!wasNormal && !wasPinned && !restoreTarget) return page;
    final pins = page.pinnedItems.where((row) => !same(row)).toList();
    final normal = page.items.where((row) => !same(row)).toList();
    var offset = page.nextOffset;
    if (target.pinnedAt != null) {
      pins.add(target);
      if (wasNormal) offset--;
    } else if (restoreTarget ||
        wasNormal ||
        !page.hasMore ||
        normal.isEmpty ||
        compareNormal(target, normal.last) <= 0) {
      if (wasPinned) offset++;
      normal.add(target);
    }
    normal.sort(compareNormal);
    pins.sort((a, b) {
      final time = (b.pinnedAt ?? '').compareTo(a.pinnedAt ?? '');
      return time != 0 ? time : compareNormal(a, b);
    });
    return TaskPage(
      pinnedItems: pins,
      items: normal,
      nextOffset: nextOffset ?? (offset < 0 ? 0 : offset),
      hasMore: page.hasMore,
      hasUnread: page.hasUnread,
    );
  }

  static int compareNormal(TaskRecord a, TaskRecord b) {
    final time = b.sortTime.compareTo(a.sortTime);
    return time != 0
        ? time
        : (a.ref?.key ?? a.id).compareTo(b.ref?.key ?? b.id);
  }

  static TaskPage unread(
    TaskPage page,
    bool Function(TaskRecord) value, {
    bool? hasUnread,
  }) => TaskPage(
    pinnedItems: [
      for (final row in page.pinnedItems)
        row.copyWith(unreadResult: value(row)),
    ],
    items: [
      for (final row in page.items) row.copyWith(unreadResult: value(row)),
    ],
    nextOffset: page.nextOffset,
    hasMore: page.hasMore,
    hasUnread: hasUnread ?? page.hasUnread,
  );
}
