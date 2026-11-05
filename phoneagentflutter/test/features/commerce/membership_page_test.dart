import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';

void main() {
  testWidgets('total points has direct v67 ledger and orders entries', (
    tester,
  ) async {
    var ledger = 0;
    var orders = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MembershipPage(
          state: const CatalogState(),
          availablePoints: 99,
          heldPoints: 1,
          onBack: () {},
          onRefresh: () async {},
          onPoints: () {},
          onOrders: () => orders++,
          onLedger: () => ledger++,
          onBuy: () {},
          onLevel: (_) {},
          onMonths: (_) {},
          onSupport: () {},
          onRestore: () {},
        ),
      ),
    );
    expect(find.text('99'), findsOneWidget);
    expect(find.text('用量与订单'), findsNothing);
    expect(find.text('本期会员积分'), findsNothing);
    expect(find.text('永久积分'), findsNothing);
    await tester.tap(find.text('查看积分流水'));
    expect(ledger, 1);
    await tester.tap(find.text('订单与发票'));
    expect(orders, 1);
  });
  testWidgets(
    'membership monthly grants use level benefits rather than pack point fields',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MembershipPage(
            state: const CatalogState(
              catalog: CommerceCatalog(
                configVersionId: 1,
                revisionNo: 1,
                agreementVersion: 'a1',
                agreementUrl: '',
                supportEmail: '',
                products: [
                  ProductOffer(
                    productId: 'm1',
                    name: '合成会员',
                    productType: 'MEMBERSHIP',
                    level: 'BASIC',
                    months: 1,
                    cashAmountFen: 3000,
                    basePoints: 0,
                    bonusPoints: 0,
                    currency: 'CNY',
                    channel: 'ALIPAY',
                    available: true,
                  ),
                ],
                benefitsByLevel: {
                  'BASIC': {
                    'monthlyBasePoints': 1000,
                    'monthlyBonusPoints': 500,
                  },
                },
              ),
            ),
            availablePoints: 0,
            heldPoints: 0,
            onBack: () {},
            onRefresh: () async {},
            onPoints: () {},
            onOrders: () {},
            onLedger: () {},
            onBuy: () {},
            onLevel: (_) {},
            onMonths: (_) {},
            onSupport: () {},
            onRestore: () {},
          ),
        ),
      );
      expect(find.text('每月到账 1,500 积分'), findsOneWidget);
      expect(find.text('其中含赠送 500 积分'), findsOneWidget);
    },
  );
  for (final width in [375.0, 390.0, 430.0]) {
    testWidgets('membership scroll and true free identity at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MembershipPage(
            state: const CatalogState(
              catalog: CommerceCatalog(
                configVersionId: 1,
                revisionNo: 1,
                agreementVersion: 'v1',
                agreementUrl: 'https://example.test/terms',
                supportEmail: '',
                products: [],
              ),
              membership: MembershipCurrent(
                level: 'FREE',
                entitlementVersionId: 1,
                benefits: {},
                terms: [],
              ),
            ),
            availablePoints: 150,
            heldPoints: 20,
            onBack: () {},
            onRefresh: () async {},
            onPoints: () {},
            onOrders: () {},
            onLedger: () {},
            onBuy: () {},
            onLevel: (_) {},
            onMonths: (_) {},
            onSupport: () {},
            onRestore: () {},
          ),
        ),
      );
      expect(find.text('当前权益'), findsNothing);
      expect(find.text('+ 购买积分'), findsNothing);
      expect(find.text('初级会员'), findsOneWidget);
      expect(find.text('暂无可售商品'), findsNothing);
      expect(find.text('购买会员'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
