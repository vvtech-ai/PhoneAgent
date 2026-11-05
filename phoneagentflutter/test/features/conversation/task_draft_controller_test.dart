import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/drafts/task_draft.dart';
import 'package:phone_agent/features/conversation/data/drafts/secure_task_draft_repository.dart';
import 'package:phone_agent/features/conversation/presentation/controller/task_draft_controller.dart';

class _Drafts implements TaskDraftRepository {
  TaskDraft? saved = const TaskDraft('原草稿', start: 1, end: 2);
  Completer<TaskDraft?>? pending;
  @override
  Future<TaskDraft?> read() async => pending == null ? saved : pending!.future;
  @override
  Future<void> save(TaskDraft? draft) async {
    saved = draft;
  }
}

void main() {
  test(
    'classification waits for actual acknowledgement and explicit clearing wins failure',
    () async {
      final store = _Drafts();
      final c = TaskDraftController(
        store,
        pendingCommand: (_) => 'awaiting-input',
        notice: (_) {},
      );
      await c.load();
      c.submit((_) => true);
      await Future<void>.delayed(Duration.zero);
      expect(store.saved, isNull);
      c.observe({}, false, nextCommand: 'classified-command');
      c.observe({'classified-command'}, false);
      await Future<void>.delayed(Duration.zero);
      expect(store.saved, isNull);
      c.edit(const TaskDraft('新的提交'));
      c.submit((_) => true);
      c.edit(const TaskDraft(''));
      c.observe({}, true);
      expect(c.value.text, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(store.saved, isNull);
      c.dispose();
    },
  );
  test(
    'display-only classification clears draft without an Agent command',
    () async {
      final store = _Drafts();
      final c = TaskDraftController(
        store,
        pendingCommand: (_) => 'awaiting-input',
        notice: (_) {},
      );
      await c.load();
      c.submit((_) => true);
      c.observe({}, false, settled: true);
      await Future<void>.delayed(Duration.zero);
      expect(store.saved, isNull);
      c.dispose();
    },
  );
  test(
    'send clears persisted draft immediately and unaccepted failure restores it',
    () async {
      final store = _Drafts();
      final c = TaskDraftController(
        store,
        pendingCommand: (_) => 'new-command',
        notice: (_) {},
      );
      await c.load();
      expect(c.value.text, '原草稿');
      expect(c.value.start, 1);
      expect(c.submit((_) => false), isFalse);
      expect(c.value.text, '原草稿');
      expect(c.submit((_) => true), isTrue);
      expect(c.value.text, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(store.saved, isNull);
      c.observe({}, true);
      expect(c.value.text, '原草稿');
      expect(c.submit((_) => true), isTrue);
      c.observe({'new-command'}, false);
      await Future<void>.delayed(Duration.zero);
      expect(store.saved, isNull);
      c.dispose();
    },
  );
  test(
    'leaving immediately after sending does not restore submitted input',
    () async {
      final store = _Drafts();
      final first = TaskDraftController(
        store,
        pendingCommand: (_) => 'command',
        notice: (_) {},
      );
      await first.load();
      first.submit((_) => true);
      first.dispose();
      final reopened = TaskDraftController(
        store,
        pendingCommand: (_) => null,
        notice: (_) {},
      );
      await reopened.load();
      expect(reopened.value.text, isEmpty);
      reopened.dispose();
    },
  );
  test(
    'late failure never restores submitted text over newer typing',
    () async {
      final store = _Drafts();
      final c = TaskDraftController(
        store,
        pendingCommand: (_) => 'command',
        notice: (_) {},
      );
      await c.load();
      c.submit((_) => true);
      c.edit(const TaskDraft('后续输入'));
      c.observe({}, true);
      await Future<void>.delayed(Duration.zero);
      expect(c.value.text, '后续输入');
      expect(store.saved!.text, '后续输入');
      c.dispose();
    },
  );
  test(
    'late restore cannot replace typing; later acknowledgement retains a newer draft',
    () async {
      final store = _Drafts()..pending = Completer<TaskDraft?>();
      final c = TaskDraftController(
        store,
        pendingCommand: (_) => 'command',
        notice: (_) {},
      );
      final loading = c.load();
      c.edit(const TaskDraft('新的输入'));
      store.pending!.complete(const TaskDraft('旧响应'));
      await loading;
      expect(c.value.text, '新的输入');
      c.submit((_) => true);
      c.edit(const TaskDraft('下一条草稿'));
      c.observe({'command'}, false);
      await Future<void>.delayed(Duration.zero);
      expect(store.saved!.text, '下一条草稿');
      c.dispose();
    },
  );
  test(
    'persistent keys isolate environment, endpoint, account and session',
    () {
      final scopes = [
        ['dev', 'https://a', 'account', 'session'],
        ['prod', 'https://a', 'account', 'session'],
        ['dev', 'https://b', 'account', 'session'],
        ['dev', 'https://a', 'other', 'session'],
        ['dev', 'https://a', 'account', 'other'],
      ];
      expect(
        scopes
            .map((scope) => SecureTaskDraftRepository(scope).key)
            .toSet()
            .length,
        5,
      );
    },
  );
}
