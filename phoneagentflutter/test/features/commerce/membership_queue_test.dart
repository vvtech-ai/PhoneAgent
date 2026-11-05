import 'package:flutter/material.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'membership_contract_v2_test.dart' show fixture;
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/membership_checkout.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';

void main() {
  testWidgets('real membership page separates retained and queued plans', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MembershipPage(
          state: CatalogState(
            membership: CommerceDto.membership(fixture('current')),
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
    expect(find.text('保留权益'), findsNothing);
    expect(find.text('待生效套餐'), findsNothing);
    await tester.tap(find.text('套餐明细'));
    await tester.pumpAndSettle();
    expect(find.text('保留权益'), findsOneWidget);
    expect(find.text('待生效套餐'), findsOneWidget);
    expect(find.textContaining('生效时发放首期 4500'), findsOneWidget);
    expect(find.textContaining('剩余约 21.0 天'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+\. ')), findsNothing);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('保留权益'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final level in ['BASIC', 'PLUS', 'PREMIUM']) {
    test('same SKU $level reaches confirmation after page agreement', () async {
      final repo = FakeCommerceRepository();
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      var confirmed = 0;
      final result = await MembershipCheckout(controller).buy(
        ProductOffer(
          productId: 'm1',
          name: '会员',
          productType: 'MEMBERSHIP',
          level: level,
          months: 1,
          cashAmountFen: 4000,
          basePoints: 4000,
          bonusPoints: 500,
          currency: 'CNY',
          channel: 'ALIPAY',
          available: true,
        ),
        CatalogState(
          catalog: await repo.catalog(),
          channelAvailable: true,
          agreementAccepted: true,
          membership: MembershipCurrent(
            level: level,
            currentMonths: 1,
            entitlementVersionId: 1,
            benefits: const {},
            terms: const [],
          ),
        ),
        isCurrent: () => true,
        confirm: (_) async {
          confirmed++;
          return false;
        },
      );
      expect(result, CheckoutOutcome.canceled);
      expect(confirmed, 1);
      expect(repo.quoteCalls, 1);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      controller.dispose();
    });
  }
}
