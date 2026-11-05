import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/membership_checkout.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_price_options.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/points_offer_card.dart';
import 'fake_commerce_repository.dart';
import 'platform_purchase_fixture.dart';

Widget _page(
  CatalogState state, {
  VoidCallback? ledger,
  VoidCallback? orders,
  VoidCallback? pending,
  bool showRestore = false,
}) => MaterialApp(
  home: MembershipPage(
    state: state,
    showRestore: showRestore,
    availablePoints: 800,
    heldPoints: 0,
    onBack: () {},
    onRefresh: () async {},
    onPoints: () {},
    onOrders: orders ?? () {},
    onLedger: ledger ?? () {},
    onPending: pending,
    onBuy: () {},
    onLevel: (_) {},
    onMonths: (_) {},
    onSupport: () {},
    onRestore: () {},
  ),
);

void main() {
  testWidgets(
    'catalog refresh does not briefly expose the points purchase entry',
    (tester) async {
      await tester.pumpWidget(_page(const CatalogState(loading: true)));
      expect(find.text('+ 购买积分'), findsNothing);
      expect(find.text('查看积分流水'), findsOneWidget);
    },
  );
  testWidgets('disabled iOS sales retains original Apple purchase restore', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(
        platformState(member: false, points: false, apple: true),
        showRestore: true,
      ),
    );
    await tester.scrollUntilVisible(find.text('恢复购买'), 200);
    expect(find.text('恢复购买'), findsOneWidget);
    expect(find.text('+ 购买积分'), findsNothing);
    expect(find.byType(MembershipPriceOptions), findsNothing);
  });
  test(
    'new unpublished response has explicit closed flags without fake publication',
    () {
      final catalog = CommerceDto.catalog({
        'configVersionId': 0,
        'revisionNo': 0,
        'products': [],
        'benefitsByLevel': {},
        'membershipEnabled': false,
        'pointsPackEnabled': false,
      });
      expect(catalog.membershipEnabled, isFalse);
      expect(catalog.pointsPackEnabled, isFalse);
      expect(catalog.configVersionId, 0);
    },
  );
  for (final member in [true, false]) {
    for (final points in [true, false]) {
      test('catalog independent flags $member/$points govern purchasable', () {
        final fixture = platformState(member: member, points: points);
        final state = CatalogState(
          catalog: fixture.catalog,
          membership: const MembershipCurrent(
            level: 'FREE',
            entitlementVersionId: 1,
            benefits: {},
            terms: [],
          ),
          channelAvailable: true,
        );
        expect(state.purchasable(state.catalog!.products[0]), member);
        expect(state.purchasable(state.catalog!.products[1]), points);
      });
      testWidgets('member page $member/$points hides only new sale content', (
        tester,
      ) async {
        var ledgers = 0, orders = 0, pending = 0;
        await tester.pumpWidget(
          _page(
            platformState(member: member, points: points),
            ledger: () => ledgers++,
            orders: () => orders++,
            pending: () => pending++,
          ),
        );
        expect(find.text('会员与积分'), findsOneWidget);
        expect(find.text('800'), findsOneWidget);
        expect(find.text('+ 购买积分'), points ? findsOneWidget : findsNothing);
        expect(
          find.byType(MembershipPriceOptions),
          member ? findsOneWidget : findsNothing,
        );
        expect(find.text('购买会员'), member ? findsOneWidget : findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        if (!member) {
          expect(find.text('当前权益'), findsOneWidget);
          expect(find.text('每月到账 1,234 积分'), findsOneWidget);
          expect(find.text('99 路同时外呼'), findsNothing);
          expect(find.text('高级'), findsNothing);
        }
        await tester.tap(find.text('订单与发票'));
        await tester.tap(find.text('查看积分流水'));
        await tester.ensureVisible(find.text('处理待购买事项'));
        await tester.tap(find.text('处理待购买事项'));
        expect([orders, ledgers, pending], [1, 1, 1]);
      });
    }
  }
  test('missing legacy flags retain historical availability', () {
    final raw = platformCatalog()
      ..remove('membershipEnabled')
      ..remove('pointsPackEnabled');
    final state = CatalogState(
      catalog: CommerceDto.catalog(raw),
      membership: const MembershipCurrent(
        level: 'FREE',
        entitlementVersionId: 1,
        benefits: {},
        terms: [],
      ),
      channelAvailable: true,
    );
    expect(state.catalog!.products.every(state.purchasable), isTrue);
  });
  for (final key in ['membershipEnabled', 'pointsPackEnabled']) {
    for (final invalid in [null, 'true', 1]) {
      test('$key rejects explicit invalid $invalid', () {
        expect(
          () => CommerceDto.catalog(platformCatalog()..[key] = invalid),
          throwsFormatException,
        );
      });
    }
  }
  for (final member in [true, false]) {
    test(
      'direct checkout cannot quote disabled ${member ? 'membership' : 'points'}',
      () async {
        final state = platformState(member: !member, points: member);
        final repo = FakeCommerceRepository();
        final native = FakePaymentLauncher();
        final controller = PurchaseController(
          repo,
          native,
          paymentChannel: 'ALIPAY',
        );
        await MembershipCheckout(controller).buy(
          state.catalog!.products[member ? 0 : 1],
          state,
          confirm: (_) async => true,
          isCurrent: () => true,
        );
        expect(repo.quoteCalls, 0);
        expect(repo.createCalls, 0);
        expect(native.launches, 0);
        controller.dispose();
      },
    );
  }
  testWidgets(
    'direct points page disabled has no products, payment or agreement',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PointsPurchasePage(
            state: platformState(points: false),
            onBack: () {},
            onBuy: (_) => fail('Disabled'),
            onAgreement: (_) {},
            onLegal: () {},
          ),
        ),
      );
      expect(find.byType(PointsOfferCard), findsNothing);
      expect(find.text('支付宝购买'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('积分购买暂未开放'), findsOneWidget);
    },
  );
}
