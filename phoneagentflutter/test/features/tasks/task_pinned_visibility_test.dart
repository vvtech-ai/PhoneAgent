import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/domain/task_pinned_visibility.dart';
import 'package:phone_agent/features/tasks/data/secure_task_pinned_preferences.dart';

TaskRecord row(String id, {bool pinned = false, bool unread = false}) =>
    TaskRecord(
      id: id,
      kind: TaskRecordKind.conversation,
      title: id,
      status: TaskStatus.completed,
      rawStatus: 'COMPLETED',
      pinnedAt: pinned ? '2026-10-08' : null,
      unreadResult: unread,
    );
void main() {
  test(
    'folding keeps unread pins and server ordering; expanding preserves all rows',
    () {
      final rows = [
        row('read', pinned: true),
        row('unread', pinned: true, unread: true),
        row('normal'),
      ];
      final folded = TaskPinnedVisibility(rows, true);
      expect(folded.visible.map((r) => r.id), ['unread', 'normal']);
      expect(folded.hiddenCount, 1);
      expect(TaskPinnedVisibility(rows, false).visible, rows);
      expect(TaskPinnedVisibility([rows[1]], true).hiddenCount, 0);
    },
  );
  test(
    'fold and scroll storage identities isolate accounts and environments',
    () {
      final scopes = [
        ['dev', 'a', 'user'],
        ['dev', 'a', 'other'],
        ['prod', 'a', 'user'],
        ['dev', 'b', 'user'],
      ];
      expect(
        scopes
            .map((s) => SecureTaskPinnedPreferences(s).scopeKey)
            .toSet()
            .length,
        4,
      );
    },
  );
}
