import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_widgets.dart';
import 'platform_purchase_fixture.dart';

void main() {
  for (final error in ['', '当前会员加载失败，请重试']) {
    testWidgets('disabled points keeps actual read retry when error=$error', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PointsPurchasePage(
            state: CatalogState(
              catalog: platformState(points: false).catalog,
              channelAvailable: true,
              error: error,
            ),
            onBack: () {},
            onBuy: (_) => fail('销售关闭不应购买'),
            onAgreement: (_) {},
            onLegal: () {},
            onRefresh: () async {
              retries++;
            },
          ),
        ),
      );
      expect(find.text('积分购买暂未开放'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('¥'), findsNothing);
      if (error.isEmpty) {
        expect(find.text('重试'), findsNothing);
      } else {
        expect(find.text(error), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(error)).dy,
          greaterThan(tester.getTopLeft(find.text('积分购买暂未开放')).dy),
        );
        await tester.tap(find.text('重试'));
        expect(retries, 1);
      }
    });
  }
  testWidgets(
    'busy action suppresses a supplied callback inside original button size',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommerceAction('buy', busy: true, onPressed: () => calls++),
          ),
        ),
      );
      final button = find.widgetWithText(FilledButton, 'buy');
      expect(
        find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(button).height, 46);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button);
      await tester.tap(button);
      expect(calls, 0);
    },
  );
  testWidgets('idle action retains label, style and height without a spinner', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommerceAction('buy', onPressed: () => calls++)),
      ),
    );
    final button = find.widgetWithText(FilledButton, 'buy');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.getSize(button).height, 46);
    expect(
      tester.widget<FilledButton>(button).style?.backgroundColor?.resolve({}),
      const Color(0xFF1677FF),
    );
    await tester.tap(button);
    expect(calls, 1);
  });
  testWidgets('busy disables Android pack purchase with immediate progress', (
    tester,
  ) async {
    var purchases = 0;
    const product = ProductOffer(
      productId: 'pack',
      name: 'synthetic',
      productType: 'POINTS_PACK',
      level: 'FREE',
      months: 0,
      cashAmountFen: 600,
      basePoints: 600,
      bonusPoints: 0,
      currency: 'CNY',
      channel: 'ALIPAY',
      available: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PointsPurchasePage(
          state: const CatalogState(
            channelAvailable: true,
            catalog: CommerceCatalog(
              configVersionId: 1,
              revisionNo: 1,
              agreementVersion: 'a',
              agreementUrl: '',
              supportEmail: '',
              products: [product],
            ),
          ),
          purchaseBlocked: true,
          onBack: () {},
          onBuy: (_) => purchases++,
          onAgreement: (_) {},
          onLegal: () {},
        ),
      ),
    );
    final purchaseButton = find.widgetWithText(FilledButton, '支付宝购买');
    expect(
      find.descendant(
        of: purchaseButton,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(purchaseButton, warnIfMissed: false);
    await tester.tap(purchaseButton, warnIfMissed: false);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '支付宝购买'),
    );
    expect(button.onPressed, isNull);
    expect(purchases, 0);
  });
  testWidgets('failed catalog is not presented as an empty sellable catalog', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PointsPurchasePage(
          state: const CatalogState(error: '会员服务暂不可用，请稍后重试'),
          onBack: () {},
          onBuy: (_) {},
          onAgreement: (_) {},
          onLegal: () {},
          onRefresh: () async {
            retries++;
          },
        ),
      ),
    );
    expect(find.text('会员服务暂不可用，请稍后重试'), findsOneWidget);
    expect(find.text('暂无可售积分包'), findsNothing);
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });
  testWidgets('selecting pack does not order until one payment confirmation', (
    tester,
  ) async {
    var purchases = 0;
    const product = ProductOffer(
      productId: 'pack-1',
      name: '动态积分包',
      productType: 'POINTS_PACK',
      level: 'FREE',
      months: 0,
      cashAmountFen: 600,
      basePoints: 600,
      bonusPoints: 0,
      currency: 'CNY',
      channel: 'ALIPAY',
      available: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PointsPurchasePage(
          state: const CatalogState(
            channelAvailable: true,
            catalog: CommerceCatalog(
              configVersionId: 1,
              revisionNo: 1,
              agreementVersion: 'a1',
              agreementUrl: '',
              supportEmail: '',
              products: [product],
            ),
          ),
          onBack: () {},
          onBuy: (_) => purchases++,
          onAgreement: (_) {},
          onLegal: () {},
        ),
      ),
    );
    await tester.tap(find.text('600 积分'));
    await tester.pump();
    expect(purchases, 0);
    await tester.tap(find.text('支付宝购买'));
    await tester.pump();
    expect(purchases, 1);
    expect(tester.takeException(), isNull);
  });
}
