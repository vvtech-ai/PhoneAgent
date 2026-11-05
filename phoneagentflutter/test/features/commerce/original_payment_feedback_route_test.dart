import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_route.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_feedback_sheet.dart';
import 'fake_commerce_repository.dart';

class _Native extends FakePaymentLauncher {
  final gate = Completer<NativePaymentResult>();
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    launches++;
    return gate.future;
  }
}

Future<void> _mount(
  WidgetTester tester,
  FakeCommerceRepository repo,
  _Native native,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginEpochProvider.overrideWithValue(1),
        commerceRepositoryProvider.overrideWithValue(repo),
        paymentLauncherProvider.overrideWithValue(native),
        purchaseControllerProvider.overrideWith(
          (ref) => PurchaseController(repo, native, paymentChannel: 'ALIPAY'),
        ),
      ],
      child: const MaterialApp(home: PurchaseResultRoute(orderNo: 'order-1')),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('重新支付'));
  await tester.tap(find.text('重新支付'));
  await tester.pump();
}

void main() {
  testWidgets(
    'original retry waiting hides order details and query/close actions',
    (tester) async {
      final repo = FakeCommerceRepository()
        ..current = sampleOrder(payment: 'PROCESSING');
      final native = _Native();
      await _mount(tester, repo, native);
      try {
        expect(native.launches, 1);
        expect(find.text('查询原订单'), findsNothing);
        expect(find.text('请求关闭订单'), findsNothing);
        expect(find.text('order-1'), findsNothing);
      } finally {
        native.gate.complete(
          const NativePaymentResult(nativeResultStatus: '6001'),
        );
      }
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'original retry SDK return shows only result and done, normal detail returns after dismiss',
    (tester) async {
      final repo = FakeCommerceRepository()
        ..current = sampleOrder(payment: 'PROCESSING');
      final native = _Native();
      await _mount(tester, repo, native);
      native.gate.complete(
        const NativePaymentResult(nativeResultStatus: '6001'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PurchaseFeedbackSheet), findsOneWidget);
      expect(find.text('支付已取消'), findsOneWidget);
      expect(find.text('查询原订单'), findsNothing);
      expect(find.text('查看原订单'), findsNothing);
      expect(find.text('重新支付'), findsNothing);
      expect(find.text('order-1'), findsNothing);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.byType(PurchaseFeedbackSheet), findsNothing);
      expect(find.text('查询原订单'), findsOneWidget);
      expect(repo.createCalls, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
