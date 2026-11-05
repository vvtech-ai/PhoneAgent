import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/domain/task_page.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';

TaskRecord row(String id) => TaskRecord(
  id: id,
  kind: TaskRecordKind.conversation,
  title: id,
  status: TaskStatus.running,
  rawStatus: 'RUNNING',
  sessionId: id,
  ref: TaskRef(TaskResourceType.agentConversation, id),
  canDelete: true,
);
TaskPage page(List<String> ids, {int next = 15, bool more = false}) => TaskPage(
  pinnedItems: [row('pin')],
  items: ids.map(row).toList(),
  nextOffset: next,
  hasMore: more,
  hasUnread: true,
);

class Pages implements PagedTaskRepository {
  final offsets = <int>[];
  final responses = <Completer<TaskPage>>[];
  int legacyCalls = 0, hides = 0;
  Completer<void>? mutation;
  @override
  Future<TaskPage> loadPage({int offset = 0, int limit = 15}) {
    expect(limit, 15);
    offsets.add(offset);
    final pending = Completer<TaskPage>();
    responses.add(pending);
    return pending.future;
  }

  @override
  Future<List<TaskRecord>> load(TaskSource source) async {
    legacyCalls++;
    return [row('old')];
  }

  @override
  Future<void> pin(TaskRef ref, bool pinned) async => mutation?.future;
  @override
  Future<void> hide(TaskRef ref) async {
    hides++;
    await mutation?.future;
  }

  @override
  Future<void> markRead(TaskRef ref) async {}
  @override
  Future<void> clearUnread() async {}
}

void main() {
  test(
    'non advancing server cursor retains a retry instead of hiding remaining rows',
    () async {
      final repo = Pages();
      final owner = TaskController(repo);
      final first = owner.refresh(synchronizeStatus: false);
      repo.responses[0].complete(page(['cached'], more: true));
      await first;
      final more = owner.loadMore();
      repo.responses[1].complete(page(['bad'], next: 15, more: true));
      await more;
      expect(owner.state.moreFailed, true);
      expect(owner.state.hasMore, true);
      expect(owner.state.catalog.records.last.id, 'cached');
      final retry = owner.loadMore();
      expect(repo.offsets, [0, 15, 15]);
      repo.responses[2].complete(page(['next'], next: 30));
      await retry;
      expect(owner.state.catalog.records.last.id, 'next');
      owner.dispose();
    },
  );
  test(
    'failed pending status sync still loads the authoritative task page',
    () async {
      final repo = Pages();
      final owner = TaskController(
        repo,
        beforeRefresh: () async {
          throw StateError('offline');
        },
      );
      final load = owner.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(repo.offsets, [0]);
      repo.responses.single.complete(page(['server']));
      await load;
      expect(owner.state.catalog.records.last.id, 'server');
      expect(
        owner.state.catalog.failedSources,
        contains(TaskSource.conversations),
      );
      owner.dispose();
    },
  );
  test(
    'production controller loads unified first page preserving order',
    () async {
      final repo = Pages();
      final c = TaskController(repo);
      final first = c.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(repo.legacyCalls, 0);
      expect(repo.offsets, [0]);
      repo.responses.single.complete(page(['z', 'a']));
      await first;
      expect(c.state.catalog.records.map((r) => r.id), ['pin', 'z', 'a']);
      c.dispose();
    },
  );
  test(
    'refresh discards late page and load more deduplicates without sorting',
    () async {
      final repo = Pages();
      final owner = TaskController(repo);
      final first = owner.refresh(synchronizeStatus: false);
      final newer = owner.refresh(synchronizeStatus: false);
      repo.responses[1].complete(page(['z', 'a'], more: true));
      await newer;
      repo.responses[0].complete(page(['obsolete']));
      await first;
      expect(owner.state.catalog.records.map((r) => r.id), ['pin', 'z', 'a']);
      final more = owner.loadMore();
      await owner.loadMore();
      expect(repo.offsets, [0, 0, 15]);
      repo.responses[2].complete(page(['a', 'b'], next: 30, more: true));
      await more;
      expect(owner.state.catalog.records.map((r) => r.id), [
        'pin',
        'z',
        'a',
        'b',
      ]);
      final late = owner.loadMore();
      final refresh = owner.refresh(synchronizeStatus: false);
      repo.responses[4].complete(page(['fresh']));
      await refresh;
      repo.responses[3].complete(page(['late']));
      await late;
      expect(owner.state.catalog.records.map((r) => r.id), ['pin', 'fresh']);
      owner.dispose();
    },
  );
  test(
    'page failure retains rows and retries the same cursor; dispose isolates account',
    () async {
      final repo = Pages();
      final owner = TaskController(repo);
      final initial = owner.refresh(synchronizeStatus: false);
      repo.responses[0].complete(page(['cached'], more: true));
      await initial;
      final failed = owner.loadMore();
      repo.responses[1].completeError(StateError('offline'));
      await failed;
      expect(owner.state.moreFailed, true);
      expect(owner.state.catalog.records.last.id, 'cached');
      final retry = owner.loadMore();
      expect(repo.offsets, [0, 15, 15]);
      owner.dispose();
      repo.responses[2].complete(page(['other-account']));
      await retry;
    },
  );
  test(
    'delete is single flight and blocked delete never reaches transport',
    () async {
      final repo = Pages()..mutation = Completer<void>();
      final owner = TaskController(repo);
      final operation = owner.hide(row('deletable'));
      final feedback = <String>[];
      final subscription = owner.state.operationFeedback!.listen(
        (result) => feedback.add(result.message),
      );
      expect(await owner.hide(row('deletable')), false);
      expect(repo.hides, 1);
      final blocked = TaskRecord(
        id: 'blocked',
        kind: TaskRecordKind.conversation,
        title: 'blocked',
        status: TaskStatus.running,
        rawStatus: 'RUNNING',
        ref: const TaskRef(TaskResourceType.agentConversation, 'blocked'),
      );
      expect(await owner.hide(blocked), false);
      expect(repo.hides, 1);
      repo.mutation!.completeError(StateError('offline'));
      expect(await operation, false);
      expect(owner.state.busy, isEmpty);
      expect(owner.state.notice, '正在通话的任务不能删除');
      expect(feedback, ['任务删除失败，请稍后重试']);
      await subscription.cancel();
      owner.dispose();
    },
  );
}
