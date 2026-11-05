import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/controller/orders_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/commerce_orders_page.dart';

void main() {
  for (final state in [
    ('PENDING', 'NOT_STARTED', 'PENDING_PAYMENT'),
    ('PROCESSING', 'NOT_STARTED', 'PAYING'),
    ('SUCCEEDED', 'EXCEPTION', 'CREDITING'),
  ]) {
    testWidgets(
      '${state.$1}/${state.$2} exposes original order without invoice or payment',
      (tester) async {
        final order = CommerceDto.order(
          orderJson(state.$1, state.$2, state.$3),
        );
        String? opened;
        var invoices = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: CommerceOrdersPage(
              state: OrdersState(items: [order]),
              onBack: () {},
              onRefresh: () async {},
              onNext: () {},
              onOrder: (value) => opened = value.orderNo,
              onInvoice: (_) => invoices++,
            ),
          ),
        );
        expect(find.text('查看订单'), findsOneWidget);
        expect(find.text('—'), findsNothing);
        await tester.tap(find.text('查看订单'));
        expect(opened, 'synthetic-order');
        expect(invoices, 0);
        expect(order.canPay, state.$1 == 'PENDING');
      },
    );
  }

  testWidgets('actual snapshot fields identify single membership and Alipay', (
    tester,
  ) async {
    final order = CommerceDto.order(
      orderJson('PENDING', 'NOT_STARTED', 'PENDING_PAYMENT'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommerceOrdersPage(
          state: OrdersState(items: [order]),
          onBack: () {},
          onRefresh: () async {},
          onNext: () {},
          onOrder: (_) {},
          onInvoice: (_) {},
        ),
      ),
    );
    expect(find.text('初级会员·月卡'), findsOneWidget);
    expect(find.text('连续包月'), findsNothing);
    await tester.tap(find.byTooltip('向右滚动'));
    await tester.pumpAndSettle();
    expect(find.text('支付宝'), findsOneWidget);
    expect(find.text('移动支付'), findsNothing);
  });

  testWidgets('completed paid order preserves invoice action', (tester) async {
    final order = CommerceDto.order({
      ...orderJson('SUCCEEDED', 'SUCCEEDED', 'COMPLETED'),
      'invoiceAllowed': true,
    });
    String? invoiceOrder;
    await tester.pumpWidget(
      MaterialApp(
        home: CommerceOrdersPage(
          state: OrdersState(items: [order]),
          onBack: () {},
          onRefresh: () async {},
          onNext: () {},
          onOrder: (_) {},
          onInvoice: (value) => invoiceOrder = value.orderNo,
        ),
      ),
    );
    await tester.tap(find.text('开发票'));
    expect(invoiceOrder, 'synthetic-order');
  });

  test('invalid optional membership metadata remains a protocol error', () {
    for (final invalid in [
      {'membershipLevel': 'UNKNOWN'},
      {'membershipLevel': 'FREE'},
      {'membershipMonths': 2},
      {'membershipMonths': '1'},
    ]) {
      expect(
        () => CommerceDto.order({
          ...orderJson('PENDING', 'NOT_STARTED', 'PENDING_PAYMENT'),
          ...invalid,
        }),
        throwsFormatException,
      );
    }
  });

  testWidgets(
    'legacy response uses neutral membership label without inferred grade',
    (tester) async {
      final json = orderJson('PENDING', 'NOT_STARTED', 'PENDING_PAYMENT')
        ..remove('membershipLevel')
        ..remove('membershipMonths')
        ..['productName'] = '历史商品标题';
      final order = CommerceDto.order(json);
      await tester.pumpWidget(
        MaterialApp(
          home: CommerceOrdersPage(
            state: OrdersState(items: [order]),
            onBack: () {},
            onRefresh: () async {},
            onNext: () {},
            onOrder: (_) {},
            onInvoice: (_) {},
          ),
        ),
      );
      expect(find.text('会员套餐'), findsOneWidget);
      expect(order.productName, '历史商品标题');
      expect(find.text('初级会员·月卡'), findsNothing);
    },
  );
}

Map<String, Object?> orderJson(
  String payment,
  String fulfillment,
  String appState,
) => {
  'orderNo': 'synthetic-order',
  'quoteId': 'synthetic-quote',
  'productType': 'MEMBERSHIP',
  'productName': '连续包月',
  'paymentState': payment,
  'fulfillmentState': fulfillment,
  'appState': appState,
  'cashAmountFen': 3900,
  'cashPaidFen': payment == 'SUCCEEDED' ? 3900 : 0,
  'currency': 'CNY',
  'channel': 'ALIPAY',
  'createdAt': '2026-10-13 12:00:00',
  'recoveryRequired': fulfillment == 'EXCEPTION',
  'invoiceAllowed': false,
  'rowVersion': 1,
  'membershipLevel': 'BASIC',
  'membershipMonths': 1,
};
