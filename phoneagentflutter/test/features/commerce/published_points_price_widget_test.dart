import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/points_offer_card.dart';
import 'fake_commerce_repository.dart';
import 'points_offer_discount_test.dart' as fixture;

class _Catalog extends FakeCommerceRepository {
  @override
  Future<CommerceCatalog> catalog() async => CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'v1',
    agreementUrl: 'https://example.com',
    supportEmail: '',
    products: [fixture.offer()],
  );
}

class _Launcher extends FakePaymentLauncher {
  Set<String>? requested;
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async {
    requested = ids;
    return {
      'member-sku': fixture.apple('4.5'),
      'regular-sku': fixture.apple('5'),
    };
  }
}

void main() {
  for (final apple in [false, true]) {
    testWidgets(
      'minimum one fen retains configured benefit and actual SKU price apple=$apple',
      (tester) async {
        final offer = fixture.offer(
          paid: 1,
          original: 1,
          bps: 7500,
          level: 'PREMIUM',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PointsOfferCard(
                state: CatalogState(
                  requiresPlatformProducts: apple,
                  platformStatus: PlatformProductsStatus.ready,
                  platformProducts: {
                    'member-sku': fixture.apple('1.99'),
                    'regular-sku': fixture.apple('1.99'),
                  },
                ),
                offer: offer,
                selected: true,
                onSelect: () {},
              ),
            ),
          ),
        );
        expect(find.text(apple ? '\$1.99' : '¥0.01'), findsOneWidget);
        expect(find.text('7.5折'), findsOneWidget);
        expect(find.text('高级会员专享价'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text && w.style?.decoration == TextDecoration.lineThrough,
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'points page keeps backend minimum one fen and never invents savings',
    (tester) async {
      const offer = ProductOffer(
        productId: 'minimum-pack',
        name: '积分包',
        productType: 'POINTS_PACK',
        level: null,
        months: null,
        cashAmountFen: 1,
        originalCashAmountFen: 1,
        basePoints: 100,
        bonusPoints: 0,
        currency: 'CNY',
        channel: 'ALIPAY',
        available: true,
      );
      ProductOffer? bought;
      await tester.pumpWidget(
        MaterialApp(
          home: PointsPurchasePage(
            state: CatalogState(
              channelAvailable: true,
              catalog: CommerceCatalog(
                configVersionId: 1,
                revisionNo: 17,
                agreementVersion: 'v1',
                agreementUrl: 'https://example.com',
                supportEmail: '',
                products: [offer],
                benefitsByLevel: const {
                  'PLUS': {'packDiscountBps': 9000},
                },
              ),
            ),
            onBack: () {},
            onBuy: (value) => bought = value,
            onAgreement: (_) {},
            onLegal: () {},
          ),
        ),
      );
      expect(find.text('¥0.01'), findsOneWidget);
      expect(find.text('¥0'), findsNothing);
      expect(find.text('9折'), findsNothing);
      expect(find.text('中级会员专享价'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.style?.decoration == TextDecoration.lineThrough,
        ),
        findsNothing,
      );
      await tester.tap(find.text('支付宝购买'));
      expect(bought?.productId, offer.productId);
      expect(bought?.cashAmountFen, 1);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'catalog loads both Apple SKU prices without changing selected purchase SKU',
    () async {
      final launcher = _Launcher();
      final controller = CatalogController(
        _Catalog(),
        launcher,
        requiresPlatformProducts: true,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(launcher.requested, {'member-sku', 'regular-sku'});
      expect(controller.state.platformProducts['regular-sku']?.price, '5');
      expect(
        controller.state.catalog!.products.single.platformProductId,
        'member-sku',
      );
    },
  );
  for (final apple in [false, true]) {
    testWidgets(
      'offer card shows actual price and truthful discount apple=$apple',
      (tester) async {
        final offer = fixture.offer();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PointsOfferCard(
                state: CatalogState(
                  requiresPlatformProducts: apple,
                  platformStatus: PlatformProductsStatus.ready,
                  platformProducts: {
                    'member-sku': fixture.apple('4.5'),
                    'regular-sku': fixture.apple('5'),
                  },
                ),
                offer: offer,
                selected: true,
                onSelect: () {},
              ),
            ),
          ),
        );
        expect(find.text(apple ? '\$4.5' : '¥9'), findsOneWidget);
        expect(find.text(apple ? '\$5' : '¥10.00'), findsOneWidget);
        expect(find.text('9折'), findsOneWidget);
        expect(find.text('中级会员专享价'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
