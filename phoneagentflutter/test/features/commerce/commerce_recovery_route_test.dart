import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/commerce/data/api_commerce_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_route.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_sheet.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/pending_membership_purchase_sheet.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'commerce_recovery_transport.dart';
import 'fake_commerce_repository.dart';
import 'membership_route_v2_test.dart' show V2Wallet;

Future<PurchaseController> mount(
  WidgetTester tester,
  CommerceRecoveryTransport server,
  FakePaymentLauncher native, {
  bool completed = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = ApiCommerceRepository(server.api);
  final purchase = PurchaseController(repo, native, paymentChannel: 'ALIPAY');
  await tester.runAsync(() async {
    await purchase.preview('BASIC', 1, agreementAccepted: true);
    await purchase.confirmPurchase('v1');
    if (!completed) {
      server.queryStatus = 502;
      await purchase.query('order-1');
      server.queryStatus = 200;
    }
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWithValue(1),
        commerceRepositoryProvider.overrideWithValue(repo),
        paymentLauncherProvider.overrideWithValue(native),
        purchaseControllerProvider.overrideWith((ref) => purchase),
        pointsWalletRepositoryProvider.overrideWithValue(V2Wallet()),
        pointsWalletCacheProvider.overrideWithValue(
          const EmptyPointsWalletCache(),
        ),
        pointsBillingProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: MembershipRoute()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(Checkbox).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox).last);
  await tester.pump();
  return purchase;
}

Future<void> buy(WidgetTester tester) async {
  // Use an eligible higher-tier offer; duplicate BASIC purchases are now blocked.
  await tester.tap(find.text('中级'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('升级会员'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('升级会员'));
  await tester.pumpAndSettle();
}

void main() {
  for (final pair in <String, String>{
    '502': '支付服务暂不可用，请稍后重试',
    'COMMERCE_MATERIAL_LIMIT_REACHED': '支付操作过于频繁，本订单支付重试次数已达上限，请查询原订单',
  }.entries) {
    testWidgets(
      'real route displays ${pair.key} after fulfilled first purchase',
      (tester) async {
        final server = CommerceRecoveryTransport();
        addTearDown(server.api.close);
        final native = FakePaymentLauncher();
        await mount(tester, server, native, completed: true);
        if (pair.key == '502') {
          server.quoteStatus = 502;
        } else {
          server.errorCode = pair.key;
        }
        await buy(tester);
        expect(find.text(pair.value), findsOneWidget);
        expect(find.textContaining('private-provider'), findsNothing);
        expect(server.creates, 1);
        expect(native.launches, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'C1 stale PROCESSING query502 reconciles original before next explicit purchase',
    (tester) async {
      final server = CommerceRecoveryTransport()
        ..payment = 'PROCESSING'
        ..fulfillment = 'NOT_STARTED';
      addTearDown(server.api.close);
      final native = FakePaymentLauncher();
      final purchase = await mount(tester, server, native);
      expect(purchase.snapshot.order?.paymentState, 'PROCESSING');
      server
        ..payment = 'SUCCEEDED'
        ..fulfillment = 'SUCCEEDED';
      final offset = server.requests.length;
      await buy(tester);
      expect(purchase.snapshot.order?.fulfillmentState, 'SUCCEEDED');
      expect(find.byType(PendingMembershipPurchaseSheet), findsNothing);
      expect(find.byType(MembershipConfirmationSheet), findsNothing);
      expect(
        server.requests.skip(offset).first.uri.path,
        endsWith('/orders/order-1'),
      );
      expect(server.quotes, 1);
      expect(server.creates, 1);
      await tester.ensureVisible(find.byType(Checkbox).last);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      await buy(tester);
      expect(find.byType(MembershipConfirmationSheet), findsOneWidget);
      expect(server.quotes, 2);
      expect(server.creates, 1);
      expect(native.launches, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final paid in [false, true]) {
    testWidgets('pending original query502 remains recoverable paid=$paid', (
      tester,
    ) async {
      final server = CommerceRecoveryTransport()
        ..payment = paid ? 'SUCCEEDED' : 'PROCESSING'
        ..fulfillment = paid ? 'PROCESSING' : 'NOT_STARTED';
      addTearDown(server.api.close);
      final native = FakePaymentLauncher();
      final purchase = await mount(tester, server, native);
      server.queryStatus = 502;
      await buy(tester);
      expect(find.byType(PendingMembershipPurchaseSheet), findsOneWidget);
      expect(find.text('支付服务暂不可用，请稍后重试'), findsOneWidget);
      expect(find.text('刷新状态'), findsOneWidget);
      expect(purchase.snapshot.order?.unresolved, isTrue);
      expect(server.creates, 1);
      expect(native.launches, 1);
      server
        ..queryStatus = 200
        ..payment = 'SUCCEEDED'
        ..fulfillment = 'SUCCEEDED';
      await tester.tap(find.text('刷新状态'));
      await tester.pumpAndSettle();
      expect(find.byType(PendingMembershipPurchaseSheet), findsNothing);
      expect(purchase.snapshot.order?.fulfillmentState, 'SUCCEEDED');
      expect(server.creates, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
