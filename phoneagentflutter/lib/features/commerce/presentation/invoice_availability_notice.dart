import '../domain/commerce_order.dart';

/// Explains known facts; server invoiceAllowed remains the application authority.
String invoiceAvailabilityNotice(CommerceOrder order) {
  if (order.invoiceAllowed) return '';
  if (order.paymentState == 'CANCELED' || order.paymentState == 'CLOSED') {
    return '该订单已取消或关闭，无法申请开票';
  }
  if (order.paymentState != 'SUCCEEDED') {
    return '该订单尚未支付成功，支付成功后可查看开票资格';
  }
  final raw = order.platformPaidAmountMilliunits;
  final amount = raw == null ? null : BigInt.tryParse(raw);
  final currency = order.platformPaidCurrency;
  if (order.channel == 'APPLE_IAP' && (currency == null || amount == null)) {
    return '暂无法确认该订单的开票资格，请联系售后协助处理';
  }
  if (amount == BigInt.zero) return '该订单无可开票的实付金额';
  if (currency != null && currency != 'CNY') {
    return '该订单使用外币支付，暂不支持在 App 内申请发票';
  }
  if (currency == 'CNY' &&
      amount != null &&
      amount % BigInt.from(10) != BigInt.zero) {
    return '该订单金额暂不支持在线开票，请联系售后协助处理';
  }
  if (order.cashPaidFen == 0) return '该订单无可开票的实付金额';
  return '当前订单无法发起新的开票申请，请查询已有发票或联系售后';
}
