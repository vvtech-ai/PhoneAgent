import '../domain/commerce_catalog.dart';
import '../domain/commerce_order.dart';
import '../domain/platform_payment_amount.dart';

String orderPaymentAmount(CommerceOrder order, {bool paid = false}) {
  if (order.channel == 'APPLE_IAP') {
    final receipt = PlatformPaymentAmount.parse(
      order.platformPaidCurrency,
      order.platformPaidAmountMilliunits,
    );
    if (receipt != null) return receipt.display;
    return order.paymentState == 'SUCCEEDED'
        ? '以 Apple 账单为准'
        : '以 Apple 显示价格为准';
  }
  return money(
    paid ? order.cashPaidFen : order.cashAmountFen,
    currency: order.currency,
  );
}

String recoveryPaymentAmount(RecoveryPreview recovery) =>
    PlatformPaymentAmount.parse(
      recovery.platformPaidCurrency,
      recovery.platformPaidAmountMilliunits,
    )?.display ??
    money(recovery.cashPaidFen);
