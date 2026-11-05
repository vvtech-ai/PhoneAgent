/// Safe presentation for recognized server admission failures only.
abstract final class MembershipDenialReply {
  static String? message(Object? code) => switch (code) {
    'BATCH_CONTACT_LIMIT' => '本次联系人数超出当前会员批量联系人上限，本次未拨出，请减少联系人后重试或查看会员权益。',
    'BATCH_CONCURRENCY_LIMIT' => '本次请求并发数超出当前会员并发上限，本次未拨出，请降低并发数后重试或查看会员权益。',
    'BATCH_ENTITLEMENT_LIMIT' => '当前会员的批量联系人或并发额度不足，本次未拨出。请查看会员权益并调整联系人数量或并发数。',
    'CALL_CONCURRENCY_LIMIT' => '当前账号通话并发已达会员上限，本次未拨出，请等待现有通话结束后重试。',
    'MODEL_ENTITLEMENT_DENIED' => '当前会员不可用该模型，本次未拨出。请开通或升级会员。',
    'ENTITLEMENT_DENIED' => '当前会员权益暂不支持本次操作，本次操作未执行。请查看会员权益后调整任务。',
    _ => null,
  };
}
