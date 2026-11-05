# 设计

`ConversationMessages` 将 schema v1 且已识别的权益拒绝 RUN_FAILED 投影为有稳定事件 ID 的助手消息。`ConversationSourceSteps` 同步增加来源锚点；复用 `MembershipDenialReply`，不显示上游原始错误。

沿用现有消息合并消除实时/历史重复。历史恢复仅还原展示，不触发 TTS、重新请求或拨号；实时播报保持原有行为。非权益错误、未知版本与恢复替代事件保持既有边界。无需后端新事件或数据库迁移。
