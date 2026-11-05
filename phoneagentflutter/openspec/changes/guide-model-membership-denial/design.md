# 设计

SSE 的 `task_failed.data.errorCode=MODEL_ENTITLEMENT_DENIED` 由现有 `AgentEventDecoder` 交给 `MembershipDenialReply`。新增固定文案后，实时事件仍生成一条助手回复并依语音设置播报一次；账本中的已识别权益失败可复用同一映射恢复历史，不触发历史重播。

文案不推断用户当前等级或哪个具体商品一定可用，只提示开通或升级会员。未知错误码保持普通错误。
