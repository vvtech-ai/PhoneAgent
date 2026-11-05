import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('wallet state transitions $platform $scale', (tester) async {
        tester.view.physicalSize = const Size(320, 680);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var retries = 0;
        Future<void> show(PointsWalletState state) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: PointsWalletPage(
                state: state,
                onBack: () {},
                onLedger: () {},
                onRefresh: () async {
                  retries++;
                },
                invitationContent: const Text('邀请区域'),
              ),
            ),
          ),
        );
        await show(const PointsWalletState(loading: true));
        expect(find.byType(LinearProgressIndicator), findsNothing);
        final spinner = find.byType(CircularProgressIndicator);
        expect(spinner, findsOneWidget);
        final region = find
            .ancestor(of: spinner, matching: find.byType(SizedBox))
            .first;
        expect(
          tester.getSize(region).height,
          platform == TargetPlatform.iOS ? 100 : 120,
        );
        expect(tester.getCenter(spinner).dx, 160);
        expect(find.text('邀请区域'), findsOneWidget);
        await show(const PointsWalletState(error: '网络失败'));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('网络失败'), findsOneWidget);
        expect(tester.getCenter(find.text('网络失败')).dx, 160);
        await tester.tap(find.text('重试'));
        expect(retries, 1);
        expect(find.text('邀请区域'), findsOneWidget);
        const account = PointsAccount(
          totalBalance: 120,
          availableBalance: 120,
          heldBalance: 0,
          updatedAt: 'synthetic',
        );
        await show(const PointsWalletState(account: account, loading: true));
        expect(find.text('当前可用积分'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await show(
          const PointsWalletState(account: account, stale: true, error: '网络失败'),
        );
        expect(find.text('网络失败'), findsNothing);
        expect(find.text('当前显示上次同步数据，非最新余额'), findsOneWidget);
        expect(find.text('邀请区域'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
