import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_route.dart';
import 'fake_commerce_repository.dart';

CommerceOrder _order(String id, {bool completed = false}) => CommerceOrder(
  orderNo: id,
  productType: 'POINTS_PACK',
  productName: '商品$id',
  paymentState: completed ? 'SUCCEEDED' : 'PENDING',
  fulfillmentState: completed ? 'SUCCEEDED' : 'NOT_STARTED',
  cashAmountFen: 100,
  cashPaidFen: completed ? 100 : 0,
  currency: 'CNY',
  channel: 'ALIPAY',
  createdAt: DateTime(2026),
  rowVersion: 1,
);

class _Repository extends FakeCommerceRepository {
  final gate = Completer<CommerceOrder>();
  final requested = <String>[];
  bool blockA = false;
  bool failB = false;
  @override
  Future<CommerceOrder> order(String orderNo) async {
    requested.add(orderNo);
    if (orderNo == 'order-B' && failB) throw StateError('synthetic failure');
    return orderNo == 'order-A' && blockA ? gate.future : _order(orderNo);
  }
}

void main() {
  for (final completed in [false, true]) {
    testWidgets('detail B never displays shared A; completed=$completed', (
      tester,
    ) async {
      final repo = _Repository();
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      // Retain A while another A refresh is still in flight.
      await controller.query('order-A');
      repo.blockA = true;
      final readingA = controller.query('order-A');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginEpochProvider.overrideWithValue(1),
            commerceRepositoryProvider.overrideWithValue(repo),
            paymentLauncherProvider.overrideWithValue(native),
            purchaseControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: PurchaseResultRoute(orderNo: 'order-B'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('order-A'), findsNothing);
      expect(find.text('重新支付'), findsNothing);
      repo.gate.complete(_order('order-A', completed: completed));
      await readingA;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.requested.last, 'order-B');
      expect(find.text('order-B'), findsOneWidget);
      expect(find.text('order-A'), findsNothing);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('detail B retries B after failure and cannot expose A actions', (
    tester,
  ) async {
    final repo = _Repository()..failB = true;
    final native = FakePaymentLauncher();
    final controller = PurchaseController(
      repo,
      native,
      paymentChannel: 'ALIPAY',
    );
    await controller.query('order-A');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          commerceRepositoryProvider.overrideWithValue(repo),
          paymentLauncherProvider.overrideWithValue(native),
          purchaseControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: PurchaseResultRoute(orderNo: 'order-B')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('order-A'), findsNothing);
    expect(find.text('重新支付'), findsNothing);
    repo.failB = false;
    await tester.tap(find.text('查询原订单'));
    await tester.pumpAndSettle();
    expect(find.text('order-B'), findsOneWidget);
    expect(repo.requested, ['order-A', 'order-B', 'order-B']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
