import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_balance_card.dart';

void main() {
  Future<void> showCard(
    WidgetTester tester, {
    int? balance = 1000,
    int? rate = 100,
    bool received = true,
    int granted = 100,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MembershipBalanceCard(
          availablePoints: balance,
          heldPoints: 50,
          pointsPerMinute: rate,
          todayDailyGrantReceived: received,
          todayDailyGrantPoints: granted,
          onPoints: () {},
          onLedger: () {},
        ),
      ),
    ),
  );

  testWidgets('余额说明恢复 Demo 文案并使用真实费率与赠送', (tester) async {
    await showCard(tester);
    expect(find.text('约可通话 10 分钟 · 今日赠送 100 积分已到账'), findsOneWidget);
    expect(find.textContaining('预占'), findsNothing);
    expect(find.text('查看积分流水'), findsOneWidget);
    await showCard(tester, balance: 3150, rate: 150, granted: 200);
    expect(find.text('约可通话 21 分钟 · 今日赠送 200 积分已到账'), findsOneWidget);
  });

  testWidgets('未知费率与未到账不虚构分钟或奖励', (tester) async {
    await showCard(tester, rate: null, received: false);
    expect(find.textContaining('已到账'), findsNothing);
    expect(find.textContaining('约可通话'), findsNothing);
    await showCard(tester, received: false);
    expect(find.text('约可通话 10 分钟'), findsOneWidget);
    await showCard(tester, granted: 0);
    expect(find.textContaining('今日赠送'), findsNothing);
    await showCard(tester, balance: null);
    expect(find.textContaining('已到账'), findsNothing);
  });
}
