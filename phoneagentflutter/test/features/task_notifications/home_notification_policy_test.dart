import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/task_notifications/domain/home_notification.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';

TaskRecord record(
  String id, {
  TaskRecordKind kind = TaskRecordKind.legacyTask,
  TaskStatus status = TaskStatus.completed,
  String raw = 'COMPLETED',
  String title = '订餐厅 · 合成餐厅',
  String time = '2026-10-07T10:00:00Z',
}) => TaskRecord(
  id: id,
  kind: kind,
  status: status,
  rawStatus: raw,
  title: title,
  sessionId: kind == TaskRecordKind.conversation ? id : null,
  taskId: kind == TaskRecordKind.legacyTask ? id : null,
  callId: kind == TaskRecordKind.translation ? id : null,
  timestamp: time,
  scene: 'RESTAURANT_BOOKING',
  summary: '已确认包房',
);

void main() {
  test(
    'only effective source candidates, latest first and stable identity',
    () {
      final rows = [
        record('unknown', raw: 'UNRECOGNIZED', status: TaskStatus.running),
        record(
          'active-chat',
          kind: TaskRecordKind.conversation,
          status: TaskStatus.running,
        ),
        record('ordinary', kind: TaskRecordKind.call),
        record('older', time: '2026-10-06T10:00:00Z', title: '订餐厅 · 较早餐厅'),
        record('translation', kind: TaskRecordKind.translation),
        record('conversation', kind: TaskRecordKind.conversation),
        record('waiting', raw: 'WAITING', status: TaskStatus.running),
      ];
      final items = homeNotificationCandidates(rows);
      expect(items.map((e) => e.id), [
        'realtime_translation_call:translation',
        'conversation:conversation',
        'legacy_task:waiting',
        'legacy_task:older',
      ]);
      expect(items[2].text, contains('进行中'));
      final later = homeNotificationCandidates([
        record('waiting', raw: 'FAILED', status: TaskStatus.incomplete),
      ]);
      expect(later.single.id, 'legacy_task:waiting');
      expect(
        pendingHomeNotifications(later, {'legacy_task:waiting': 1}),
        isEmpty,
      );
    },
  );

  test('deduplicate before filtering read so old copies do not resurface', () {
    final items = homeNotificationCandidates([
      record('old', time: '2026-10-06T10:00:00Z'),
      record('new'),
    ]);
    expect(items.single.id, 'legacy_task:new');
    expect(pendingHomeNotifications(items, {'legacy_task:new': 1}), isEmpty);
    final separate = homeNotificationCandidates([
      record('a', kind: TaskRecordKind.conversation),
      record('b', kind: TaskRecordKind.conversation),
    ]);
    expect(separate, hasLength(2));
  });

  test(
    'plain source text and execution/running states do not fabricate success',
    () {
      final items = homeNotificationCandidates([
        record(
          'error',
          status: TaskStatus.executionError,
          raw: 'EXECUTION_ERROR',
        ),
        record(
          'interrupted',
          status: TaskStatus.running,
          raw: 'USER_INTERRUPTED',
        ),
      ]);
      expect(items.first.text, '订餐厅执行异常：合成餐厅 · 已确认包房 · 订餐厅 · 合成餐厅');
      expect(items.last.text, contains('进行中'));
      expect(items.every((e) => !e.text.contains('已完成')), isTrue);
    },
  );

  test(
    'read pruning protects live identities and bounds unrelated history',
    () {
      final now = DateTime.utc(2026, 10, 7).millisecondsSinceEpoch;
      final old = now - const Duration(days: 91).inMilliseconds;
      final reads = {
        'live': old,
        'expired': old,
        for (var i = 0; i < 600; i++) 'history:$i': now - i,
      };
      final pruned = pruneHomeNotificationReads(reads, {'live'}, now);
      expect(pruned['live'], old);
      expect(pruned.containsKey('expired'), isFalse);
      expect(
        pruned.length,
        513,
      ); // 512 newest plus an explicitly protected old entry.
      expect(pruned.containsKey('history:599'), isFalse);
    },
  );
}
