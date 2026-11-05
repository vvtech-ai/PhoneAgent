import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/controller/orders_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/commerce_orders_page.dart';
import 'fake_commerce_repository.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    OrdersState state, {
    VoidCallback? invoice,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommerceOrdersPage(
          state: state,
          onBack: () {},
          onRefresh: () async {},
          onNext: () {},
          onOrder: (_) {},
          onInvoice: (_) => invoice?.call(),
        ),
      ),
    );
  }

  testWidgets('empty orders omit swipe instruction and table navigation', (
    tester,
  ) async {
    await show(tester, const OrdersState());
    expect(find.text('暂无更多数据'), findsOneWidget);
    expect(find.textContaining('暂不支持自助退款'), findsNothing);
    expect(find.text('左右滑动查看支付渠道与状态'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget); // page back only
    for (final heading in ['类型', '日期', '金额', '支付渠道', '状态', '操作']) {
      expect(find.text(heading), findsOneWidget);
    }
  });

  for (final state in [
    const OrdersState(loading: true),
    const OrdersState(error: '订单服务暂不可用，请稍后重试'),
  ]) {
    testWidgets(
      'empty loading/error does not expose table arrows ${state.loading}',
      (tester) async {
        await show(tester, state);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
        expect(find.text('暂无更多数据'), findsNothing);
        if (state.error.isNotEmpty) {
          expect(find.text(state.error), findsOneWidget);
          expect(find.text('重试'), findsOneWidget);
        } else {
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'existing orders retain scrolling and invoice action with Demo hint',
    (tester) async {
      tester.view.physicalSize = const Size(375, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var invoices = 0;
      await show(
        tester,
        OrdersState(
          items: [sampleOrder(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED')],
        ),
        invoice: () => invoices++,
      );
      expect(find.text('左右滑动查看支付渠道与状态'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      final horizontal = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(horizontal.controller!.offset, 0);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(horizontal.controller!.offset, greaterThan(0));
      await tester.tap(find.text('开票说明'));
      expect(invoices, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
