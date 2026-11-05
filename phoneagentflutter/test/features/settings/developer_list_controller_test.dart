import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/controller/developer_list_controller.dart';
import '../dialer/app_call_record_repository_test.dart'
    show MemoryRecords, record;

void main() {
  late MemoryRecords memory;
  late DeveloperListController controller;
  var tasks = 0, contacts = 0, clears = 0;
  var tasksOk = true, contactsOk = true;
  Completer<void>? taskGate;
  setUp(() {
    memory = MemoryRecords();
    tasks = 0;
    contacts = 0;
    clears = 0;
    tasksOk = true;
    contactsOk = true;
    taskGate = null;
    controller = DeveloperListController(
      records: memory.create(),
      refreshTasks: () async {
        tasks++;
        await taskGate?.future;
        return tasksOk;
      },
      reloadContacts: () async {
        contacts++;
        return contactsOk;
      },
      clearContacts: () {
        clears++;
      },
    );
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  test('Filled clears records and refreshes, never fabricates data', () async {
    await controller.records!.append(record('1'));
    await controller.apply(DeveloperListMode.filled);
    expect(await controller.records!.load(), isEmpty);
    expect([tasks, contacts, clears], [1, 1, 0]);
    expect(controller.state.mode, DeveloperListMode.filled);
    expect(controller.state.failed, isFalse);
  });
  test(
    'Empty clears local records and contacts only, repeated action still works',
    () async {
      await controller.records!.append(record('1'));
      await controller.apply(DeveloperListMode.empty);
      await controller.records!.append(record('2'));
      await controller.apply(DeveloperListMode.empty);
      expect(await controller.records!.load(), isEmpty);
      expect([tasks, contacts, clears], [0, 0, 2]);
      expect(controller.state.message, contains('后台任务未删除'));
    },
  );
  test('failed clear stops other consumers and can retry', () async {
    memory.failWrite = true;
    await controller.apply(DeveloperListMode.filled);
    expect([tasks, contacts, clears], [0, 0, 0]);
    expect(controller.state.failed, isTrue);
    expect(controller.state.mode, DeveloperListMode.empty);
    memory.failWrite = false;
    await controller.apply(DeveloperListMode.filled);
    expect(controller.state.failed, isFalse);
  });
  test(
    'partial refresh failure remains visible without rolling back successful clear',
    () async {
      tasksOk = false;
      contactsOk = false;
      await controller.apply(DeveloperListMode.filled);
      expect(controller.state.failed, isTrue);
      expect(controller.state.message, contains('本机通话记录已清空'));
      expect(controller.state.message, contains('任务刷新失败'));
      expect(controller.state.message, contains('联系人列表处理失败'));
      expect([tasks, contacts], [1, 1]);
    },
  );
  test('double click is single flight', () async {
    taskGate = Completer();
    final pending = controller.apply(DeveloperListMode.filled);
    await Future<void>.delayed(Duration.zero);
    await controller.apply(DeveloperListMode.empty);
    expect(controller.state.busy, isTrue);
    taskGate!.complete();
    await pending;
    expect([tasks, contacts, clears], [1, 1, 0]);
    expect(memory.writes, 1);
  });
  test('dispose while clear pending does not invoke next consumers', () async {
    memory.readGate = Completer();
    final pending = controller.apply(DeveloperListMode.filled);
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    memory.readGate!.complete();
    await pending;
    expect([tasks, contacts, clears], [0, 0, 0]);
  });
  test(
    'dispose while task refresh pending does not read new account contacts',
    () async {
      taskGate = Completer();
      final pending = controller.apply(DeveloperListMode.filled);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      taskGate!.complete();
      await pending;
      expect([tasks, contacts, clears], [1, 0, 0]);
    },
  );
  test(
    'no account repository shows unavailable without touching consumers',
    () async {
      final c = DeveloperListController(
        records: null,
        refreshTasks: () async => throw StateError('must not call'),
        reloadContacts: () async => throw StateError('must not call'),
        clearContacts: () => throw StateError('must not call'),
      );
      addTearDown(c.dispose);
      await c.apply(DeveloperListMode.empty);
      expect(c.state.failed, isTrue);
    },
  );
}
