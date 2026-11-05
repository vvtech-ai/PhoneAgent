import 'membership_result_feedback.dart';
import '../domain/commerce_failure.dart';

import 'controller/purchase_controller.dart';
import '../domain/payment_launcher.dart';

class PaymentAttemptFeedback {
  const PaymentAttemptFeedback(
    this.title,
    this.message, {
    this.completed = false,
    this.processing = false,
  });
  final String title, message;
  final bool completed, processing;
}

PaymentAttemptFeedback paymentAttemptFeedback(
  PurchaseState state, {
  bool upgrade = false,
}) {
  final order = state.order;
  final apple = order?.channel == 'APPLE_IAP';
  final points = apple && order?.productType == 'POINTS_PACK';
  if (state.recoveredPreviousPurchase) {
    final completed =
        order?.paymentState == 'SUCCEEDED' &&
        order?.fulfillmentState == 'SUCCEEDED';
    return PaymentAttemptFeedback(
      completed ? '上次购买已处理完成' : '正在确认购买结果',
      state.recoveryMessage.isNotEmpty
          ? state.recoveryMessage
          : completed
          ? '上次购买已处理完成，本次未新增购买。'
          : '正在处理上次购买，本次未新增购买，请查询原订单。',
      completed: completed,
      processing: !completed,
    );
  }
  if (order?.paymentState == 'SUCCEEDED') {
    if (order?.fulfillmentState == 'SUCCEEDED') {
      final membership = membershipResultFeedback(order!);
      if (membership != null) {
        return PaymentAttemptFeedback(
          membership.title,
          membership.message,
          completed: true,
        );
      }
      return PaymentAttemptFeedback(
        points
            ? '购买成功，积分已到账'
            : upgrade
            ? '升级成功'
            : '支付成功',
        points ? '购买成功，积分已到账。' : '支付成功，权益已到账。',
        completed: true,
      );
    }
    return PaymentAttemptFeedback(
      points ? '积分到账处理中' : '已支付，权益处理中',
      points ? '支付已确认，积分到账处理中。' : '支付已确认，权益尚未到账。',
      processing: apple,
    );
  }
  if (order?.appleFlowExpired == true) {
    return const PaymentAttemptFeedback(
      '已超时关闭',
      '本次订单购买流程已超时结束。如 Apple 后续确认付款，仍会核验并处理原订单权益，可查询支付结果。',
    );
  }
  if (order != null && !order.unresolved) {
    return PaymentAttemptFeedback(
      order.paymentState == 'CANCELED'
          ? '支付已取消'
          : order.paymentState == 'FAILED'
          ? '支付失败'
          : '本次支付未完成',
      _attemptMessage(state.error, '本次支付未完成。'),
    );
  }
  if (state.nativeOutcome == NativePaymentOutcome.canceled) {
    return const PaymentAttemptFeedback('本次支付已取消', '本次支付已取消。');
  }
  if (state.nativeOutcome == NativePaymentOutcome.pending) {
    return const PaymentAttemptFeedback(
      '等待支付确认',
      '本次购买等待 Apple 确认，请勿重复支付。',
      processing: true,
    );
  }
  if (apple && state.waitingForApple) {
    return const PaymentAttemptFeedback(
      '等待 Apple 支付结果',
      '尚未收到 Apple 支付结果，请勿重复购买，可查询原订单。',
      processing: true,
    );
  }
  if (apple && state.busy) {
    return const PaymentAttemptFeedback(
      '正在确认支付结果',
      '正在核验支付及权益到账情况，请稍候。',
      processing: true,
    );
  }
  if (apple && state.error == '商品价格已变化，请刷新后重新确认') {
    return PaymentAttemptFeedback('商品价格已变化', state.error);
  }
  if (apple) {
    return const PaymentAttemptFeedback(
      '支付结果待确认',
      '请查询原订单确认支付结果，请勿重复支付。',
      processing: true,
    );
  }
  return switch (state.nativeResultStatus) {
    '6001' => const PaymentAttemptFeedback('支付已取消', '本次支付已取消。'),
    '4000' => PaymentAttemptFeedback(
      '支付失败',
      _attemptMessage(state.error, '本次支付未成功。'),
    ),
    _ => PaymentAttemptFeedback(
      '本次支付未完成',
      _attemptMessage(state.error, '本次支付未完成，请稍后重试。'),
    ),
  };
}

String _attemptMessage(String error, String fallback) {
  if (error.isEmpty) return fallback;
  return CommerceFailure.safeMessage(error) ?? '本次支付未完成，请稍后重试。';
}
