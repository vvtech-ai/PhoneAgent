import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/domain/points_activation.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_session_controller.dart';

const snapshot = PointsAccount(
  totalBalance: 900,
  availableBalance: 800,
  heldBalance: 100,
  updatedAt: 'synthetic',
);
const grant = PointsGrant('DAILY_LOGIN_GRANT', 100, '2026-09-18');

class Fixture {
  int activations = 0, refreshes = 0;
  bool current = true, failActivation = false, failRefresh = false;
  Completer<PointsActivation?>? gate;
  final accepted = <PointsAccount>[];
  late final PointsSessionController controller;
  Fixture({bool login = false}) {
    controller = PointsSessionController(
      activate: () async {
        activations++;
        if (failActivation) throw StateError('offline');
        return gate == null ? null : await gate!.future;
      },
      refresh: () async {
        refreshes++;
        if (failRefresh) throw StateError('offline');
      },
      acceptAccount: accepted.add,
      isCurrent: () => current,
      loginAccount: login ? snapshot : null,
      loginGrants: login ? [grant] : [],
    );
  }
}

void main() {
  test(
    'login seed and server grant consumed once across repeated foreground',
    () async {
      final f = Fixture(login: true);
      addTearDown(f.controller.dispose);
      f.controller.setForeground(true);
      await f.controller.synchronize();
      expect(f.accepted, [snapshot]);
      expect(f.controller.takeNotices(), ['今日登录赠送 ✦100 积分已到账']);
      expect(f.controller.takeNotices(), isEmpty);
      f.controller.setForeground(false);
      f.controller.setForeground(true);
      await f.controller.synchronize();
      expect(f.accepted, hasLength(1));
      expect(f.controller.state, isEmpty);
    },
  );
  test(
    'activation completion publishes complete account then refreshes',
    () async {
      final f = Fixture()..gate = Completer();
      addTearDown(f.controller.dispose);
      f.controller.setForeground(true);
      final work = f.controller.synchronize();
      expect(f.activations, 1);
      expect(f.refreshes, 0);
      f.gate!.complete(const PointsActivation(snapshot, [grant]));
      await work;
      expect(f.accepted, [snapshot]);
      expect(f.refreshes, 1);
      expect(f.controller.takeNotices(), hasLength(1));
    },
  );
  test(
    'failed activation still refreshes, without immediate recursive retry',
    () async {
      final f = Fixture()..failActivation = true;
      addTearDown(f.controller.dispose);
      f.controller.setForeground(true);
      await f.controller.synchronize();
      expect(f.activations, 1);
      expect(f.refreshes, 1);
      expect(f.accepted, isEmpty);
      expect(f.controller.state, isEmpty);
    },
  );
  test(
    'failure in wallet refresh does not replay successful server grant',
    () async {
      final f = Fixture(login: true)..failRefresh = true;
      addTearDown(f.controller.dispose);
      f.controller.setForeground(true);
      await f.controller.synchronize();
      f.controller.takeNotices();
      await f.controller.synchronize();
      expect(f.accepted, hasLength(1));
      expect(f.controller.state, isEmpty);
    },
  );
  for (final dispose in [false, true]) {
    test(
      'late activation ignored after ${dispose ? 'dispose' : 'account change'}',
      () async {
        final f = Fixture()..gate = Completer();
        f.controller.setForeground(true);
        final work = f.controller.synchronize();
        if (dispose) {
          f.controller.dispose();
        } else {
          f.current = false;
        }
        f.gate!.complete(const PointsActivation(snapshot, [grant]));
        await work;
        expect(f.accepted, isEmpty);
        expect(f.refreshes, 0);
        if (!dispose) f.controller.dispose();
      },
    );
  }
  testWidgets(
    'foreground 30 second cadence stops in background and resumes once',
    (tester) async {
      final f = Fixture();
      f.controller.setForeground(true);
      await tester.pump();
      expect(f.refreshes, 1);
      await tester.pump(const Duration(seconds: 29));
      expect(f.refreshes, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(f.refreshes, 2);
      f.controller.setForeground(false);
      await tester.pump(const Duration(minutes: 3));
      expect(f.refreshes, 2);
      await f.controller.synchronize();
      expect(f.refreshes, 2);
      f.controller.setForeground(true);
      f.controller.setForeground(true);
      await tester.pump();
      expect(f.refreshes, 3);
      f.controller.dispose();
    },
  );
}
