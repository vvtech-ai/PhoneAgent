import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/task_notifications/domain/home_notification.dart';
import 'package:phone_agent/features/task_notifications/presentation/controller/home_notification_controller.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';

TaskRecord row(String id) => TaskRecord(
  id: id,
  taskId: id,
  title: '合成通知 $id',
  kind: TaskRecordKind.legacyTask,
  rawStatus: 'COMPLETED',
  status: TaskStatus.completed,
);

void main() {
  test(
    'storage retry preserves failed snapshot without reading future items',
    () async {
      final store = _Store()..failSave = true;
      final controller = HomeNotificationController(
        store,
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      controller.replaceRecords([row('a'), row('b')]);
      await controller.load();
      await controller.markAllPendingRead();
      controller.replaceRecords([row('a'), row('b'), row('future')]);
      store.failSave = false;
      await controller.retryStorage();
      expect(controller.state.pending.single.id, 'legacy_task:future');
      expect(controller.state.notice, isEmpty);
    },
  );
  test(
    'hydrate before showing unread; read failure hides unverified count',
    () async {
      final store = _Store()..failLoad = true;
      final controller = HomeNotificationController(
        store,
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      controller.replaceRecords([row('a')]);
      await controller.load();
      expect(controller.state.pending, isEmpty);
      expect(controller.state.ready, isFalse);
      expect(controller.state.notice, '通知读取失败，请重试');
      store.failLoad = false;
      await controller.load();
      expect(controller.state.pending.single.id, 'legacy_task:a');
      await controller.markAllPendingRead();
      await controller.load();
      expect(controller.state.pending, isEmpty);
    },
  );

  test(
    'save failure preserves current notification and explicit retry',
    () async {
      final store = _Store()..failSave = true;
      final controller = HomeNotificationController(
        store,
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      controller.replaceRecords([row('a'), row('b')]);
      await controller.load();
      await controller.dismissCurrent();
      expect(controller.state.pending, hasLength(2));
      expect(controller.state.notice, '通知已读状态保存失败，请重试');
      expect(controller.state.saving, isFalse);
      store.failSave = false;
      await controller.dismissCurrent();
      expect(controller.state.pending.single.id, 'legacy_task:b');
      expect(controller.state.notice, isEmpty);
    },
  );

  test(
    'queued writes single flight and mark only presented snapshot',
    () async {
      final store = _Store()..saveGate = Completer();
      final controller = HomeNotificationController(
        store,
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      controller.replaceRecords([row('a')]);
      await controller.load();
      final first = controller.dismissCurrent();
      final duplicate = controller.dismissCurrent();
      await Future<void>.delayed(Duration.zero);
      expect(store.saves, 1);
      controller.replaceRecords([row('a'), row('b')]);
      final current = controller.markAllPendingRead();
      controller.replaceRecords([row('a'), row('b'), row('future')]);
      store.saveGate!.complete();
      await Future.wait([first, duplicate, current]);
      expect(store.saves, 2);
      expect(controller.state.pending.single.id, 'legacy_task:future');
      expect(controller.state.saving, isFalse);
      expect(store.entries.keys, {'legacy_task:a', 'legacy_task:b'});
    },
  );

  test(
    'account change suppresses late hydration and prevents writes',
    () async {
      final store = _Store()..loadGate = Completer();
      var current = true;
      final controller = HomeNotificationController(
        store,
        isCurrent: () => current,
      );
      addTearDown(controller.dispose);
      controller.replaceRecords([row('a')]);
      final pending = controller.load();
      current = false;
      store.loadGate!.complete();
      await pending;
      expect(controller.state.ready, isFalse);
      await controller.markTaskRead(taskId: 'a');
      expect(store.saves, 0);
    },
  );

  test('owner change while saving does not publish an old success', () async {
    final store = _Store()..saveGate = Completer();
    var current = true;
    final controller = HomeNotificationController(
      store,
      isCurrent: () => current,
    );
    addTearDown(controller.dispose);
    controller.replaceRecords([row('a')]);
    await controller.load();
    final saving = controller.markTaskRead(taskId: 'a');
    await Future<void>.delayed(Duration.zero);
    current = false;
    store.saveGate!.complete();
    await saving;
    expect(controller.state.readAtMillis, isEmpty);
  });

  test(
    'disposed owner ignores late result without background state change',
    () async {
      final store = _Store()..loadGate = Completer();
      final controller = HomeNotificationController(
        store,
        isCurrent: () => true,
      );
      final loading = controller.load();
      controller.dispose();
      store.loadGate!.complete();
      await loading;
    },
  );
}

class _Store implements HomeNotificationReadStore {
  var entries = <String, int>{};
  bool failLoad = false, failSave = false;
  int saves = 0;
  Completer<void>? loadGate, saveGate;
  @override
  Future<Map<String, int>> load() async {
    await loadGate?.future;
    if (failLoad) throw StateError('synthetic');
    return Map.of(entries);
  }

  @override
  Future<void> save(Map<String, int> next) async {
    saves++;
    await saveGate?.future;
    if (failSave) throw StateError('synthetic');
    entries = Map.of(next);
  }
}
