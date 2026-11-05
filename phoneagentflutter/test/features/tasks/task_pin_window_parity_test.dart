import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_page.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'task_pagination_test.dart' show Pages;

TaskRecord _row(String id, int day, {bool pinned = false}) => TaskRecord(
  id: id,
  kind: TaskRecordKind.conversation,
  title: id,
  status: TaskStatus.completed,
  rawStatus: 'COMPLETED',
  sessionId: id,
  timestamp: '2026-10-${day.toString().padLeft(2, '0')}',
  ref: TaskRef(TaskResourceType.agentConversation, id),
  pinnedAt: pinned ? '2026-10-15' : null,
);

class _Pins extends Pages implements TaskPinRepository {
  final saved = Completer<TaskRecord>();
  @override
  Future<TaskRecord> updatePin(TaskRef ref, bool pinned) => saved.future;
}

void main() {
  test(
    'failed old unpin does not restore unread cleared during save',
    () async {
      final repo = _Pins();
      final controller = TaskController(repo);
      addTearDown(controller.dispose);
      final old = _row('old', 1, pinned: true).copyWith(unreadResult: true);
      final load = controller.refresh(synchronizeStatus: false);
      repo.responses.single.complete(
        TaskPage(
          pinnedItems: [old],
          items: [_row('new', 15)],
          nextOffset: 1,
          hasMore: true,
          hasUnread: true,
        ),
      );
      await load;
      final save = controller.pin(old);
      await controller.clearUnread();
      repo.saved.completeError(StateError('offline'));
      expect(await save, isFalse);
      expect(controller.state.hasUnread, isFalse);
      expect(controller.state.pinnedItems.single.unreadResult, isFalse);
    },
  );
  for (final fail in [false, true]) {
    test(
      'old unpin preserves loaded window on ${fail ? 'failure' : 'success'}',
      () async {
        final repo = _Pins();
        final controller = TaskController(repo);
        addTearDown(controller.dispose);
        final old = _row(
          'old',
          1,
          pinned: true,
        ).copyWith(pinnedAt: '2026-10-16');
        final load = controller.refresh(synchronizeStatus: false);
        repo.responses.single.complete(
          TaskPage(
            pinnedItems: [old, _row('other-pin', 2, pinned: true)],
            items: [_row('new', 15)],
            nextOffset: 1,
            hasMore: true,
            hasUnread: true,
          ),
        );
        await load;
        final save = controller.pin(old);
        expect(controller.state.catalog.records.map((r) => r.id), [
          'other-pin',
          'new',
        ]);
        if (fail) {
          repo.saved.completeError(StateError('offline'));
        } else {
          repo.saved.complete(old.copyWith(clearPin: true));
        }
        expect(await save, !fail);
        expect(
          controller.state.catalog.records.map((r) => r.id),
          fail ? ['old', 'other-pin', 'new'] : ['other-pin', 'new'],
        );
        final more = controller.loadMore();
        expect(repo.offsets, [0, 1]);
        repo.responses.last.complete(
          TaskPage(
            pinnedItems: fail
                ? [old, _row('other-pin', 2, pinned: true)]
                : [_row('other-pin', 2, pinned: true)],
            items: [
              fail ? _row('older-normal', 1) : old.copyWith(clearPin: true),
            ],
            nextOffset: 2,
            hasMore: false,
            hasUnread: true,
          ),
        );
        await more;
      },
    );
  }
}
