import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_offer.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_period_card.dart';
import 'platform_purchase_fixture.dart';

CatalogState saleSelection({bool allHidden = false}) {
  final raw = platformCatalog();
  final member = (raw['products'] as List).first as Map<String, Object?>;
  raw['products'] = [
    {...member, 'productId': 'month', 'months': 1, 'available': false},
    {...member, 'productId': 'quarter', 'months': 3, 'available': !allHidden},
    {...member, 'productId': 'year', 'months': 12, 'available': !allHidden},
  ];
  return CatalogState(
    catalog: CommerceDto.catalog(raw),
    selectedMonths: 1,
    channelAvailable: true,
  );
}

void main() {
  test('hidden selected monthly offer falls back to an available quarter', () {
    final state = saleSelection();
    expect(state.offers.map((offer) => offer.productId), ['quarter', 'year']);
    expect(state.selectedMonths, 3);
    expect(state.selectedProduct?.productId, 'quarter');
    expect(state.copy(selectedMonths: 12).selectedProduct?.productId, 'year');
  });

  testWidgets('hidden membership periods have no price or selectable card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipOffer(
            state: saleSelection(),
            onMonths: (_) {},
            onBuy: () {},
            onSupport: () {},
          ),
        ),
      ),
    );
    expect(find.text('月卡'), findsNothing);
    expect(find.text('季卡'), findsOneWidget);
    expect(find.byType(MembershipPeriodCard), findsNWidgets(2));
    final card = find
        .ancestor(of: find.text('季卡'), matching: find.byType(Container))
        .first;
    final border =
        (tester.widget<Container>(card).decoration as BoxDecoration).border!
            as Border;
    expect(border.top.width, 2);
  });

  testWidgets(
    'all hidden offers retain benefits without empty sale card or agreement',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MembershipOffer(
              state: saleSelection(allHidden: true),
              onMonths: (_) {},
              onBuy: () {},
              onSupport: () {},
              onAgreement: (_) {},
              onLegal: () {},
            ),
          ),
        ),
      );
      expect(find.text('每月到账 9,999 积分', findRichText: true), findsOneWidget);
      expect(find.text('暂无可售商品'), findsNothing);
      expect(find.text('购买会员'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(MembershipPeriodCard), findsNothing);
    },
  );
}
