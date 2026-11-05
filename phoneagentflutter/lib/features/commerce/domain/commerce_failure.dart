class CommerceFailure implements Exception {
  const CommerceFailure(this.code, {this.httpStatus = 0});
  final String code;
  final int httpStatus;
  String get message => _messages[code] ?? '加载失败，请重试';

  /// Only messages from the domain catalog may survive final UI projection.
  static String? safeMessage(String message) =>
      _messages.containsValue(message) ? message : null;

  static const _messages = {
    'MEMBERSHIP_CLIENT_UPDATE_REQUIRED': '请更新客户端后购买会员',
    'MEMBERSHIP_SYNCING': '会员状态同步中，请稍后重试',
    'MEMBERSHIP_REVIEW_REQUIRED': '会员权益待核查，请联系客服',
    'QUOTE_STALE': '会员状态已变化，请刷新并重新确认',
    'MEMBERSHIP_SERVICE_UNAVAILABLE': '会员服务暂不可用，请稍后重试',
    'ORDER_SERVICE_UNAVAILABLE': '订单服务暂不可用，请稍后重试',
    'MEMBERSHIP_ORDER_EXISTS': '已有会员订单，请先查看原订单',
    'MEMBERSHIP_PAYMENT_UNKNOWN': '支付结果确认中，请查询原订单',
    'MEMBERSHIP_STATE_CONFLICT': '已支付，权益处理中，请查看恢复方案',
    'RECOVERY_CONFIRMATION_REQUIRED': '请本人确认恢复方案',
    'RECOVERY_PREVIEW_EXPIRED': '恢复方案已变化，请重新查看并确认',
    'RECOVERY_PRICING_UNAVAILABLE': '暂无法生成恢复方案，请联系售后',
    'PRODUCT_UNAVAILABLE': '商品暂不可购买',
    'CATALOG_CHANGED': '商品目录已更新，请刷新后重试',
    'QUOTE_EXPIRED': '报价已失效，请重新确认',
    'AGREEMENT_REQUIRED': '请先阅读并同意付费协议',
    'UPGRADE_NOT_ALLOWED': '当前会员不支持此变更',
    'IDEMPOTENCY_CONFLICT': '请求信息已变化，请重新操作',
    'APPLE_PRICE_CHANGED': '商品价格已变化，请刷新后重新确认',
    'APPLE_ATTEMPT_STORAGE_UNAVAILABLE': '暂时无法保存购买信息，请稍后重试',
    'APPLE_RECOVERY_TIMEOUT': '支付结果暂未确认，请稍后查询原订单',
    'APPLE_RECONCILIATION_PENDING': '原购买仍在处理中，请稍后重试；若持续未完成，请联系客服',
    'APPLE_RECOVERY_INCOMPLETE': '部分购买结果暂未确认，将稍后重试',
    'PAYMENT_EXPIRED': '支付资料已过期，请查询原订单',
    'CHANNEL_UNAVAILABLE': '当前支付渠道暂不可用',
    'PAYMENT_VERIFICATION_FAILED': '支付结果待核验，请查询原订单',
    'ACCOUNT_MISMATCH': '购买账号不匹配，请使用原账号恢复',
    'INVOICE_NOT_ALLOWED': '该订单暂不可申请开票',
    'INVOICE_SERVICE_UNAVAILABLE': '开票服务暂不可用，请稍后重试',
    'COMMERCE_ORDER_MINUTE_LIMITED': '支付操作过于频繁，请稍后重试',
    'COMMERCE_ORDER_HOUR_LIMITED': '支付操作过于频繁，请稍后重试',
    'COMMERCE_MATERIAL_INTERVAL_LIMITED': '支付操作过于频繁，请稍后重试',
    'COMMERCE_MATERIAL_LIMIT_REACHED': '支付操作过于频繁，本订单支付重试次数已达上限，请查询原订单',
    'COMMERCE_SERVICE_UNAVAILABLE': '支付服务暂不可用，请稍后重试',
    'COMMERCE_NETWORK_UNAVAILABLE': '网络连接异常，请检查网络后重试',
    'AC0006': '支付操作过于频繁或已达重试次数，请稍后查询原订单',
    'CONFIGURATION_CONFLICT': '原订单状态已变化，请重新查询',
  };
}
