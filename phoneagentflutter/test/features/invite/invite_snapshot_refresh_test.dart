import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_controller.dart';
import 'invite_fakes.dart';

const _nextActivity = InviteActivity(
  id: 'p2',
  name: '新活动',
  rules: '新规则',
  inviterPoints: 30,
  inviteePoints: 40,
  quota: 6,
);
InviteCode _code(InviteOverview overview) => InviteCode(
  'EFGH',
  'https://example.test/invite/?code=EFGH',
  '2035-01-01T00:00:00Z',
  0,
  0,
  6,
  overview,
);

class _Repository extends FakeInviteRepository {
  int activityCalls = 0, codeCalls = 0;
  InviteCode current = sampleCode;
  InviteOverview overview = const InviteOverview(sampleActivity, null);
  Completer<InviteCode>? codeGate;
  Completer<void>? eventGate;
  final periods = <String>[];
  @override
  Future<InviteOverview> activity() async {
    activityCalls++;
    if (this.fail) throw const InviteFailure('CONFIG_SYNCING');
    return delayed?.future ?? overview;
  }

  @override
  Future<InviteCode> code() async {
    codeCalls++;
    return codeGate?.future ?? current;
  }

  @override
  Future<void> event(String period, String type, String eventId) async {
    periods.add(period);
    events.add(type);
    await eventGate?.future;
    if (failEvent) throw const InviteFailure('NETWORK');
  }
}

class _Device extends FakeInviteDevice {
  Completer<void>? copyGate;
  @override
  Future<void> copy(String text) async {
    await copyGate?.future;
    copied = text;
  }
}

void main() {
  late _Repository repo;
  late _Device device;
  late InviteController controller;
  setUp(() {
    repo = _Repository();
    device = _Device();
    controller = InviteController(repo, device);
  });
  tearDown(() async {
    if (controller.mounted) controller.dispose();
    await device.received.close();
  });
  test('new code replaces activity and personal as one snapshot', () async {
    const next = InviteOverview(
      _nextActivity,
      InvitePersonal(true, 2, 60, 0, false),
    );
    repo.current = _code(next);
    await controller.refresh();
    expect(controller.state.overview, same(next));
    expect(controller.state.overview!.activity!.inviteePoints, 40);
    expect(controller.state.overview!.personal!.successful, 2);
    await controller.copy(true);
    expect(device.copied, repo.current.url);
    expect(repo.periods, ['p2']);
  });
  test('missing code activity never falls back to earlier overview', () async {
    repo.current = _code(const InviteOverview(null, null));
    await controller.refresh();
    expect(controller.state.overview, isNull);
    expect(controller.state.code, isNull);
    expect(controller.canShare, false);
    expect(controller.state.error, '邀请活动已更新，请刷新获取新邀请码');
    await controller.copy(true);
    expect(device.copied, isNull);
    expect(repo.events, isEmpty);
  });
  test(
    'refresh clears stale overview immediately and failure keeps it revoked',
    () async {
      await controller.refresh();
      repo.delayed = Completer();
      final loading = controller.refresh();
      expect(controller.state.overview, isNull);
      expect(controller.state.code, isNull);
      repo.delayed!.completeError(const InviteFailure('CONFIG_SYNC_PENDING'));
      await loading;
      expect(controller.state.overview, isNull);
      expect(controller.canShare, false);
      expect(controller.state.error, '活动规则正在同步，请稍后重试');
      repo.delayed = null;
      await controller.refresh();
      expect(controller.canShare, true);
    },
  );
  test('no published activity skips code and exposes empty state', () async {
    repo.overview = const InviteOverview(null, null);
    await controller.refresh();
    expect(repo.codeCalls, 0);
    expect(controller.state.error, '活动尚未发布');
    expect(controller.canShare, false);
  });
  test(
    'loading coalesces repeated refresh into one subsequent request',
    () async {
      repo.delayed = Completer();
      final loading = controller.refresh();
      await controller.refresh();
      await controller.refresh();
      final first = repo.delayed!;
      repo.delayed = null;
      repo.current = _code(const InviteOverview(_nextActivity, null));
      first.complete(const InviteOverview(sampleActivity, null));
      await loading;
      expect(repo.activityCalls, 2);
      expect(repo.codeCalls, 2);
      expect(controller.state.overview!.activity!.id, 'p2');
    },
  );
  test('copy defers refresh and hung telemetry does not block it', () async {
    await controller.refresh();
    device.copyGate = Completer();
    repo.eventGate = Completer();
    final copy = controller.copy(true);
    await controller.refresh();
    await controller.refresh();
    expect(repo.activityCalls, 1);
    repo.current = _code(const InviteOverview(_nextActivity, null));
    device.copyGate!.complete();
    await copy;
    expect(device.copied, sampleCode.url);
    expect(repo.periods, ['p1']);
    expect(repo.activityCalls, 2);
    expect(controller.state.overview!.activity!.id, 'p2');
    repo.eventGate!.completeError(const InviteFailure('NETWORK'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.canShare, true);
  });
  for (final result in ['success', 'cancel', 'failure']) {
    test(
      'poster $result releases deferred refresh using clicked snapshot',
      () async {
        await controller.refresh();
        final render = Completer<Uint8List>();
        final save = controller.savePoster(sampleCode, () => render.future);
        await controller.refresh();
        await controller.refresh();
        repo.current = _code(const InviteOverview(_nextActivity, null));
        device.saveResult = result != 'cancel';
        if (result == 'failure') {
          render.completeError(StateError('synthetic rendering failure'));
        } else {
          render.complete(Uint8List(8));
        }
        await save;
        expect(repo.activityCalls, 2);
        expect(repo.periods, result == 'success' ? ['p1'] : isEmpty);
        expect(controller.state.overview!.activity!.id, 'p2');
      },
    );
  }
  test('disposal discards queued refresh and late code response', () async {
    repo.codeGate = Completer();
    final loading = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    await controller.refresh();
    controller.dispose();
    repo.codeGate!.complete(sampleCode);
    await loading;
    expect(repo.activityCalls, 1);
    expect(repo.events, isEmpty);
  });
}
