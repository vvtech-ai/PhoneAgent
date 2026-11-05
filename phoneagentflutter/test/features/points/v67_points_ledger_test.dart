import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart'
    show PointsLedgerItem;
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_page.dart';

void main() {
  testWidgets(
    'v67 ledger keeps original signed rows balance and skips zero changes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointsLedgerPage(
              state: const PointsWalletState(
                ledgerAvailable: true,
                items: [
                  PointsLedgerItem(
                    id: 1,
                    type: 'MEMBERSHIP_GRANT',
                    title: '会员积分赠送',
                    delta: 1500,
                    balanceAfter: 1500,
                    description: '本期会员积分',
                    occurredAt: '2026-10-12T10:00:00',
                  ),
                  PointsLedgerItem(
                    id: 2,
                    type: 'USAGE',
                    title: '通话消耗',
                    delta: -100,
                    balanceAfter: 1400,
                    description: '积分消耗',
                    occurredAt: '2026-10-12T10:05:00',
                  ),
                  PointsLedgerItem(
                    id: 3,
                    type: 'ZERO',
                    title: '不显示零变化',
                    delta: 0,
                    balanceAfter: 1400,
                    description: '零变化',
                    occurredAt: '2026-10-12T10:05:00',
                  ),
                ],
              ),
              onBack: () {},
              onRefresh: () async {},
              onLoadNext: () {},
            ),
          ),
        ),
      );
      expect(find.text('收支明细'), findsOneWidget);
      expect(find.text('展示账户全部积分收入与消耗'), findsOneWidget);
      expect(find.text('本期会员积分 · 操作后余额 1,500'), findsOneWidget);
      expect(find.text('2026-10-12 10:00'), findsOneWidget);
      expect(find.text('不显示零变化'), findsNothing);
      expect(tester.widget<Text>(find.text('+1500')).style?.fontSize, 17);
      expect(
        tester.widget<Text>(find.text('-100')).style?.color,
        const Color(0xFFE34242),
      );
    },
  );
}
