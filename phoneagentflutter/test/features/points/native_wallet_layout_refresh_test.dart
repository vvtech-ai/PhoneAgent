import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_page_header.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_page.dart';
import 'package:phone_agent/features/points/presentation/widgets/points_wallet_balance_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'wallet layout retains refresh and ledger $platform scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          var refreshes = 0, ledgers = 0, backs = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: SafeArea(
                  child: PointsWalletPage(
                    state: const PointsWalletState(
                      account: PointsAccount(
                        totalBalance: 900,
                        availableBalance: 900,
                        heldBalance: 0,
                        updatedAt: 'synthetic',
                        todayDailyGrantPoints: 100,
                      ),
                    ),
                    onBack: () => backs++,
                    onLedger: () => ledgers++,
                    onRefresh: () async {
                      refreshes++;
                    },
                  ),
                ),
              ),
            ),
          );
          final card = find
              .descendant(
                of: find.byType(PointsWalletBalanceCard),
                matching: find.byType(DecoratedBox),
              )
              .first;
          final header = find.byType(NativePageHeader);
          expect(
            tester.getTopLeft(card).dy - tester.getBottomLeft(header).dy,
            18,
          );
          expect(tester.getTopLeft(card).dx, 16);
          expect(tester.getTopRight(card).dx, 304);
          expect(find.text('刷新积分'), findsNothing);
          expect(find.text('900'), findsOneWidget);
          await tester.ensureVisible(find.text('积分流水  ›'));
          await tester.tap(find.text('积分流水  ›'));
          expect(ledgers, 1);
          await tester.drag(find.byType(ListView), const Offset(0, 300));
          await tester.pumpAndSettle();
          expect(refreshes, 1);
          await tester.tap(
            find.descendant(of: header, matching: find.byType(IconButton)),
          );
          expect(backs, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
