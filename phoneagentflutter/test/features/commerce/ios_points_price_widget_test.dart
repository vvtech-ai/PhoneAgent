import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'ios_purchase_fixture.dart' show pack;

void main() {
  testWidgets(
    'price spinner, blue whole-list retry, unavailable and localized price independent of agreement',
    (t) async {
      var retries = 0, purchases = 0;
      Future<void> show(
        PlatformProductsStatus status, {
        Map<String, PlatformProduct> products = const {},
        bool agreed = true,
        bool blocked = false,
      }) => t.pumpWidget(
        MaterialApp(
          home: PointsPurchasePage(
            purchaseBlocked: blocked,
            state: CatalogState(
              requiresPlatformProducts: true,
              channelAvailable: true,
              platformStatus: status,
              agreementAccepted: agreed,
              platformProducts: products,
              catalog: const CommerceCatalog(
                configVersionId: 1,
                revisionNo: 1,
                agreementVersion: 'v1',
                agreementUrl: 'https://example.com',
                supportEmail: '',
                products: [pack],
              ),
            ),
            onBack: () {},
            onLegal: () {},
            onAgreement: (_) {},
            onBuy: (_) => purchases++,
            onReloadProducts: () => retries++,
          ),
        ),
      );
      await show(PlatformProductsStatus.loading);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.tap(find.text('确认支付'));
      expect(purchases, 0);
      await show(PlatformProductsStatus.failed);
      final retry = t.widget<TextButton>(
        find.widgetWithText(TextButton, '重新加载'),
      );
      expect(
        retry.style!.foregroundColor!.resolve({}),
        const Color(0xFF1677FF),
      );
      await t.tap(find.text('重新加载'));
      expect(retries, 1);
      await show(PlatformProductsStatus.ready);
      expect(find.text('暂不可售'), findsOneWidget);
      const products = {
        'pack-sku': PlatformProduct(
          'pack-sku',
          'CN¥6.00',
          price: '6',
          currencyCode: 'CNY',
          productType: 'consumable',
        ),
      };
      await show(
        PlatformProductsStatus.ready,
        products: products,
        agreed: false,
      );
      expect(find.text('CN¥6.00'), findsOneWidget);
      await t.tap(find.text('确认支付'));
      expect(
        purchases,
        1,
      ); // Agreement is checked by checkout, not button eligibility.
      await show(PlatformProductsStatus.ready, products: products);
      await t.tap(find.text('确认支付'));
      expect(purchases, 2);
      await show(
        PlatformProductsStatus.ready,
        products: products,
        agreed: false,
        blocked: true,
      );
      await t.tap(find.text('确认支付'));
      expect(purchases, 2);
    },
  );
}
