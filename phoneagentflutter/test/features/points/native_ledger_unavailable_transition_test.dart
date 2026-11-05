import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_page_header.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart'
    show PointsLedgerItem;
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_page.dart';
import 'package:phone_agent/features/points/presentation/widgets/points_ledger_status.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('ledger unavailable to known states $platform $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var state = const PointsWalletState(loading: true);
        late StateSetter update;
        var retries = 0, backs = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return PointsLedgerPage(
                      state: state,
                      onBack: () => backs++,
                      onRefresh: () async {
                        retries++;
                        update(() => state = state.copy(loading: true));
                      },
                      onLoadNext: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final spinner = find.byType(CircularProgressIndicator);
        expect(tester.getSize(spinner), const Size(40, 40));
        expect(find.text('收支明细'), findsNothing);
        expect(find.text('暂无积分流水'), findsNothing);
        expect(find.text('重试'), findsNothing);
        final bodyTop = tester
            .getBottomLeft(find.byType(NativePageHeader))
            .dy;
        expect(tester.getCenter(spinner).dy, closeTo((bodyTop + 568) / 2, 1));
        update(() => state = const PointsWalletState(error: '合成网络错误'));
        await tester.pumpAndSettle();
        expect(find.text(ledgerRefreshErrorMessage), findsOneWidget);
        expect(find.text('合成网络错误'), findsNothing);
        await tester.ensureVisible(find.text('重试'));
        await tester.tap(find.text('重试'));
        await tester.pump();
        expect(retries, 1);
        expect(spinner, findsOneWidget);
        expect(find.text('重试'), findsNothing);
        update(() => state = const PointsWalletState(ledgerAvailable: true));
        await tester.pumpAndSettle();
        expect(find.text('收支明细'), findsOneWidget);
        expect(find.text('暂无积分流水'), findsOneWidget);
        update(
          () => state = const PointsWalletState(
            ledgerAvailable: true,
            ledgerStale: true,
            error: '合成网络错误',
            hasNext: true,
            items: [
              PointsLedgerItem(
                id: 1,
                type: 'SYNTHETIC',
                title: '合成记录',
                delta: 100,
                balanceAfter: 900,
                description: '合成数据',
                occurredAt: '2026-10-07T09:00:00',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('合成记录'), 150);
        expect(find.text('+100'), findsOneWidget);
        expect(find.text('暂无积分流水'), findsNothing);
        await tester.scrollUntilVisible(find.text('重试'), -150);
        await tester.tap(find.text('重试'));
        await tester.pump();
        expect(retries, 2);
        await tester.scrollUntilVisible(find.text('加载更多'), 150);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '加载更多'))
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('返回'));
        expect(backs, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
