import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_page.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_operation_feedback.dart';
import 'task_pagination_test.dart' show row;

class _Repository implements PagedTaskRepository, TaskPinRepository {
  final loads = <Completer<TaskPage>>[];
  final deletes = <String, Completer<void>>{};
  final pins = <String, Completer<TaskRecord>>{};

  @override
  Future<TaskPage> loadPage({int offset = 0, int limit = 15}) {
    final result = Completer<TaskPage>();
    loads.add(result);
    return result.future;
  }

  @override
  Future<void> hide(TaskRef ref) =>
      (deletes[ref.id] = Completer<void>()).future;
  @override
  Future<TaskRecord> updatePin(TaskRef ref, bool pinned) =>
      (pins[ref.id] = Completer<TaskRecord>()).future;
  @override
  Future<void> pin(TaskRef ref, bool pinned) => throw UnimplementedError();
  @override
  Future<void> clearUnread() async {}
  @override
  Future<void> markRead(TaskRef ref) async {}
  @override
  Future<List<TaskRecord>> load(TaskSource source) =>
      throw UnimplementedError();
}

TaskPage _page(List<TaskRecord> rows) => TaskPage(
  pinnedItems: rows.where((r) => r.pinnedAt != null).toList(),
  items: rows.where((r) => r.pinnedAt == null).toList(),
  nextOffset: rows.where((r) => r.pinnedAt == null).length,
  hasMore: false,
  hasUnread: rows.any((r) => r.unreadResult),
);

void main() {
  for (final pinB in [false, true]) {
    testWidgets(
      'late delete A page cannot overwrite completed ${pinB ? 'pin' : 'delete'} B',
      (tester) async {
        final repo = _Repository();
        final controller = TaskController(repo);
        addTearDown(controller.dispose);
        final effects = <TaskOperationFeedback>[];
        final subscription = controller.state.operationFeedback!.listen(
          effects.add,
        );
        addTearDown(subscription.cancel);
        final initial = controller.refresh(synchronizeStatus: false);
        repo.loads.single.complete(_page([row('a'), row('b')]));
        await initial;
        final a = controller.hide(row('a'));
        final b = pinB ? controller.pin(row('b')) : controller.hide(row('b'));
        repo.deletes['a']!.complete();
        await tester.pump();
        expect(repo.loads, hasLength(2));
        final staleLoad = repo.loads.last;
        final stalePage = _page([row('b')]);
        expect(controller.state.loading, isTrue);
        if (pinB) {
          repo.pins['b']!.complete(row('b').copyWith(pinnedAt: '2026-10-21'));
        } else {
          repo.deletes['b']!.complete();
          await tester.pump();
          expect(repo.loads, hasLength(3));
          repo.loads.last.complete(_page([]));
        }
        expect(await b, isTrue);
        expect(effects.map((e) => e.target.id), ['b']);
        staleLoad.complete(stalePage);
        expect(await a, isTrue);
        if (pinB) {
          expect(controller.state.pinnedItems.map((r) => r.id), ['b']);
          expect(
            controller.state.catalog.records.single.pinnedAt,
            '2026-10-21',
          );
          expect(repo.loads, hasLength(2));
        } else {
          expect(controller.state.catalog.records, isEmpty);
          expect(controller.state.notificationRecords, isEmpty);
        }
        expect(controller.state.loading, isFalse);
        expect(controller.state.loadingMore, isFalse);
        expect(controller.state.busy, isEmpty);
        expect(effects.map((e) => e.target.id), ['b', 'a']);
        expect(effects.every((e) => e.succeeded), isTrue);
      },
    );
  }

  for (final pinB in [false, true]) {
    testWidgets(
      'delete A reconciliation preserves pending ${pinB ? 'pin' : 'delete'} B',
      (tester) async {
        final repo = _Repository();
        final drafts = <String>[];
        final controller = TaskController(
          repo,
          afterHide: (r) async => drafts.add(r.id),
        );
        addTearDown(controller.dispose);
        final effects = <TaskOperationFeedback>[];
        final subscription = controller.state.operationFeedback!.listen(
          effects.add,
        );
        addTearDown(subscription.cancel);
        final initial = controller.refresh(synchronizeStatus: false);
        repo.loads.single.complete(_page([row('a'), row('b')]));
        await initial;
        final a = controller.hide(row('a'));
        final b = pinB ? controller.pin(row('b')) : controller.hide(row('b'));
        expect(await controller.hide(row('a')), isFalse);
        expect(
          await (pinB ? controller.pin(row('b')) : controller.hide(row('b'))),
          isFalse,
        );
        repo.deletes['a']!.complete();
        await tester.pump();
        expect(repo.loads, hasLength(2));
        repo.loads.last.complete(_page([row('b')]));
        expect(await a, isTrue);
        expect(controller.state.catalog.records.single.id, 'b');
        expect(effects.map((e) => e.target.id), ['a']);
        if (pinB) {
          repo.pins['b']!.complete(row('b').copyWith(pinnedAt: '2026-10-21'));
          expect(await b, isTrue);
          expect(controller.state.pinnedItems.single.id, 'b');
          expect(
            controller.state.catalog.records.single.pinnedAt,
            '2026-10-21',
          );
          expect(repo.loads, hasLength(2));
        } else {
          repo.deletes['b']!.complete();
          await tester.pump();
          expect(controller.state.catalog.records, isEmpty);
          expect(repo.loads, hasLength(3));
          repo.loads.last.complete(_page([]));
          expect(await b, isTrue);
          expect(controller.state.notificationRecords, isEmpty);
        }
        expect(effects.map((e) => e.target.id), ['a', 'b']);
        expect(effects.every((e) => e.succeeded), isTrue);
        expect(repo.deletes.keys, pinB ? ['a'] : ['a', 'b']);
        expect(repo.pins.keys, pinB ? ['b'] : isEmpty);
        expect(drafts, pinB ? ['a'] : ['a', 'b']);
        expect(controller.state.busy, isEmpty);
      },
    );
  }
}
