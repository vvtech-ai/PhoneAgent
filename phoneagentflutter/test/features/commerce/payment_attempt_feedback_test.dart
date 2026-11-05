import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_failure.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/payment_attempt_feedback.dart';
import 'fake_commerce_repository.dart';

class _Launcher extends FakePaymentLauncher {
  _Launcher(this.code);
  final String? code;
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    launches++;
    return NativePaymentResult(nativeResultStatus: code);
  }
}

void main() {
  for (final code in [
    'COMMERCE_ORDER_MINUTE_LIMITED',
    'COMMERCE_ORDER_HOUR_LIMITED',
    'COMMERCE_MATERIAL_INTERVAL_LIMITED',
    'COMMERCE_MATERIAL_LIMIT_REACHED',
    'COMMERCE_SERVICE_UNAVAILABLE',
    'COMMERCE_NETWORK_UNAVAILABLE',
    'MEMBERSHIP_PAYMENT_UNKNOWN',
    'MEMBERSHIP_STATE_CONFLICT',
    'AC0006',
    'CONFIGURATION_CONFLICT',
  ]) {
    test('final feedback retains domain safe cause $code', () {
      final message = CommerceFailure(code).message;
      final state = PurchaseState(
        order: sampleOrder(payment: 'PROCESSING'),
        error: message,
      );
      expect(paymentAttemptFeedback(state).message, message);
      expect(paymentAttemptFeedback(state).completed, isFalse);
    });
  }
  test(
    'unknown provider text is never projected or relabeled as frequency',
    () {
      final state = PurchaseState(
        order: sampleOrder(payment: 'PROCESSING'),
        error: 'private-provider token frequency order',
      );
      expect(paymentAttemptFeedback(state).message, '本次支付未完成，请稍后重试。');
    },
  );
  for (final outcome in [
    NativePaymentOutcome.canceled,
    NativePaymentOutcome.pending,
  ]) {
    test('native $outcome still overrides safe prior failure', () {
      final state = PurchaseState(
        order: sampleOrder(payment: 'PROCESSING'),
        nativeOutcome: outcome,
        error: const CommerceFailure('COMMERCE_MATERIAL_LIMIT_REACHED').message,
      );
      expect(
        paymentAttemptFeedback(state).title,
        outcome == NativePaymentOutcome.canceled ? '本次支付已取消' : '等待支付确认',
      );
    });
  }

  for (final pair in {
    '6001': '支付已取消',
    '4000': '支付失败',
    '9000': '本次支付未完成',
    '8000': '本次支付未完成',
    '6004': '本次支付未完成',
    '7001': '本次支付未完成',
  }.entries) {
    test(
      'attempt ${pair.key} keeps PROCESSING original and displays ${pair.value}',
      () async {
        final repo = FakeCommerceRepository();
        final native = _Launcher(pair.key);
        final controller = PurchaseController(
          repo,
          native,
          paymentChannel: 'ALIPAY',
        );
        await controller.preview('m1', 1, agreementAccepted: true);
        // Create PENDING, but authoritative query returns PROCESSING.
        final pending = repo.current;
        repo.delayedOrder = null;
        await controller.confirmPurchase('v1');
        repo.current = sampleOrder(payment: 'PROCESSING');
        await controller.query(pending.orderNo);
        expect(controller.state.nativeResultStatus, pair.key);
        expect(paymentAttemptFeedback(controller.state).title, pair.value);
        expect(controller.state.order?.paymentState, 'PROCESSING');
        expect(controller.state.order?.unresolved, isTrue);
        expect(controller.state.order?.canPay, isFalse);
        expect(repo.createCalls, 1);
        expect(native.launches, 1);
        expect(repo.queries, 2);
        controller.dispose();
      },
    );
  }
  test(
    'authoritative completion overrides canceled attempt and upgrade uses server completion',
    () {
      final state = PurchaseState(
        order: sampleOrder(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED'),
        nativeResultStatus: '6001',
        error: const CommerceFailure('COMMERCE_MATERIAL_LIMIT_REACHED').message,
      );
      expect(paymentAttemptFeedback(state).title, '支付成功');
      expect(paymentAttemptFeedback(state, upgrade: true).title, '升级成功');
      expect(paymentAttemptFeedback(state).completed, isTrue);
    },
  );
  test(
    'paid but unfulfilled overrides failure without claiming granted rights',
    () {
      final state = PurchaseState(
        order: sampleOrder(payment: 'SUCCEEDED'),
        nativeResultStatus: '4000',
        error: const CommerceFailure('COMMERCE_MATERIAL_LIMIT_REACHED').message,
      );
      expect(paymentAttemptFeedback(state).title, '已支付，权益处理中');
      expect(paymentAttemptFeedback(state).completed, isFalse);
    },
  );
  test(
    'timeout and unknown keep original and never show confirmation-in-progress wording',
    () async {
      final repo = FakeCommerceRepository();
      final native = FakePaymentLauncher()..fail = true;
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.confirmPurchase('v1');
      expect(paymentAttemptFeedback(controller.state).title, '本次支付未完成');
      expect(controller.state.order?.unresolved, isTrue);
      expect(repo.createCalls, 1);
      expect(OrderAppState.paying.label, '未完成支付');
      controller.dispose();
    },
  );
}
