import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_network_recovery.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_command.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_sync.dart';

void main() {
  late _Events events;
  late PreviewTaskErrorStatusPorts ports;
  late TaskErrorStatusSync sync;
  late TaskErrorNetworkRecovery recovery;
  var current = true, refreshed = 0;
  setUp(() {
    events = _Events();
    ports = PreviewTaskErrorStatusPorts();
    current = true;
    refreshed = 0;
    sync = ports.createSync(isCurrent: () => current);
    recovery = TaskErrorNetworkRecovery(sync, events, isCurrent: () => current);
    recovery.completed.listen((_) => refreshed++);
  });
  tearDown(() async {
    recovery.close();
    sync.close();
    await events.values.close();
  });
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  test(
    'initial available restores persisted pending and syncs without user action',
    () async {
      await ports.put(
        TaskErrorStatusCommand('s', TaskErrorStatusReason.exited, 'cmd'),
      );
      expect(sync.hasPending, isFalse); // not loaded yet
      events.values.add(NetworkAvailability.available);
      await tick();
      expect(ports.sent.single.commandId, 'cmd');
      expect(ports.commands, isEmpty);
      expect(refreshed, 1);
    },
  );
  test(
    'available with no pending makes no request and no task refresh',
    () async {
      events.values.add(NetworkAvailability.available);
      await tick();
      expect(ports.sent, isEmpty);
      expect(refreshed, 0);
    },
  );
  test(
    'offline/unknown/duplicate available do not spin failed requests',
    () async {
      ports.offline = true;
      await sync.record('s', TaskErrorStatusReason.exited);
      ports.sent.clear();
      events.values.add(NetworkAvailability.unavailable);
      events.values.add(NetworkAvailability.unknown);
      await tick();
      expect(ports.sent, isEmpty);
      events.values.add(NetworkAvailability.available);
      await tick();
      events.values.add(NetworkAvailability.available);
      await tick();
      expect(ports.sent, hasLength(1));
      expect(refreshed, 1);
      expect(sync.hasPending, isTrue);
      events.values.add(NetworkAvailability.unavailable);
      ports.offline = false;
      events.values.add(NetworkAvailability.available);
      await tick();
      expect(ports.sent, hasLength(2));
      expect(refreshed, 2);
    },
  );
  test('account replacement and close suppress further events', () async {
    await ports.put(
      TaskErrorStatusCommand('s', TaskErrorStatusReason.exited, 'cmd'),
    );
    current = false;
    events.values.add(NetworkAvailability.available);
    await tick();
    expect(ports.sent, isEmpty);
    recovery.close();
    current = true;
    events.values.add(NetworkAvailability.unavailable);
    events.values.add(NetworkAvailability.available);
    await tick();
    expect(ports.sent, isEmpty);
    expect(refreshed, 0);
  });
  test(
    'reconnection during request coalesces, never overlaps or replays user turns',
    () async {
      recovery.close();
      sync.close();
      final gated = _GatedPorts();
      await gated.put(
        TaskErrorStatusCommand('s', TaskErrorStatusReason.exited, 'cmd'),
      );
      sync = gated.createSync();
      recovery = TaskErrorNetworkRecovery(
        sync,
        events,
        isCurrent: () => current,
      );
      recovery.completed.listen((_) => refreshed++);
      events.values.add(NetworkAvailability.available);
      await gated.entered.future;
      events.values.add(NetworkAvailability.unavailable);
      events.values.add(NetworkAvailability.available);
      events.values.add(NetworkAvailability.available);
      await tick();
      expect(gated.sent, hasLength(1));
      gated.gate.complete('EXECUTION_ERROR');
      await tick();
      expect(gated.sent, hasLength(1));
      expect(refreshed, 1);
    },
  );
}

class _Events implements NetworkAvailabilityEvents {
  final values = StreamController<NetworkAvailability>.broadcast();
  @override
  Stream<NetworkAvailability> watch() => values.stream;
}

class _GatedPorts extends PreviewTaskErrorStatusPorts {
  final entered = Completer<void>(), gate = Completer<String>();
  @override
  Future<String> send(TaskErrorStatusCommand command) {
    sent.add(command);
    entered.complete();
    return gate.future;
  }
}
