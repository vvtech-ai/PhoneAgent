import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_command.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_sync.dart';

void main() {
  late _Store store;
  late _Gateway gateway;
  late TaskErrorStatusSync sync;
  var active = true, id = 0;
  setUp(() {
    store = _Store();
    gateway = _Gateway();
    active = true;
    id = 0;
    sync = TaskErrorStatusSync(
      store: store,
      gateway: gateway,
      isCurrent: () => active,
      nextId: () => 'cmd-${++id}',
    );
  });

  test('write before send, successful completion removes pending', () async {
    gateway.handle = (c) async {
      expect(store.values[c.sessionId]?.commandId, c.commandId);
      return 'COMPLETED';
    };
    await sync.record('s', TaskErrorStatusReason.exited);
    expect(gateway.sent.single.reason, TaskErrorStatusReason.exited);
    expect(sync.pendingExitSessions, isEmpty);
    expect(store.values, isEmpty);
  });
  test(
    'failed request keeps identity across retry and process reconstruction',
    () async {
      gateway.handle = (_) async => throw StateError('offline');
      await sync.record('s', TaskErrorStatusReason.exited);
      final command = gateway.sent.single;
      expect(sync.pendingExitSessions, {'s'});
      expect(gateway.sent, hasLength(1));
      sync.close();
      sync = TaskErrorStatusSync(
        store: store,
        gateway: gateway,
        isCurrent: () => active,
      );
      gateway.handle = (_) async => 'EXECUTION_ERROR';
      await sync.flush();
      expect(gateway.sent.last.commandId, command.commandId);
      expect(store.values, isEmpty);
    },
  );
  test(
    'write failure never sends and retains memory for later trigger',
    () async {
      store.failWrite = true;
      await sync.record('s', TaskErrorStatusReason.exited);
      expect(gateway.sent, isEmpty);
      expect(sync.pendingExitSessions, {'s'});
      store.failWrite = false;
      await sync.flush();
      expect(gateway.sent, hasLength(1));
    },
  );
  test('damaged store never becomes an empty successful queue', () async {
    store.failRead = true;
    await sync.record('s', TaskErrorStatusReason.exited);
    expect(store.writes, 0);
    expect(gateway.sent, isEmpty);
    expect(sync.hasPending, isTrue);
    store.failRead = false;
    await sync.flush();
    expect(gateway.sent, hasLength(1));
  });
  test('simultaneous flushes do not duplicate an in-flight request', () async {
    final gate = Completer<String>();
    final entered = Completer<void>();
    gateway.handle = (_) {
      entered.complete();
      return gate.future;
    };
    final recorded = sync.record('s', TaskErrorStatusReason.exited);
    await entered.future;
    final a = sync.flush(), b = sync.flush();
    expect(gateway.sent, hasLength(1));
    gate.complete('EXECUTION_ERROR');
    await Future.wait([recorded, a, b]);
    expect(gateway.sent, hasLength(1));
  });
  test(
    'new recovery supersedes exit and cannot be deleted by late exit ack',
    () async {
      final gate = Completer<String>(), entered = Completer<void>();
      gateway.handle = (c) {
        if (c.reason == TaskErrorStatusReason.exited) {
          entered.complete();
          return gate.future;
        }
        return Future.error(StateError('retry later'));
      };
      final old = sync.record('s', TaskErrorStatusReason.exited);
      await entered.future;
      final newer = sync.record('s', TaskErrorStatusReason.recovered);
      expect(sync.pendingExitSessions, isEmpty); // not a RUNNING overlay
      // New recovery reaches durable storage while the old HTTP request is stuck.
      await Future<void>.delayed(Duration.zero);
      expect(store.values['s']?.reason, TaskErrorStatusReason.recovered);
      gate.complete('EXECUTION_ERROR');
      await Future.wait([old, newer]);
      expect(gateway.sent.map((c) => c.reason), [
        TaskErrorStatusReason.exited,
        TaskErrorStatusReason.recovered,
      ]);
      expect(store.values['s']?.reason, TaskErrorStatusReason.recovered);
    },
  );
  test('latest unsent command wins, not each obsolete transition', () async {
    final a = sync.record('s', TaskErrorStatusReason.exited);
    final b = sync.record('s', TaskErrorStatusReason.recovered);
    final c = sync.record('s', TaskErrorStatusReason.exited);
    await Future.wait([a, b, c]);
    expect(gateway.sent.single.commandId, 'cmd-3');
  });
  test(
    'failed acknowledgement reuses same persisted command, not new identity',
    () async {
      store.failRemove = true;
      await sync.record('s', TaskErrorStatusReason.exited);
      expect(sync.hasPending, isTrue);
      expect(sync.pendingExitSessions, isEmpty);
      store.failRemove = false;
      await sync.flush();
      expect(gateway.sent.map((c) => c.commandId).toSet(), {'cmd-1'});
      expect(gateway.sent, hasLength(1)); // only local acknowledgement retries
      expect(sync.hasPending, isFalse);
    },
  );
  test(
    'account change during request stops ack and all later sessions',
    () async {
      final gate = Completer<String>(), entered = Completer<void>();
      gateway.handle = (_) {
        entered.complete();
        return gate.future;
      };
      final first = sync.record('s', TaskErrorStatusReason.exited);
      await entered.future;
      final second = sync.record('t', TaskErrorStatusReason.exited);
      active = false;
      gate.complete('EXECUTION_ERROR');
      await Future.wait([first, second]);
      expect(gateway.sent, hasLength(1));
      expect(store.values.containsKey('s'), isTrue);
      await sync.record('u', TaskErrorStatusReason.exited);
      expect(gateway.sent, hasLength(1));
    },
  );
  test(
    'one failed session does not prevent other session synchronization',
    () async {
      gateway.handle = (c) async {
        if (c.sessionId == 's') throw StateError('offline');
        return 'RUNNING';
      };
      await Future.wait([
        sync.record('s', TaskErrorStatusReason.exited),
        sync.record('t', TaskErrorStatusReason.recovered),
      ]);
      expect(gateway.sent, hasLength(2));
      expect(store.values.keys, ['s']);
    },
  );
}

class _Store implements TaskErrorStatusStore {
  final values = <String, TaskErrorStatusCommand>{};
  bool failRead = false, failWrite = false, failRemove = false;
  int writes = 0;
  @override
  Future<List<TaskErrorStatusCommand>> read() async {
    if (failRead) throw const FormatException('damaged');
    return values.values.toList();
  }

  @override
  Future<void> put(TaskErrorStatusCommand command) async {
    writes++;
    if (failWrite) throw StateError('locked');
    values[command.sessionId] = command;
  }

  @override
  Future<void> removeIfCurrent(TaskErrorStatusCommand command) async {
    if (failRemove) throw StateError('locked');
    if (values[command.sessionId]?.commandId == command.commandId) {
      values.remove(command.sessionId);
    }
  }
}

class _Gateway implements TaskErrorStatusGateway {
  final sent = <TaskErrorStatusCommand>[];
  Future<String> Function(TaskErrorStatusCommand) handle = (_) async =>
      'RUNNING';
  @override
  Future<String> send(TaskErrorStatusCommand command) {
    sent.add(command);
    return handle(command);
  }
}
