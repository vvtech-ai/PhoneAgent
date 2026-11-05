## ADDED Requirements

### Requirement: 模型会员拒绝提供可行动的安全提示

App SHALL 将 SSE 的 `MODEL_ENTITLEMENT_DENIED` 识别为已知会员准入拒绝，显示且按现有语音设置播报固定简短中文提示，说明本次未拨出，并引导用户开通或升级会员。App SHALL NOT 猜测具体会员等级或显示上游原始异常。

#### Scenario: 单通模型权益不足

- **WHEN** 实时 `task_failed` 包含 `errorCode=MODEL_ENTITLEMENT_DENIED`
- **THEN** 对话显示一条安全助手回复，可按既有设置播报一次，并告知开通或升级会员

#### Scenario: 重新打开该失败任务

- **WHEN** 已识别的模型会员拒绝出现在账本历史中
- **THEN** 历史恢复使用同一安全文案，不重新拨号或播报历史 TTS
