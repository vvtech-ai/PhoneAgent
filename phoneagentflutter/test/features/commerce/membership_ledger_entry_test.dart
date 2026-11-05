import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_balance_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('流水独立整行且购买区域不重叠 $platform $width $scale', (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var ledgerOpened = 0;
          var pointsOpened = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(14),
                    child: MembershipBalanceCard(
                      availablePoints: 1500,
                      heldPoints: 0,
                      pointsPerMinute: 100,
                      todayDailyGrantReceived: true,
                      todayDailyGrantPoints: 100,
                      onPoints: () => pointsOpened++,
                      onLedger: () => ledgerOpened++,
                    ),
                  ),
                ),
              ),
            ),
          );
          final ledgerLabel = find.textContaining('积分流水');
          expect(ledgerLabel, findsOneWidget);
          final ledger = find.ancestor(
            of: ledgerLabel,
            matching: find.byType(TextButton),
          );
          final purchase = find.ancestor(
            of: find.text('+ 购买积分'),
            matching: find.byType(TextButton),
          );
          final hint = find.text('约可通话 15 分钟 · 今日赠送 100 积分已到账');
          final divider = find.byType(Divider);
          final rowRect = tester.getRect(ledger);
          final purchaseRect = tester.getRect(purchase);
          expect(rowRect.left, closeTo(28, 0.1));
          expect(rowRect.right, closeTo(width - 28, 0.1));
          expect(rowRect.height, greaterThanOrEqualTo(44));
          expect(
            tester.getRect(hint).bottom,
            lessThanOrEqualTo(tester.getRect(divider).top),
          );
          expect(
            tester.getRect(divider).bottom,
            lessThanOrEqualTo(rowRect.top),
          );
          expect(rowRect.overlaps(purchaseRect), isFalse);
          expect(find.text('查看积分流水'), findsOneWidget);
          expect(purchaseRect.right, closeTo(rowRect.right, 0.1));
          expect(
            purchaseRect.top,
            lessThan(tester.getRect(find.text('1,500')).top),
          );
          expect(tester.getRect(ledgerLabel).left, lessThan(rowRect.center.dx));
          final arrow = find.descendant(
            of: ledger,
            matching: find.byIcon(Icons.chevron_right),
          );
          expect(tester.getCenter(arrow).dx, greaterThan(rowRect.center.dx));
          for (final position in [
            tester.getCenter(ledgerLabel),
            rowRect.center,
            tester.getCenter(arrow),
            Offset(rowRect.left + 1, rowRect.center.dy),
            Offset(rowRect.right - 1, rowRect.center.dy),
          ]) {
            await tester.tapAt(position);
            await tester.pump();
          }
          expect(ledgerOpened, 5);
          expect(pointsOpened, 0);
          await tester.tap(purchase);
          expect(pointsOpened, 1);
          expect(ledgerOpened, 5);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('不可购买积分时流水入口仍独立可用', (tester) async {
    var ledgerOpened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipBalanceCard(
            availablePoints: null,
            heldPoints: null,
            onPoints: null,
            onLedger: () => ledgerOpened++,
          ),
        ),
      ),
    );
    expect(find.text('+ 购买积分'), findsNothing);
    expect(find.text('通话时长估算暂不可用'), findsOneWidget);
    await tester.tap(find.text('查看积分流水'));
    expect(ledgerOpened, 1);
    expect(tester.takeException(), isNull);
  });
}
