import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_page.dart';
import '../../support/points_cache_fakes.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets(
      'offline restored wallet and ledger remain readable and explicitly stale at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cache = PointsCacheFake()..value = pointsSnapshot();
        final controller = PointsWalletController(
          PointsRepositoryFake()..failAccount = true,
          cache: cache,
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        await tester.pumpWidget(
          MaterialApp(
            home: PointsWalletPage(
              state: controller.state,
              onBack: () {},
              onLedger: () {},
              onRefresh: controller.refresh,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('120'), findsOneWidget);
        expect(find.text('当前显示上次同步数据，非最新余额'), findsOneWidget);
        expect(find.text('积分加载失败，请重试'), findsNothing);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(controller.state.admissionBalance, isNull);
        await tester.pumpWidget(
          MaterialApp(
            home: PointsLedgerPage(
              state: controller.state,
              onBack: () {},
              onRefresh: controller.refresh,
              onLoadNext: controller.loadNext,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('合成流水'), findsNWidgets(2));
        expect(find.text('积分流水尚未同步，请刷新后查看最新明细'), findsOneWidget);
        expect(find.text('暂无积分流水'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
