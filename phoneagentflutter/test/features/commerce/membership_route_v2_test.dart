import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_route.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'fake_commerce_repository.dart';
import 'commerce_dto_test.dart' show orderJson;
import 'membership_contract_v2_test.dart' show fixture;

class V2Repository extends FakeCommerceRepository {
  V2Repository(this.type);
  final String type;
  Completer<CommerceOrder>? createGate;
  String get level =>
      (fixture('quote-$type')['membershipPreview'] as Map)['targetLevel']
          as String;
  @override
  Future<CommerceCatalog> catalog() async => CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'v1',
    agreementUrl: 'https://example.test/agreement',
    supportEmail: '',
    membershipRuleVersion: 'PAUSE_QUEUE_V1',
    membershipProtocolVersion: 2,
    products: [
      ProductOffer(
        productId: 'm',
        name: '会员包月',
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
    ],
  );
  @override
  Future<CommerceQuote> quote(String productId, int configVersionId) async {
    quoteCalls++;
    return CommerceDto.quote({
      ...fixture('quote-$type'),
      'quoteId': 'q',
      'productId': productId,
      'configVersionId': 1,
      'cashAmountFen': 4000,
      'currency': 'CNY',
      'expiresAt': '2099-01-01T00:00:00+08:00',
    });
  }

  @override
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String requestId,
    String agreementVersion,
  ) async {
    createCalls++;
    return createGate?.future ?? order('order-1');
  }

  @override
  Future<CommerceOrder> order(String orderNo) async => CommerceDto.order({
    ...orderJson(),
    'orderNo': orderNo,
    ...fixture('result-$type'),
  });
}

class V2Wallet implements PointsWalletRepository {
  @override
  Future<PointsAccount> account() async => const PointsAccount(
    totalBalance: 100,
    availableBalance: 100,
    heldBalance: 0,
    updatedAt: 'fixture',
  );
  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async =>
      const PointsLedgerPage(
        items: [],
        page: 0,
        size: 20,
        totalElements: 0,
        totalPages: 0,
      );
}

Widget app(V2Repository repo, FakePaymentLauncher native) => ProviderScope(
  overrides: [
    loginEpochProvider.overrideWithValue(1),
    commerceRepositoryProvider.overrideWithValue(repo),
    paymentLauncherProvider.overrideWithValue(native),
    pointsWalletRepositoryProvider.overrideWithValue(V2Wallet()),
    pointsWalletCacheProvider.overrideWithValue(const EmptyPointsWalletCache()),
    purchaseControllerProvider.overrideWith(
      (ref) => PurchaseController(repo, native, paymentChannel: 'ALIPAY'),
    ),
  ],
  child: const MaterialApp(home: MembershipRoute()),
);
Future<void> confirm(WidgetTester tester, V2Repository repo) async {
  await tester.tap(find.text(membershipName(repo.level)));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(Checkbox).last);
  await tester.tap(find.byType(Checkbox).last);
  await tester.pump();
  await tester.ensureVisible(find.text('购买会员'));
  await tester.tap(find.text('购买会员'));
  await tester.pumpAndSettle();
  expect(repo.createCalls, 0);
  expect(find.byType(Dialog), findsOneWidget);
  await tester.ensureVisible(find.widgetWithText(FilledButton, '支付 ¥40.00'));
  final staleConfirm = tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, '支付 ¥40.00'))
      .onPressed!;
  expect(
    find.widgetWithText(FilledButton, '支付 ¥40.00').hitTestable(),
    findsOneWidget,
  );
  await tester.tap(find.widgetWithText(FilledButton, '支付 ¥40.00'));
  // Exercise the same-frame callback after the first pop removed its hit target.
  staleConfirm();
}

void main() {
  for (final type in ['new', 'upgrade', 'renew', 'lower_queued']) {
    testWidgets('real route $type reaches actual fulfillment feedback', (
      tester,
    ) async {
      final repo = V2Repository(type);
      final native = FakePaymentLauncher();
      await tester.pumpWidget(app(repo, native));
      await tester.pumpAndSettle();
      await confirm(tester, repo);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('返回会员页面'), findsOneWidget);
      expect(
        find.text(switch (type) {
          'new' => '开通成功',
          'upgrade' => '升级成功',
          _ => '购买成功，套餐待生效',
        }),
        findsOneWidget,
      );
      expect(repo.quoteCalls, 1);
      expect(repo.createCalls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets(
    'creating original order shows processing and blocks repeated purchase',
    (tester) async {
      final repo = V2Repository('new')..createGate = Completer<CommerceOrder>();
      await tester.pumpWidget(app(repo, FakePaymentLauncher()));
      await tester.pumpAndSettle();
      await confirm(tester, repo);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('支付处理中…'), findsOneWidget);
      expect(repo.createCalls, 1);
      repo.createGate!.complete(await repo.order('order-1'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
