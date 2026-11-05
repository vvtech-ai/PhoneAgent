import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/app/points_session_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/points/domain/points_activation.dart';
import '../../support/points_cache_fakes.dart';
import '../../support/points_session_fixture.dart';

void main() {
  test(
    'restored production session activates once; token refresh and route remount do not replay',
    () async {
      final f = PointsSessionFixture();
      addTearDown(f.dispose);
      await f.restore();
      final runtime = f.container.read(
        pointsSessionControllerProvider.notifier,
      );
      runtime.setForeground(true);
      await runtime.synchronize();
      expect(f.activations.calls, 1);
      expect(runtime.takeNotices(), hasLength(1));
      runtime.setForeground(false);
      await f.container.pump();
      final session = f.container.read(sessionControllerProvider.notifier);
      await session.replaceToken(session.credentials!, 'synthetic-refreshed');
      expect(
        f.container.read(pointsSessionControllerProvider.notifier),
        same(runtime),
      );
      runtime.setForeground(true);
      await runtime.synchronize();
      expect(f.activations.calls, 1);
      expect(runtime.takeNotices(), isEmpty);
      expect(
        f.container
            .read(pointsWalletControllerProvider)
            .account!
            .availableBalance,
        900,
      );
    },
  );
  test(
    'fresh SMS login uses response without activation and displays actual grant',
    () async {
      final f = PointsSessionFixture();
      addTearDown(f.dispose);
      await f.restore();
      await f.container
          .read(sessionControllerProvider.notifier)
          .accept(
            const LoginOutcome(
              phone: '13800000000',
              accountId: 'b',
              accessToken: 'synthetic-b',
              inviteRequired: false,
              points: AuthPoints(
                availableBalance: 900,
                heldBalance: 0,
                totalBalance: 900,
                updatedAt: 'synthetic',
              ),
              grantEvents: [
                AuthGrantEvent(
                  type: 'INITIAL_GRANT',
                  amount: 800,
                  businessDate: '2026-09-18',
                ),
              ],
            ),
          );
      final runtime = f.container.read(
        pointsSessionControllerProvider.notifier,
      );
      runtime.setForeground(true);
      await runtime.synchronize();
      expect(f.activations.calls, 0);
      expect(runtime.takeNotices(), ['初始赠送 ✦800 积分已到账']);
      await runtime.synchronize();
      expect(runtime.takeNotices(), isEmpty);
    },
  );
  test(
    'login without points still marks activated without fabricating grant',
    () async {
      final f = PointsSessionFixture();
      addTearDown(f.dispose);
      await f.restore();
      await f.container
          .read(sessionControllerProvider.notifier)
          .accept(
            const LoginOutcome(
              phone: '13800000000',
              accountId: 'b',
              accessToken: 'synthetic-b',
              inviteRequired: false,
            ),
          );
      final runtime = f.container.read(
        pointsSessionControllerProvider.notifier,
      );
      runtime.setForeground(true);
      await runtime.synchronize();
      expect(f.activations.calls, 0);
      expect(runtime.takeNotices(), isEmpty);
    },
  );
  test(
    'late activation from previous epoch cannot publish into replacement wallet',
    () async {
      final f = PointsSessionFixture();
      addTearDown(f.dispose);
      await f.restore();
      f.activations.pending = Completer();
      final old = f.container.read(pointsSessionControllerProvider.notifier);
      old.setForeground(true);
      final pending = old.synchronize();
      await f.container
          .read(sessionControllerProvider.notifier)
          .accept(
            const LoginOutcome(
              phone: '13800000000',
              accountId: 'b',
              accessToken: 'synthetic-b',
              inviteRequired: false,
            ),
          );
      f.repository.balance = 200;
      final current = f.container.read(
        pointsSessionControllerProvider.notifier,
      );
      current.setForeground(true);
      await current.synchronize();
      f.activations.pending!.complete(
        PointsActivation(pointsAccount(777), const [
          PointsGrant('INITIAL_GRANT', 777, 'old'),
        ]),
      );
      await pending;
      expect(current.takeNotices(), isEmpty);
      expect(
        f.container
            .read(pointsWalletControllerProvider)
            .account!
            .availableBalance,
        200,
      );
    },
  );
}
