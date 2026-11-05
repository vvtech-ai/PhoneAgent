import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_period_card.dart';

void main() {
  testWidgets('商品自身原价保留角分，不与展示折扣矛盾', (tester) async {
    const monthly = ProductOffer(
      productId: 'm1',
      name: '月度',
      productType: 'MEMBERSHIP',
      level: 'BASIC',
      months: 1,
      cashAmountFen: 1950,
      basePoints: 0,
      bonusPoints: 0,
      currency: 'CNY',
      channel: 'ALIPAY',
      available: true,
    );
    const quarterly = ProductOffer(
      productId: 'm3',
      name: '季度',
      productType: 'MEMBERSHIP',
      level: 'BASIC',
      months: 3,
      cashAmountFen: 5000,
      originalCashAmountFen: 5850,
      basePoints: 0,
      bonusPoints: 0,
      currency: 'CNY',
      channel: 'ALIPAY',
      available: true,
    );
    const state = CatalogState(
      channelAvailable: true,
      catalog: CommerceCatalog(
        configVersionId: 1,
        revisionNo: 1,
        agreementVersion: 'fixture',
        agreementUrl: 'https://example.com/fixture',
        supportEmail: '',
        products: [monthly, quarterly],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            child: MembershipPeriodCard(
              state: state,
              offer: quarterly,
              onSelect: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('¥58.50'), findsOneWidget);
    expect(find.text('¥50'), findsOneWidget);
    expect(find.text('8.5折'), findsOneWidget);
  });

  testWidgets('季度原价使用自身配置，不由同档月价推算', (tester) async {
    final quarterly = offer(months: 3, cash: 9900, original: 15900);
    await render(tester, quarterly, extra: [offer(months: 1, cash: 3900)]);
    expect(find.text('¥159'), findsOneWidget);
    expect(find.text('6.2折'), findsOneWidget);
    expect(find.text('¥117'), findsNothing);
    expect(find.text('¥99'), findsOneWidget);
  });

  testWidgets('年度原价无需月度商品且不复用季度原价', (tester) async {
    await render(tester, offer(months: 12, cash: 36900, original: 46800));
    expect(find.text('¥468'), findsOneWidget);
    expect(find.text('7.9折'), findsOneWidget);
    expect(find.text('¥369'), findsOneWidget);
  });

  testWidgets('旧商品缺原价时不推算折扣', (tester) async {
    await render(
      tester,
      offer(months: 3, cash: 9900),
      extra: [offer(months: 1, cash: 3900)],
    );
    expect(find.text('¥117'), findsNothing);
    expect(find.text('8.5折'), findsNothing);
  });

  testWidgets('月度可显示自己配置的原价与折扣', (tester) async {
    await render(tester, offer(months: 1, cash: 3900, original: 5900));
    expect(find.text('¥59'), findsOneWidget);
    expect(find.text('6.6折'), findsOneWidget);
  });

  testWidgets('无效原价不会生成营销折扣', (tester) async {
    for (final product in [
      offer(months: 3, cash: 9900, original: 9900),
      offer(months: 3, cash: 9900, original: 9000),
    ]) {
      await render(tester, product, extra: [offer(months: 1, cash: 3900)]);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.endsWith('折') ?? false),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('不可售保留商品价格资料，卡片不显示额外状态标签', (tester) async {
    await render(
      tester,
      offer(months: 3, cash: 9900, original: 15900, available: false),
    );
    expect(find.text('¥159'), findsOneWidget);
    expect(find.text('6.2折'), findsOneWidget);
    expect(find.text('暂不可售'), findsNothing);
  });

  testWidgets('StoreKit价格原样保留且不比较后台人民币原价', (tester) async {
    await render(
      tester,
      offer(months: 3, cash: 9900, original: 15900),
      platform: true,
    );
    expect(find.text('€9.99'), findsOneWidget);
    expect(find.text('¥159'), findsNothing);
    expect(find.text('6.2折'), findsNothing);
  });
}

ProductOffer offer({
  required int months,
  required int cash,
  int? original,
  bool available = true,
}) => ProductOffer(
  productId: 'synthetic-$months',
  name: '合成会员',
  productType: 'MEMBERSHIP',
  level: 'BASIC',
  months: months,
  cashAmountFen: cash,
  originalCashAmountFen: original,
  basePoints: 0,
  bonusPoints: 0,
  currency: 'CNY',
  channel: 'ALIPAY',
  available: available,
  platformProductId: 'sku-$months',
  unavailableReason: available ? null : '暂不可售',
);

Future<void> render(
  WidgetTester tester,
  ProductOffer product, {
  List<ProductOffer> extra = const [],
  bool platform = false,
}) async {
  final state = CatalogState(
    channelAvailable: true,
    requiresPlatformProducts: platform,
    platformProducts: platform
        ? {'sku-3': const PlatformProduct('sku-3', '€9.99')}
        : const {},
    catalog: CommerceCatalog(
      configVersionId: 1,
      revisionNo: 1,
      agreementVersion: 'fixture',
      agreementUrl: 'https://example.com/fixture',
      supportEmail: '',
      products: [...extra, product],
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 140,
          child: MembershipPeriodCard(
            state: state,
            offer: product,
            onSelect: () {},
          ),
        ),
      ),
    ),
  );
}
