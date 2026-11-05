import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_page.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'task_pagination_test.dart' show Pages, row, page;

class _Mutations extends Pages implements TaskPinRepository {
  final pins = <Completer<TaskRecord>>[];
  Completer<void>? unread;
  final marked = <TaskRef>[];
  @override
  Future<TaskRecord> updatePin(TaskRef ref, bool pinned) {
    final next = Completer<TaskRecord>();
    pins.add(next);
    return next.future;
  }

  @override
  Future<void> clearUnread() async => unread?.future;

  @override
  Future<void> markRead(TaskRef ref) async {
    marked.add(ref);
    await unread?.future;
  }
}

void main() {
  test('late pin response cannot restore unread cleared during save', () async {
    final repo = _Mutations();
    final owner = TaskController(repo);
    final unread = row('a').copyWith(unreadResult: true);
    final load = owner.refresh(synchronizeStatus: false);
    repo.responses.single.complete(
      TaskPage(
        pinnedItems: [],
        items: [unread],
        nextOffset: 1,
        hasMore: false,
        hasUnread: true,
      ),
    );
    await load;
    final pin = owner.pin(unread);
    await owner.clearUnread();
    repo.pins.single.complete(unread.copyWith(pinnedAt: '2026-10-09'));
    await pin;
    expect(owner.state.pinnedItems.single.unreadResult, false);
    expect(owner.state.hasUnread, false);
    owner.dispose();
  });
  test(
    'pin stays local, uses returned target, adjusts cursor and rolls back failure',
    () async {
      final repo = _Mutations();
      final owner = TaskController(repo);
      final first = owner.refresh(synchronizeStatus: false);
      repo.responses.single.complete(page(['a', 'b'], next: 2, more: true));
      await first;
      final operation = owner.pin(row('b'));
      expect(owner.state.pinnedItems.map((r) => r.id), contains('b'));
      expect(owner.state.loading, isFalse);
      expect(await owner.pin(row('b')), isFalse);
      expect(repo.pins, hasLength(1));
      repo.pins.single.complete(
        row('b').copyWith(pinnedAt: '2026-10-09T10:00:00'),
      );
      expect(await operation, isTrue);
      expect(repo.offsets, [0]);
      final more = owner.loadMore();
      expect(repo.offsets, [0, 1]);
      repo.responses.last.complete(page(['a', 'c'], next: 3, more: true));
      await more;
      expect(
        owner.state.catalog.records.where((r) => r.id == 'a'),
        hasLength(1),
      );
      final failing = owner.pin(row('c'));
      repo.pins.last.completeError(StateError('offline'));
      expect(await failing, isFalse);
      expect(owner.state.catalog.records.last.id, 'c');
      expect(owner.state.catalog.records.last.pinnedAt, isNull);
      expect(repo.offsets, [0, 1]);
      final afterRollback = owner.loadMore();
      expect(
        repo.offsets.last,
        3,
        reason: 'rollback restores the covered normal window',
      );
      repo.responses.last.complete(page(['d'], next: 4));
      await afterRollback;
      owner.dispose();
    },
  );
  test(
    'clear unread is immediate and failed save restores flags without page reload',
    () async {
      final repo = _Mutations()..unread = Completer<void>();
      final owner = TaskController(repo);
      final load = owner.refresh(synchronizeStatus: false);
      repo.responses.single.complete(
        TaskPage(
          pinnedItems: [
            row('p').copyWith(pinnedAt: '2026-10-08', unreadResult: true),
          ],
          items: [row('a').copyWith(unreadResult: true)],
          nextOffset: 1,
          hasMore: true,
          hasUnread: true,
        ),
      );
      await load;
      final clear = owner.clearUnread();
      expect(owner.state.hasUnread, isFalse);
      expect(owner.state.catalog.records.every((r) => !r.unreadResult), isTrue);
      repo.unread!.completeError(StateError('offline'));
      expect(await clear, isFalse);
      expect(owner.state.hasUnread, isTrue);
      expect(owner.state.catalog.records.every((r) => r.unreadResult), isTrue);
      expect(owner.state.notice, '清除未读失败，请稍后重试');
      expect(repo.offsets, [0]);
      owner.dispose();
    },
  );
  test(
    'marking a row read clears the loaded row after server success',
    () async {
      final repo = _Mutations();
      final owner = TaskController(repo);
      final load = owner.refresh(synchronizeStatus: false);
      repo.responses.single.complete(
        TaskPage(
          pinnedItems: [row('pin').copyWith(unreadResult: true)],
          items: [row('a').copyWith(unreadResult: true)],
          nextOffset: 2,
          hasMore: false,
          hasUnread: true,
        ),
      );
      await load;

      expect(await owner.markRead(owner.state.catalog.records.first), isTrue);
      expect(repo.marked, [
        const TaskRef(TaskResourceType.agentConversation, 'pin'),
      ]);
      expect(owner.state.pinnedItems.single.unreadResult, isFalse);
      expect(owner.state.catalog.records.any((row) => row.unreadResult), isTrue);
      expect(owner.state.hasUnread, isTrue);
      owner.dispose();
    },
  );
  test('refresh and account disposal invalidate late pin target', () async {
    final repo = _Mutations();
    final owner = TaskController(repo);
    final load = owner.refresh(synchronizeStatus: false);
    repo.responses.single.complete(page(['a']));
    await load;
    final pin = owner.pin(row('a'));
    final refresh = owner.refresh(synchronizeStatus: false);
    repo.responses.last.complete(page(['fresh']));
    await refresh;
    repo.pins.single.complete(row('a').copyWith(pinnedAt: '2026-10-09'));
    await pin;
    expect(owner.state.catalog.records.map((r) => r.id), isNot(contains('a')));
    owner.dispose();
  });
}
