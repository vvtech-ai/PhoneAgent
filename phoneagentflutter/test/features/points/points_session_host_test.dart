import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/points_session_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/points/domain/points_activation.dart';
import 'package:phone_agent/features/points/presentation/widgets/points_session_host.dart';
import '../../support/points_session_fixture.dart';
import '../../support/points_cache_fakes.dart';

void main() {
  for (final source in ['login', 'restore']) {
    testWidgets('$source host shows both server grants once in order', (
      tester,
    ) async {
      final f = PointsSessionFixture();
      addTearDown(f.dispose);
      if (source == 'login') {
        await f.container
            .read(sessionControllerProvider.notifier)
            .accept(
              const LoginOutcome(
                phone: '13800000000',
                accountId: 'a',
                accessToken: 'synthetic-a',
                inviteRequired: false,
                points: AuthPoints(
                  availableBalance: 800,
                  heldBalance: 0,
                  totalBalance: 800,
                  updatedAt: '2026-10-16',
                ),
                grantEvents: [
                  AuthGrantEvent(
                    type: 'INITIAL_GRANT',
                    amount: 735,
                    businessDate: '2026-10-16',
                  ),
                  AuthGrantEvent(
                    type: 'DAILY_LOGIN_GRANT',
                    amount: 65,
                    businessDate: '2026-10-16',
                  ),
                ],
              ),
            );
      } else {
        f.activations.pending = Completer<PointsActivation>()
          ..complete(
            PointsActivation(pointsAccount(800), const [
              PointsGrant('INITIAL_GRANT', 735, '2026-10-16'),
              PointsGrant('DAILY_LOGIN_GRANT', 65, '2026-10-16'),
            ]),
          );
        await tester.runAsync(f.restore);
      }
      final app = UncontrolledProviderScope(
        container: f.container,
        child: const MaterialApp(
          home: PointsSessionHost(child: Scaffold(body: Text('首页'))),
        ),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('初始赠送 ✦735 积分已到账'), findsOneWidget);
      expect(find.text('今日登录赠送 ✦65 积分已到账'), findsNothing);
      expect(f.container.read(pointsSessionControllerProvider), isEmpty);
      await tester.pump(const Duration(milliseconds: 3900));
      expect(find.text('初始赠送 ✦735 积分已到账'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('初始赠送 ✦735 积分已到账'), findsNothing);
      expect(find.text('今日登录赠送 ✦65 积分已到账'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      expect(f.activations.calls, source == 'login' ? 0 : 1);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'production host displays actual notice once and forwards app lifecycle',
    (tester) async {
      final f = PointsSessionFixture();
      await tester.runAsync(f.restore);
      final widget = UncontrolledProviderScope(
        container: f.container,
        child: const MaterialApp(
          home: PointsSessionHost(child: Scaffold(body: Text('首页'))),
        ),
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(find.text('今日登录赠送 ✦100 积分已到账'), findsOneWidget);
      expect(f.activations.calls, 1);
      expect(f.container.read(pointsSessionControllerProvider), isEmpty);
      final before = f.repository.accounts;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 2));
      expect(f.repository.accounts, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(f.repository.accounts, greaterThan(before));
      expect(f.activations.calls, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(find.text('今日登录赠送 ✦100 积分已到账'), findsNothing);
      expect(f.activations.calls, 1);
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    },
  );
}
