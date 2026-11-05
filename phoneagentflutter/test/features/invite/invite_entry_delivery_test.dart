import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite_link_policy.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_entry_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'invite_fakes.dart';

const _policy = InviteLinkPolicy(
  host: 'example.test',
  path: '/invite/',
  scheme: 'phoneagent-dev',
);

class _DelayedInitialDevice extends FakeInviteDevice {
  final initialRequest = Completer<String?>();
  @override
  Future<String?> initialLink() => initialRequest.future;
}

void main() {
  test(
    'new native Android clicks with identical URL are not time-debounced',
    () async {
      final device = FakeInviteDevice();
      final pending = PendingInviteController(MemoryInviteStore());
      final entry = InviteEntryController(
        device,
        _policy,
        pending,
        deduplicateUrls: false,
      );
      await entry.start();
      entry.session(ready: true, signedIn: false);
      device.received.add('phoneagent-dev://invite/?code=ABCD');
      await Future<void>.delayed(Duration.zero);
      final first = pending.state.entryId;
      pending.continueLogin();
      device.received.add('phoneagent-dev://invite/?code=ABCD');
      await Future<void>.delayed(Duration.zero);
      expect(pending.state.welcome, true);
      expect(pending.state.entryId, greaterThan(first));
      entry.dispose();
      pending.dispose();
      await device.received.close();
    },
  );
  test(
    'latest hot link wins over delayed cold link during session restore',
    () async {
      final device = _DelayedInitialDevice();
      final pending = PendingInviteController(MemoryInviteStore());
      final entry = InviteEntryController(device, _policy, pending);
      final starting = entry.start();
      device.received.add('phoneagent-dev://invite/?code=EFGH');
      await Future<void>.delayed(Duration.zero);
      device.initialRequest.complete('phoneagent-dev://invite/?code=ABCD');
      await starting;
      expect(pending.state.code, isEmpty);
      entry.session(ready: true, signedIn: false);
      await Future<void>.delayed(Duration.zero);
      expect(pending.state.code, 'EFGH');
      expect(pending.state.welcome, true);
      entry.dispose();
      pending.dispose();
      await device.received.close();
    },
  );
  test(
    'iOS repeated callback preserves continuation for same immediate URL',
    () async {
      final device = FakeInviteDevice();
      final pending = PendingInviteController(MemoryInviteStore());
      final entry = InviteEntryController(device, _policy, pending);
      entry.session(ready: true, signedIn: false);
      entry.receive('phoneagent-dev://invite/?code=ABCD');
      await Future<void>.delayed(Duration.zero);
      pending.continueLogin();
      entry.receive('phoneagent-dev://invite/?code=ABCD');
      await Future<void>.delayed(Duration.zero);
      expect(pending.state.welcome, false);
      entry.dispose();
      pending.dispose();
      await device.received.close();
    },
  );
}
