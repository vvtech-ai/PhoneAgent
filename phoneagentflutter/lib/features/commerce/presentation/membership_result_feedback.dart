import '../domain/commerce_order.dart';

/// Uses the actual fulfillment projection, never a pre-payment preview.
({String title, String message})? membershipResultFeedback(
  CommerceOrder order,
) {
  final membership = order.membershipFulfillment;
  if (membership == null || order.fulfillmentState != 'SUCCEEDED') return null;
  return switch (membership.entitlementState) {
    'QUEUED' => (
      title: '购买成功，套餐待生效',
      message:
          '付款后等待生效，当前权益不受影响。生效时发放首期 ${membership.queuedFirstGrantPoints} 积分。',
    ),
    'ACTIVE' => (
      title: membership.initialEntitlementState == 'QUEUED'
          ? '套餐已生效'
          : membership.actualPurchaseType == 'UPGRADE'
          ? '升级成功'
          : '开通成功',
      message:
          '首期 ${membership.firstActivationGrantedPoints ?? membership.initialGrantedPoints} 积分已到账。${membership.actualPurchaseType == 'UPGRADE' ? '原套餐剩余权益已保留，之后自动恢复。' : ''}',
    ),
    'PAUSED' => (
      title: '权益已保留',
      message: '剩余使用时间及未发积分计划已暂停，之后按顺序恢复。已到账积分仍可使用。',
    ),
    'EXHAUSTED' => (title: '套餐已用完', message: '该套餐使用时长已耗尽，已到账积分仍可使用。'),
    'REVOKED' => (title: '权益已撤销', message: '该套餐已退出履约，详情请联系客服。'),
    _ => null,
  };
}
