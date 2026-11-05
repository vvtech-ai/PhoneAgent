import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'fake_commerce_repository.dart';

const unpublishedJson = <String, Object?>{
  'configVersionId': 0,
  'revisionNo': 0,
  'products': [],
  'benefitsByLevel': {},
};

class UnpublishedRepository extends FakeCommerceRepository {
  Object? catalogFailure, membershipFailure;
  @override
  Future<CommerceCatalog> catalog() async {
    if (catalogFailure != null) throw catalogFailure!;
    return CommerceDto.catalog(unpublishedJson);
  }

  @override
  Future<MembershipCurrent> membership() async {
    if (membershipFailure != null) throw membershipFailure!;
    return CommerceDto.membership({'level': 'FREE', 'terms': []});
  }
}

class UnrequestedPaymentLauncher extends FakePaymentLauncher {
  int availableCalls = 0, productCalls = 0;
  @override
  Future<bool> available() async {
    availableCalls++;
    throw StateError('An unpublished catalog has no native payment dependency');
  }

  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async {
    productCalls++;
    throw StateError('An unpublished catalog has no platform products');
  }
}

const closedAppleOffer = ProductOffer(
  productId: 'synthetic-closed',
  name: '已关闭会员商品',
  productType: 'MEMBERSHIP',
  level: 'BASIC',
  months: 1,
  cashAmountFen: 3000,
  basePoints: 0,
  bonusPoints: 0,
  currency: 'CNY',
  channel: 'APPLE_IAP',
  available: false,
  platformProductId: 'synthetic.closed.apple',
);

class ClosedAppleRepository extends UnpublishedRepository {
  @override
  Future<CommerceCatalog> catalog() async => const CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'a1',
    agreementUrl: 'https://example.test/agreement',
    supportEmail: 'support@example.test',
    products: [closedAppleOffer],
  );
}

class PriceReadingLauncher extends FakePaymentLauncher {
  int availableCalls = 0, productCalls = 0;
  Set<String>? queriedIds;
  @override
  Future<bool> available() async {
    availableCalls++;
    return true;
  }

  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async {
    productCalls++;
    queriedIds = ids;
    return const {
      'synthetic.closed.apple': PlatformProduct(
        'synthetic.closed.apple',
        '¥30',
      ),
    };
  }
}

Widget membershipPage(
  CatalogState state, {
  VoidCallback? onOrders,
  VoidCallback? onRestore,
  bool showRestore = false,
}) => MaterialApp(
  home: MembershipPage(
    state: state,
    showRestore: showRestore,
    availablePoints: 99,
    heldPoints: 1,
    onBack: () {},
    onRefresh: () async {},
    onPoints: () {},
    onOrders: onOrders ?? () {},
    onLedger: () {},
    onBuy: () {},
    onLevel: (_) {},
    onMonths: (_) {},
    onSupport: () {},
    onRestore: onRestore ?? () {},
  ),
);

void main() {
  test(
    'published closed Apple SKU retains native price lookup without sale',
    () async {
      final launcher = PriceReadingLauncher();
      final controller = CatalogController(
        ClosedAppleRepository(),
        launcher,
        requiresPlatformProducts: true,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.error, isEmpty);
      expect(launcher.availableCalls, 1);
      expect(launcher.productCalls, 1);
      expect(launcher.queriedIds, {'synthetic.closed.apple'});
      expect(controller.state.price(closedAppleOffer), '暂不可售');
      expect(controller.state.purchasable(closedAppleOffer), isFalse);
    },
  );
  for (final platformProducts in [false, true]) {
    test(
      'unpublished server literal skips native channel $platformProducts',
      () async {
        final launcher = UnrequestedPaymentLauncher();
        final controller = CatalogController(
          UnpublishedRepository(),
          launcher,
          requiresPlatformProducts: platformProducts,
        );
        addTearDown(controller.dispose);
        await controller.load();
        expect(controller.state.error, isEmpty);
        expect(controller.state.catalog?.configVersionId, 0);
        expect(controller.state.membership?.level, 'FREE');
        expect(launcher.availableCalls, 0);
        expect(launcher.productCalls, 0);
        expect(controller.state.channelAvailable, isFalse);
      },
    );
  }

  for (final failure in [
    const CommerceFailure('MEMBERSHIP_SERVICE_UNAVAILABLE'),
    const FormatException('missing products'),
    ApiFailure.network,
    ApiFailure.signedOut,
    ApiFailure.rejected,
    ApiFailure.invalidResponse,
  ]) {
    for (final fromMembership in [false, true]) {
      test(
        'actual failure $failure from membership=$fromMembership stays error',
        () async {
          final repository = UnpublishedRepository();
          if (fromMembership) {
            repository.membershipFailure = failure;
          } else {
            repository.catalogFailure = failure;
          }
          final launcher = UnrequestedPaymentLauncher();
          final controller = CatalogController(
            repository,
            launcher,
            requiresPlatformProducts: true,
          );
          addTearDown(controller.dispose);
          await controller.load();
          expect(controller.state.error, isNotEmpty);
          expect(controller.state.catalog, fromMembership ? isNotNull : isNull);
          expect(
            controller.state.membership,
            fromMembership ? isNull : isNotNull,
          );
          expect(launcher.availableCalls, 0);
        },
      );
    }
  }

  testWidgets('unconfigured membership shows total and no fake sales', (
    tester,
  ) async {
    await tester.pumpWidget(
      membershipPage(
        CatalogState(
          catalog: CommerceDto.catalog(unpublishedJson),
          membership: CommerceDto.membership({'level': 'FREE', 'terms': []}),
        ),
      ),
    );
    expect(find.text('会员与商品暂未配置'), findsOneWidget);
    expect(find.text('99'), findsOneWidget);
    expect(find.text('查看积分流水'), findsOneWidget);
    expect(find.text('订单与发票'), findsOneWidget);
    expect(find.text('会员与商品加载失败，请重试'), findsNothing);
    expect(find.text('购买会员'), findsNothing);
    expect(find.text('初级会员'), findsNothing);
    expect(find.text('当前支付渠道暂不可用'), findsNothing);
    expect(find.text('恢复购买'), findsNothing);
  });

  testWidgets('iOS unconfigured catalog retains original transaction restore', (
    tester,
  ) async {
    var restores = 0;
    await tester.pumpWidget(
      membershipPage(
        CatalogState(
          catalog: CommerceDto.catalog(unpublishedJson),
          membership: CommerceDto.membership({'level': 'FREE', 'terms': []}),
          requiresPlatformProducts: true,
        ),
        onRestore: () => restores++,
        showRestore: true,
      ),
    );
    await tester.tap(find.text('恢复购买'));
    expect(restores, 1);
    expect(find.text('会员与商品暂未配置'), findsOneWidget);
  });

  testWidgets(
    'unpublished sale keeps current term and original pending order',
    (tester) async {
      var orders = 0;
      var restores = 0;
      await tester.pumpWidget(
        membershipPage(
          CatalogState(
            catalog: CommerceDto.catalog(unpublishedJson),
            requiresPlatformProducts: true,
            membership: MembershipCurrent(
              level: 'BASIC',
              entitlementVersionId: 1,
              benefits: null,
              terms: const [],
              expiresAt: DateTime(2026, 12, 1),
              pendingOrderNo: 'synthetic-pending',
            ),
          ),
          onOrders: () => orders++,
          onRestore: () => restores++,
          showRestore: true,
        ),
      );
      expect(find.textContaining(' 到期'), findsOneWidget);
      expect(find.text('处理待购买事项'), findsOneWidget);
      await tester.tap(find.text('处理待购买事项'));
      expect(orders, 1);
      await tester.tap(find.text('恢复购买'));
      expect(restores, 1);
      expect(find.text('会员与商品暂未配置'), findsOneWidget);
    },
  );
}
