import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/points_offer_card.dart';
import 'platform_purchase_fixture.dart';

CatalogState mixedPacks({bool hideAll = false, bool firstAvailable = false}) {
  final raw = platformCatalog();
  final pack = (raw['products'] as List)[1] as Map<String, Object?>;
  raw['products'] = [
    {
      ...pack,
      'productId': 'one-a',
      'basePoints': 1,
      'cashAmountFen': 0,
      'available': firstAvailable,
    },
    {
      ...pack,
      'productId': 'normal',
      'basePoints': 3000,
      'cashAmountFen': 2700,
      'bonusPoints': 0,
      'available': !hideAll,
    },
    {
      ...pack,
      'productId': 'one-b',
      'basePoints': 2,
      'cashAmountFen': 0,
      'available': false,
    },
  ];
  return CatalogState(
    catalog: CommerceDto.catalog(raw),
    channelAvailable: true,
  );
}

Widget packPage(CatalogState state, ValueChanged<String> buy) => MaterialApp(
  home: PointsPurchasePage(
    state: state,
    onBack: () {},
    onBuy: (product) => buy(product.productId),
    onAgreement: (_) {},
    onLegal: () {},
  ),
);

void main() {
  testWidgets(
    'two unavailable packs are hidden and normal 27 yuan pack is selected',
    (tester) async {
      String? bought;
      await tester.pumpWidget(packPage(mixedPacks(), (id) => bought = id));
      expect(find.byType(PointsOfferCard), findsOneWidget);
      expect(find.text('3,000 积分'), findsOneWidget);
      expect(find.text('¥27'), findsOneWidget);
      await tester.tap(find.text('支付宝购买'));
      expect(bought, 'normal');
    },
  );

  testWidgets('selected pack removed by refresh falls back to displayed sale', (
    tester,
  ) async {
    String? bought;
    await tester.pumpWidget(
      packPage(mixedPacks(firstAvailable: true), (id) => bought = id),
    );
    await tester.tap(find.text('51 积分'));
    await tester.pumpWidget(packPage(mixedPacks(), (id) => bought = id));
    await tester.tap(find.text('支付宝购买'));
    expect(bought, 'normal');
  });

  testWidgets(
    'normal empty sale hides price agreement and action without error card',
    (tester) async {
      await tester.pumpWidget(packPage(mixedPacks(hideAll: true), (_) {}));
      expect(find.byType(PointsOfferCard), findsNothing);
      expect(find.text('暂无可售积分包'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    },
  );
}
