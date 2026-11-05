import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/domain/invite_link_policy.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_entry_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'invite_fakes.dart';

void main() {
  test(
    'refresh skips records, cancelled save, successful copy with failed telemetry',
    () async {
      final repo = FakeInviteRepository();
      final device = FakeInviteDevice();
      final c = InviteController(repo, device);
      await c.refresh();
      expect(repo.recordCalls, 0);
      expect(c.canShare, isTrue);
      device.saveResult = false;
      await c.savePoster(sampleCode, () async => Uint8List(8));
      expect(repo.events, isEmpty);
      expect(c.state.notice, '已取消保存');
      repo.failEvent = true;
      await c.copy(true);
      expect(device.copied, sampleCode.url);
      expect(c.state.notice, '已复制');
      expect(repo.events, ['COPY_LINK']);
      c.dispose();
      await device.received.close();
    },
  );
  test('copy and poster saving expose distinct busy operations', () async {
    final device = _DelayedDevice();
    final c = InviteController(FakeInviteRepository(), device);
    await c.refresh();
    final copy = c.copy(true);
    expect(c.state.actionType, 'COPY_LINK');
    expect(c.canShare, isFalse);
    device.gate.complete();
    await copy;
    expect(c.state.actionType, isEmpty);
    final render = Completer<Uint8List>();
    final save = c.savePoster(sampleCode, () => render.future);
    expect(c.state.actionType, 'SAVE_POSTER');
    render.complete(Uint8List(8));
    await save;
    expect(c.state.actionType, isEmpty);
    c.dispose();
    await device.received.close();
  });
  test('offline refresh revokes stale share and retry recovers', () async {
    final repo = FakeInviteRepository();
    final device = FakeInviteDevice();
    final c = InviteController(repo, device);
    await c.refresh();
    expect(c.canShare, isTrue);
    repo.fail = true;
    await c.refresh();
    expect(c.state.error, contains('同步'));
    expect(c.canShare, isFalse);
    await c.copy(true);
    expect(device.copied, isNull);
    repo.fail = false;
    await c.refresh();
    expect(c.canShare, isTrue);
    c.dispose();
    await device.received.close();
  });
  test(
    'returned code can open poster regardless of local expiry or quota',
    () async {
      final repo = _ExhaustedRepository();
      final device = FakeInviteDevice();
      final c = InviteController(repo, device);
      await c.refresh();
      expect(c.canShare, isTrue);
      expect(repo.events, isEmpty);
      c.dispose();
      await device.received.close();
    },
  );
  test('account-scoped disposed controller ignores late responses', () async {
    final repo = FakeInviteRepository()..delayed = Completer<InviteOverview>();
    final device = FakeInviteDevice();
    final c = InviteController(repo, device);
    final load = c.refresh();
    c.dispose();
    repo.delayed!.complete(const InviteOverview(sampleActivity, null));
    await load;
    expect(repo.events, isEmpty);
    await device.received.close();
  });
  test(
    'cold link waits for session restore; signed in never binds referral',
    () async {
      final device = FakeInviteDevice()..initial = sampleCode.url;
      final p = PendingInviteController(MemoryInviteStore());
      await p.initialize();
      final entry = InviteEntryController(
        device,
        const InviteLinkPolicy(
          host: 'example.test',
          path: '/invite/',
          scheme: 'phoneagent-test',
        ),
        p,
      );
      await entry.start();
      expect(p.state.code, isEmpty);
      entry.session(ready: true, signedIn: true);
      await Future<void>.delayed(Duration.zero);
      expect(p.state.code, isEmpty);
      expect(entry.state, contains('仅限新用户'));
      entry.session(ready: true, signedIn: false);
      device.received.add('phoneagent-test://invite/?code=EFGH');
      await Future<void>.delayed(Duration.zero);
      expect(p.state.code, 'EFGH');
      expect(p.state.welcome, isTrue);
      entry.dispose();
      p.dispose();
      await device.received.close();
    },
  );
}

class _DelayedDevice extends FakeInviteDevice {
  final gate = Completer<void>();
  @override
  Future<void> copy(String text) async {
    await gate.future;
  }
}

class _ExhaustedRepository extends FakeInviteRepository {
  @override
  Future<InviteCode> code() async => const InviteCode(
    'ABCD',
    'https://example.test/invite/?code=ABCD',
    '2020-01-01',
    5,
    0,
    0,
    InviteOverview(sampleActivity, null),
  );
}
