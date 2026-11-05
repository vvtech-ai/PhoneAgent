import '../../domain/commerce_order.dart';
import '../membership_card_presentation.dart';

String orderProductLabel(CommerceOrder order) {
  if (order.productType == 'MEMBERSHIP') {
    return membershipPlanLabel(
      level: order.membershipLevel,
      months: order.membershipMonths,
    );
  }
  return order.productName;
}

String orderChannelLabel(String channel) => switch (channel) {
  'ALIPAY' => '支付宝',
  'APPLE_IAP' => '应用内购买',
  'WECHAT' => '微信支付',
  _ => '—',
};

String orderListStateLabel(CommerceOrder order) => order.appleFlowExpired
    ? '已超时关闭'
    : switch (order.paymentState) {
        'PENDING' => '待支付',
        'PROCESSING' => '支付处理中',
        'SUCCEEDED' => '支付成功',
        'FAILED' => '支付失败',
        'CANCELED' => '已取消',
        'CLOSED' => '已关闭',
        _ => '—',
      };
